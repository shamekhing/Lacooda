`timescale 1ns/1ps

// ============================================================
// LACOODA RPU SLAVE PORT — STAGE 5
// ============================================================
//
// One per-slave arbitration and response-routing port.
//
// The fabric is a fixed 4-master / 4-slave crossbar because
// Icarus Verilog 12 cannot elaborate unpacked-array parameters
// or two-dimensional arrays. Each slave port therefore exposes
// four explicit master request/response pairs.
//
// CONTRACT
//
//   A requesting master holds its entire bus_req_s stable
//   while valid is asserted and ready is low.
//
//   A transaction completes on the rising edge when:
//
//       slave_req.valid && slave_rsp.ready
//
//   Only the selected master receives slave_rsp. Every other
//   master receives a zero response.
//
// ARBITRATION
//
//   Round-robin. The priority register advances past the
//   master that completed the previous transaction.
//
//   A slave that never asserts ready holds the port in
//   SP_ACTIVE. Timeouts are a future RPU extension.
//
// CAPABILITY MODEL
//
//   This module implements exactly one operation slot:
//
//     READ_PORTS             = 1
//     WRITE_PORTS            = 1 (shared with read)
//     TOTAL_PORTS            = 1
//     MAX_OUTSTANDING        = 1
//     CONCURRENT_READ_WRITE  = 0
//
//   That matches the existing single-port data RAM, instruction
//   ROM, GPU MMIO block, and DDR3 bridge. Illegal simultaneous
//   port combinations cannot be admitted because there is only
//   one slot. A genuine dual-port or 2R1W slave would require a
//   separate multi-port slave module; it is not simulated here.
// ============================================================

module rpu_slave_port (

    input logic clk,
    input logic rst,

    // Four master request inputs
    input bus_pkg::bus_req_s req0,
    input bus_pkg::bus_req_s req1,
    input bus_pkg::bus_req_s req2,
    input bus_pkg::bus_req_s req3,

    // Four master response outputs
    output bus_pkg::bus_rsp_s rsp0,
    output bus_pkg::bus_rsp_s rsp1,
    output bus_pkg::bus_rsp_s rsp2,
    output bus_pkg::bus_rsp_s rsp3,

    // Downstream slave interface
    output bus_pkg::bus_req_s slave_req,
    input  bus_pkg::bus_rsp_s slave_rsp,

    // Observability
    output logic owner_active

);

    // ========================================================
    // STATE
    // ========================================================

    typedef enum logic {
        SP_IDLE   = 1'b0,
        SP_ACTIVE = 1'b1
    } sp_state_e;

    sp_state_e state_reg;

    logic [1:0] priority_reg;
    logic [1:0] owner_reg;
    logic       owner_valid;

    logic [1:0] selected;
    logic       selected_valid;

    logic transaction_complete;

    // ========================================================
    // ROUND-ROBIN SELECTION
    // ========================================================

    always_comb begin

        selected       = 2'd0;
        selected_valid = 1'b0;

        if (!rst) begin

            if (state_reg == SP_ACTIVE) begin

                selected       = owner_reg;
                selected_valid = owner_valid;

            end else begin

                case (priority_reg)

                    // -----------------------------------------
                    // MASTER 0 HAS FIRST PRIORITY
                    // -----------------------------------------

                    2'd0: begin
                        if (req0.valid) begin
                            selected = 2'd0; selected_valid = 1'b1;
                        end else if (req1.valid) begin
                            selected = 2'd1; selected_valid = 1'b1;
                        end else if (req2.valid) begin
                            selected = 2'd2; selected_valid = 1'b1;
                        end else if (req3.valid) begin
                            selected = 2'd3; selected_valid = 1'b1;
                        end
                    end

                    // -----------------------------------------
                    // MASTER 1 HAS FIRST PRIORITY
                    // -----------------------------------------

                    2'd1: begin
                        if (req1.valid) begin
                            selected = 2'd1; selected_valid = 1'b1;
                        end else if (req2.valid) begin
                            selected = 2'd2; selected_valid = 1'b1;
                        end else if (req3.valid) begin
                            selected = 2'd3; selected_valid = 1'b1;
                        end else if (req0.valid) begin
                            selected = 2'd0; selected_valid = 1'b1;
                        end
                    end

                    // -----------------------------------------
                    // MASTER 2 HAS FIRST PRIORITY
                    // -----------------------------------------

                    2'd2: begin
                        if (req2.valid) begin
                            selected = 2'd2; selected_valid = 1'b1;
                        end else if (req3.valid) begin
                            selected = 2'd3; selected_valid = 1'b1;
                        end else if (req0.valid) begin
                            selected = 2'd0; selected_valid = 1'b1;
                        end else if (req1.valid) begin
                            selected = 2'd1; selected_valid = 1'b1;
                        end
                    end

                    // -----------------------------------------
                    // MASTER 3 HAS FIRST PRIORITY
                    // -----------------------------------------

                    default: begin
                        if (req3.valid) begin
                            selected = 2'd3; selected_valid = 1'b1;
                        end else if (req0.valid) begin
                            selected = 2'd0; selected_valid = 1'b1;
                        end else if (req1.valid) begin
                            selected = 2'd1; selected_valid = 1'b1;
                        end else if (req2.valid) begin
                            selected = 2'd2; selected_valid = 1'b1;
                        end
                    end

                endcase

            end

        end

    end

    // ========================================================
    // REQUEST MULTIPLEXER
    // ========================================================

    always_comb begin

        slave_req = '0;

        if (selected_valid) begin

            case (selected)
                2'd0: slave_req = req0;
                2'd1: slave_req = req1;
                2'd2: slave_req = req2;
                default: slave_req = req3;
            endcase

        end

    end

    // ========================================================
    // RESPONSE DEMULTIPLEXER
    // ========================================================
    //
    // No response is broadcast. Only the selected or registered
    // owner observes the downstream response.
    // ========================================================

    always_comb begin

        rsp0 = '0;
        rsp1 = '0;
        rsp2 = '0;
        rsp3 = '0;

        if (selected_valid && slave_req.valid) begin

            case (selected)
                2'd0: rsp0 = slave_rsp;
                2'd1: rsp1 = slave_rsp;
                2'd2: rsp2 = slave_rsp;
                default: rsp3 = slave_rsp;
            endcase

        end

    end

    // ========================================================
    // COMPLETION AND OBSERVABILITY
    // ========================================================

    assign transaction_complete =
        slave_req.valid && slave_rsp.ready;

    assign owner_active =
        (state_reg == SP_ACTIVE);

    // ========================================================
    // ARBITRATION STATE MACHINE
    // ========================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            state_reg    <= SP_IDLE;
            priority_reg <= 2'd0;
            owner_reg    <= 2'd0;
            owner_valid  <= 1'b0;

        end else begin

            case (state_reg)

                // ============================================
                // IDLE
                // ============================================

                SP_IDLE: begin

                    if (selected_valid) begin

                        if (transaction_complete) begin

                            // Zero-wait completion.

                            priority_reg <=
                                (selected == 2'd3)
                                    ? 2'd0
                                    : selected + 2'd1;

                        end else begin

                            // Downstream is not ready yet.
                            // Preserve the selected master.

                            owner_reg   <= selected;
                            owner_valid <= 1'b1;
                            state_reg   <= SP_ACTIVE;

                        end

                    end

                end

                // ============================================
                // ACTIVE
                // ============================================

                SP_ACTIVE: begin

                    if (transaction_complete) begin

                        priority_reg <=
                            (owner_reg == 2'd3)
                                ? 2'd0
                                : owner_reg + 2'd1;

                        owner_valid <= 1'b0;
                        state_reg   <= SP_IDLE;

                    end

                end

                // ============================================
                // INVALID STATE
                // ============================================

                default: begin

                    state_reg    <= SP_IDLE;
                    priority_reg <= 2'd0;
                    owner_reg    <= 2'd0;
                    owner_valid  <= 1'b0;

                end

            endcase

        end

    end

endmodule
