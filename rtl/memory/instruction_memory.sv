module instruction_memory #(
    parameter int DEPTH = cpu_pkg::INSTRUCTION_MEMORY_DEPTH,
    parameter INIT_FILE = cpu_pkg::INSTRUCTION_MEMORY_INIT_FILE
)(
    input  cpu_pkg::data_t address,
    output cpu_pkg::instruction_t instruction
);

    cpu_pkg::instruction_t memory [0:DEPTH-1];

    initial begin
        $readmemh(INIT_FILE, memory);
    end

    always_comb begin
        instruction = '0;

        if (address % cpu_pkg::INSTRUCTION_BYTES == 0 &&
            (address / cpu_pkg::INSTRUCTION_BYTES) < DEPTH)
            instruction = memory[address / cpu_pkg::INSTRUCTION_BYTES];
    end

endmodule
