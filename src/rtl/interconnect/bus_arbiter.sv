`timescale 1ns/1ps

// ============================================================
// LACOODA NATIVE BUS ARBITER — STAGE 4
// ============================================================
//
// PURPOSE
//
//   Allow the CPU, GPU and TPU memory masters to share
//   one downstream data-bus interconnect.
//
// MASTERS
//
//   Master 0 : CPU
//   Master 1 : GPU
//   Master 2 : TPU
//
// DOWNSTREAM
//
//   Existing LACOODA bus interconnect.
//
// ARBITRATION
//
//   Round-robin.
//
//   After a completed transaction, the next arbitration
//   begins with the master following the previous winner.
//
// BUS CONTRACT
//
//   A requesting master must keep its entire bus_req_s
//   stable while valid is asserted and ready is low.
//
//   A transaction completes on the rising edge when:
//
//       request.valid && response.ready
//
//   Only the selected master receives the downstream
//   response.
//
//   Non-selected masters receive a zero response.
//
// DESIGN
//
//   - One outstanding downstream transaction.
//   - No request buffering.
//   - No address decoding.
//   - No changes to data width or write strobes.
//   - No clock-domain crossing.
//   - No dependency on GPU or TPU implementation.
//
// IMMEDIATE RESPONSES
//
//   When the bus is idle, the selected request is forwarded
//   combinationally.
//
//   This allows a zero-wait MMIO response to complete on
//   the next rising edge.
//
// DELAYED RESPONSES
//
//   When the downstream slave is not ready, the arbiter
//   registers the selected master and holds ownership
//   until completion.
//
// FAIRNESS
//
//   With masters obeying the stable-request contract and
//   every downstream transaction eventually completing,
//   a continuously requesting master cannot be bypassed
//   indefinitely.
//
// LIMITATION
//
//   A downstream slave that never completes can block
//   every other master. Timeouts and bus fault recovery
//   are separate architectural features.
// ============================================================

module bus_arbiter (

    input logic clk,
    input logic rst,

    // ========================================================
    // CPU MASTER
    // ========================================================

    input  bus_pkg::bus_req_s cpu_bus_req,
    output bus_pkg::bus_rsp_s cpu_bus_rsp,

    // ========================================================
    // GPU MASTER
    // ========================================================

    input  bus_pkg::bus_req_s gpu_bus_req,
    output bus_pkg::bus_rsp_s gpu_bus_rsp,

    // ========================================================
    // TPU MASTER
    // ========================================================

    input  bus_pkg::bus_req_s tpu_bus_req,
    output bus_pkg::bus_rsp_s tpu_bus_rsp,

    // ========================================================
    // SHARED DOWNSTREAM BUS
    // ========================================================

    output bus_pkg::bus_req_s shared_bus_req,
    input  bus_pkg::bus_rsp_s shared_bus_rsp

);

    // ========================================================
    // MASTER IDENTIFIERS
    // ========================================================

    typedef enum logic [1:0] {

        MASTER_CPU  = 2'd0,
        MASTER_GPU  = 2'd1,
        MASTER_TPU  = 2'd2,

        MASTER_NONE = 2'd3

    } master_e;

    // ========================================================
    // ARBITRATION STATE
    // ========================================================
    //
    // ARB_IDLE:
    //   Choose a requesting master.
    //
    // ARB_ACTIVE:
    //   Preserve the selected master until its transaction
    //   completes.
    // ========================================================

    typedef enum logic {

        ARB_IDLE   = 1'b0,
        ARB_ACTIVE = 1'b1

    } arb_state_e;

    arb_state_e state_reg;

    // Current transaction owner.
    master_e owner_reg;

    // Master with first priority during the next election.
    master_e priority_reg;

    // Combinational result of the current election.
    master_e candidate;

    // Actual owner of the currently forwarded request.
    master_e selected_master;

    // Indicates that the selected downstream transaction
    // completes on the current rising clock edge.
    logic transaction_complete;

    // ========================================================
    // ROUND-ROBIN SUCCESSOR
    // ========================================================
    //
    // CPU -> GPU -> TPU -> CPU
    //
    // MASTER_NONE maps back to CPU as a safe default.
    // ========================================================

    function automatic master_e next_master(
        input master_e current
    );

        case (current)

            MASTER_CPU:
                return MASTER_GPU;

            MASTER_GPU:
                return MASTER_TPU;

            MASTER_TPU:
                return MASTER_CPU;

            default:
                return MASTER_CPU;

        endcase

    endfunction

    // ========================================================
    // ROUND-ROBIN CANDIDATE SELECTION
    // ========================================================
    //
    // Search all three requesters.
    //
    // The first position depends on priority_reg.
    //
    // An idle master is skipped.
    //
    // No request produces MASTER_NONE.
    //
    // Every possible priority value has an explicit case.
    // ========================================================

    always_comb begin

        candidate = MASTER_NONE;

        case (priority_reg)

            // ------------------------------------------------
            // CPU HAS FIRST PRIORITY
            // ------------------------------------------------

            MASTER_CPU: begin

                if (cpu_bus_req.valid)
                    candidate = MASTER_CPU;

                else if (gpu_bus_req.valid)
                    candidate = MASTER_GPU;

                else if (tpu_bus_req.valid)
                    candidate = MASTER_TPU;

            end

            // ------------------------------------------------
            // GPU HAS FIRST PRIORITY
            // ------------------------------------------------

            MASTER_GPU: begin

                if (gpu_bus_req.valid)
                    candidate = MASTER_GPU;

                else if (tpu_bus_req.valid)
                    candidate = MASTER_TPU;

                else if (cpu_bus_req.valid)
                    candidate = MASTER_CPU;

            end

            // ------------------------------------------------
            // TPU HAS FIRST PRIORITY
            // ------------------------------------------------

            MASTER_TPU: begin

                if (tpu_bus_req.valid)
                    candidate = MASTER_TPU;

                else if (cpu_bus_req.valid)
                    candidate = MASTER_CPU;

                else if (gpu_bus_req.valid)
                    candidate = MASTER_GPU;

            end

            // ------------------------------------------------
            // INVALID PRIORITY RECOVERY
            // ------------------------------------------------

            default: begin

                if (cpu_bus_req.valid)
                    candidate = MASTER_CPU;

                else if (gpu_bus_req.valid)
                    candidate = MASTER_GPU;

                else if (tpu_bus_req.valid)
                    candidate = MASTER_TPU;

            end

        endcase

    end

    // ========================================================
    // SELECT CURRENT TRANSACTION OWNER
    // ========================================================
    //
    // During IDLE:
    //   The round-robin candidate owns the transaction.
    //
    // During ACTIVE:
    //   The registered owner retains the bus.
    //
    // Reset suppresses all downstream activity.
    // ========================================================

    always_comb begin

        selected_master = MASTER_NONE;

        if (!rst) begin

            if (state_reg == ARB_ACTIVE)
                selected_master = owner_reg;

            else
                selected_master = candidate;

        end

    end

    // ========================================================
    // DOWNSTREAM REQUEST MULTIPLEXER
    // ========================================================
    //
    // Forward all fields of the selected master's request.
    //
    // The arbiter never modifies:
    //
    //   op
    //   addr
    //   wdata
    //   wstrb
    //
    // A non-selected request is never forwarded.
    // ========================================================

    always_comb begin

        shared_bus_req = '0;

        case (selected_master)

            MASTER_CPU:
                shared_bus_req = cpu_bus_req;

            MASTER_GPU:
                shared_bus_req = gpu_bus_req;

            MASTER_TPU:
                shared_bus_req = tpu_bus_req;

            default:
                shared_bus_req = '0;

        endcase

    end

    // ========================================================
    // UPSTREAM RESPONSE DEMULTIPLEXER
    // ========================================================
    //
    // Only the current transaction owner sees shared_bus_rsp.
    //
    // Every other master receives ready = 0.
    //
    // This prevents an unselected master from incorrectly
    // retiring its pending transaction.
    // ========================================================

    always_comb begin

        cpu_bus_rsp = '0;
        gpu_bus_rsp = '0;
        tpu_bus_rsp = '0;

        if (shared_bus_req.valid) begin

            case (selected_master)

                MASTER_CPU:
                    cpu_bus_rsp = shared_bus_rsp;

                MASTER_GPU:
                    gpu_bus_rsp = shared_bus_rsp;

                MASTER_TPU:
                    tpu_bus_rsp = shared_bus_rsp;

                default: begin

                    // No selected master.

                end

            endcase

        end

    end

    // ========================================================
    // TRANSACTION COMPLETION
    // ========================================================
    //
    // Both valid and ready must be asserted.
    //
    // The downstream interconnect may return ready
    // immediately for an MMIO access or several cycles
    // later for RAM/DDR3.
    // ========================================================

    assign transaction_complete =
        shared_bus_req.valid && shared_bus_rsp.ready;

    // ========================================================
    // ROUND-ROBIN STATE MACHINE
    // ========================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            state_reg    <= ARB_IDLE;
            owner_reg    <= MASTER_NONE;
            priority_reg <= MASTER_CPU;

        end else begin

            case (state_reg)

                // ============================================
                // IDLE
                // ============================================
                //
                // No requester:
                //   Remain idle.
                //
                // Immediate completion:
                //   Rotate priority and remain idle.
                //
                // Delayed completion:
                //   Register the selected owner.
                // ============================================

                ARB_IDLE: begin

                    if (selected_master != MASTER_NONE) begin

                        if (transaction_complete) begin

                            // The transaction completed
                            // without a registered wait state.

                            priority_reg <=
                                next_master(selected_master);

                            owner_reg <= MASTER_NONE;
                            state_reg <= ARB_IDLE;

                        end else begin

                            // Downstream not ready.
                            //
                            // Preserve the selected master
                            // throughout the pending request.

                            owner_reg <= selected_master;
                            state_reg <= ARB_ACTIVE;

                        end

                    end

                end

                // ============================================
                // ACTIVE
                // ============================================
                //
                // Ignore other masters until the registered
                // owner's transaction completes.
                //
                // Request fields must remain stable under
                // the native bus master contract.
                // ============================================

                ARB_ACTIVE: begin

                    if (transaction_complete) begin

                        priority_reg <=
                            next_master(owner_reg);

                        owner_reg <= MASTER_NONE;
                        state_reg <= ARB_IDLE;

                    end

                end

                // ============================================
                // INVALID STATE
                // ============================================

                default: begin

                    state_reg    <= ARB_IDLE;
                    owner_reg    <= MASTER_NONE;
                    priority_reg <= MASTER_CPU;

                end

            endcase

        end

    end

endmodule