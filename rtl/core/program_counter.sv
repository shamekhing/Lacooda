module program_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,

    input  logic        redirect,
    input  logic [63:0] target,

    output logic [63:0] pc
);

    always_ff @(posedge clk) begin
        if (rst)
            pc <= 64'd0;

        else if (enable) begin
            if (redirect)
                pc <= target;
            else
                pc <= pc + 64'd8;
        end
    end

endmodule