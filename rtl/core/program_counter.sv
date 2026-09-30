// Byte-addressed program counter with synchronous, active-high reset.
// Priority at each rising edge: reset, enabled redirect, enabled increment.
// When enable is low, the PC holds its value even if redirect is asserted.
module program_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,

    input  logic        redirect,
    input  cpu_pkg::data_t target,

    output cpu_pkg::data_t pc
);

    always_ff @(posedge clk) begin
        if (rst)
            pc <= '0;

        else if (enable) begin
            // Targets are loaded directly; alignment is checked by instruction memory.
            if (redirect)
                pc <= target;
            else
                pc <= pc + cpu_pkg::data_t'(cpu_pkg::INSTRUCTION_BYTES);
        end
    end

endmodule
