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
            if (redirect)
                pc <= target;
            else
                pc <= pc + cpu_pkg::data_t'(cpu_pkg::INSTRUCTION_BYTES);
        end
    end

endmodule
