`timescale 1ns/1ps

// ============================================================
// LACOODA DDR3 BRIDGE — STAGE 3
// ============================================================
//
// PURPOSE
//
// Convert the CPU-side native bus transaction into a
// captured and stable transaction for a DDR3 backend adapter.
//
// This is NOT a DDR3 PHY or a Gowin IP replacement.
//
// INPUT ADDRESS
//
// The incoming address is local to DDR3:
//
//   0x00000000 through 0x07FFFFFF
//
// The interconnect removes DDR3_BASE before forwarding.
//
// SUPPORTED OPERATIONS
//
//   BUS_READ
//   BUS_WRITE
//
// TRANSACTION SEMANTICS
//
//   1. Capture one valid upstream request.
//   2. Reject invalid/unavailable accesses with an error.
//   3. Present a stable request to the backend.
//   4. Wait for the backend completion handshake.
//   5. Capture the backend result.
//   6. Return one registered upstream response.
//   7. Release the transaction after upstream completion.
//
// Backend contract:
//
//   ddr3_backend_bus_req.valid && ddr3_backend_bus_rsp.ready
//
// means that the entire backend transaction has completed.
//
// A future Gowin adapter MUST NOT assert ddr3_backend_bus_rsp.ready
// merely because a DDR3 command was accepted.
//
// For writes, all required write-data acceptance must also
// have occurred before acknowledging the transaction.
//
// Both bus interfaces are synchronous to clk.
//
// No multiple outstanding requests or pipelining.
// ============================================================

module ddr3_bridge (

    input logic clk,
    input logic rst,

    // Upstream DDR3-local LACOODA bus
    input  bus_pkg::bus_req_s ddr3_bus_req,
    output bus_pkg::bus_rsp_s ddr3_bus_rsp,

    // Backend availability
    input logic backend_ready,

    // Backend native transaction interface
    output bus_pkg::bus_req_s ddr3_backend_bus_req,
    input  bus_pkg::bus_rsp_s ddr3_backend_bus_rsp
);

    // ========================================================
    // STATE MACHINE
    // ========================================================
    //
    // IDLE:
    //   Accept a new upstream request.
    //
    // WAIT_BACKEND:
    //   Hold a previously captured request stable until
    //   the backend completes it.
    //
    // RESPOND:
    //   Return one registered response upstream.
    // ========================================================

    typedef enum logic [1:0] {
        DDR3_IDLE         = 2'b00,
        DDR3_WAIT_BACKEND = 2'b01,
        DDR3_RESPOND      = 2'b10
    } ddr3_state_e;

    ddr3_state_e state_reg;

    // ========================================================
    // REGISTERED TRANSACTION DATA
    // ========================================================

    bus_pkg::bus_req_s request_reg;
    bus_pkg::bus_rsp_s response_reg;

    // ========================================================
    // REQUEST VALIDATION
    // ========================================================
    //
    // Validate against the physical region exposed
    // through the global memory map.
    //
    // A bridge may be instantiated independently of the
    // interconnect, so validation is repeated locally.
    // ========================================================

    logic address_valid;
    logic address_aligned;

    assign address_valid =
        ddr3_bus_req.addr < cpu_pkg::word_t'(memory_pkg::DDR3_BYTES);

    assign address_aligned =
        bus_pkg::bus_is_aligned(ddr3_bus_req.addr);

    // ========================================================
    // BACKEND REQUEST OUTPUT
    // ========================================================
    //
    // Only the WAIT_BACKEND state can assert valid.
    //
    // request_reg is never modified while waiting.
    //
    // Therefore every request field remains stable through
    // arbitrary backend stalls.
    // ========================================================

    always_comb begin

        ddr3_backend_bus_req = '0;

        if (
            !rst &&
            (state_reg == DDR3_WAIT_BACKEND)
        ) begin

            ddr3_backend_bus_req = request_reg;
            ddr3_backend_bus_req.valid = 1'b1;

        end

    end

    // ========================================================
    // UPSTREAM RESPONSE OUTPUT
    // ========================================================
    //
    // The registered result becomes visible during RESPOND.
    //
    // It is not forwarded combinationally from the backend.
    // ========================================================

    always_comb begin

        ddr3_bus_rsp = '0;

        if (
            !rst &&
            (state_reg == DDR3_RESPOND)
        ) begin

            ddr3_bus_rsp = response_reg;
            ddr3_bus_rsp.ready = 1'b1;

        end

    end

    // ========================================================
    // STATE AND TRANSACTION REGISTERS
    // ========================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            state_reg <= DDR3_IDLE;

            request_reg  <= '0;
            response_reg <= '0;

        end else begin

            case (state_reg)

                // ============================================
                // IDLE
                // ============================================

                DDR3_IDLE: begin

                    if (ddr3_bus_req.valid) begin

                        // Capture the complete request.
                        request_reg <= ddr3_bus_req;

                        // Clear the previous transaction's
                        // registered response.
                        response_reg <= '0;

                        // Reject invalid addresses before
                        // any request reaches the backend.
                        if (
                            !address_valid ||
                            !address_aligned
                        ) begin

                            response_reg <=
                                bus_pkg::bus_failure();

                            state_reg <= DDR3_RESPOND;

                        end

                        // Do not forward a transaction
                        // when the backend is unavailable.
                        else if (!backend_ready) begin

                            response_reg <=
                                bus_pkg::bus_failure();

                            state_reg <= DDR3_RESPOND;

                        end

                        // Valid transaction: forward on
                        // the following clock interval.
                        else begin

                            state_reg <= DDR3_WAIT_BACKEND;

                        end

                    end

                end

                // ============================================
                // WAIT_BACKEND
                // ============================================
                //
                // ddr3_backend_bus_req remains asserted.
                //
                // The backend may take any number of cycles
                // to produce a response.
                //
                // A successful handshake completes exactly
                // one backend transaction.
                // ============================================

                DDR3_WAIT_BACKEND: begin

                    if (ddr3_backend_bus_req.valid && ddr3_backend_bus_rsp.ready) begin

                        response_reg <= ddr3_backend_bus_rsp;

                        // The response records completion.
                        response_reg.ready <= 1'b1;

                        // Stop presenting the backend request
                        // after the completion edge.
                        state_reg <= DDR3_RESPOND;

                    end

                end

                // ============================================
                // RESPOND
                // ============================================
                //
                // The upstream master observes ready while
                // holding its original valid request.
                //
                // The rising edge completes the handshake.
                //
                // Return to IDLE after that edge.
                // ============================================

                DDR3_RESPOND: begin

                    if (ddr3_bus_req.valid) begin

                        state_reg <= DDR3_IDLE;

                    end

                    // With this simple bus contract, the
                    // requester must hold valid until ready.
                    //
                    // If valid is incorrectly withdrawn,
                    // keep the response pending rather than
                    // silently discarding the transaction.

                end

                // ============================================
                // INVALID STATE RECOVERY
                // ============================================

                default: begin

                    state_reg <= DDR3_IDLE;

                    request_reg  <= '0;
                    response_reg <= '0;

                end

            endcase

        end

    end

endmodule