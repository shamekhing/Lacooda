module instruction_memory #(
    parameter int DEPTH = 256,
    parameter string INIT_FILE = "programs/program_0.hex"
)(
    input  logic [63:0] address,
    output logic [63:0] instruction
);

    logic [63:0] memory [0:DEPTH-1];

    initial begin
        $readmemh(INIT_FILE, memory);
    end

    always_comb begin
        instruction = 64'd0;

        if (address[2:0] == 3'b000 &&
            (address >> 3) < DEPTH)
            instruction = memory[address >> 3];
    end

endmodule