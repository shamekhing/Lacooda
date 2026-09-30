// Combinational instruction ROM indexed by a byte address.
// INIT_FILE contains one hexadecimal instruction word per memory entry.
module instruction_memory #(
    parameter int DEPTH = cpu_pkg::INSTRUCTION_MEMORY_DEPTH,
    parameter INIT_FILE = cpu_pkg::INSTRUCTION_MEMORY_INIT_FILE
)(
    input  cpu_pkg::data_t address,
    output cpu_pkg::instruction_t instruction
);

    cpu_pkg::instruction_t memory [0:DEPTH-1];

    // Initialize unused words to zero before loading the program at simulation start.
    // Relative INIT_FILE paths are resolved from the simulator working directory.
    initial begin
        for (int i = 0; i < DEPTH; i++)
            memory[i] = '0;

        $readmemh(INIT_FILE, memory);
    end

    always_comb begin
        // Misaligned or out-of-range addresses return a zero instruction word.
        // No fetch-fault signal is generated; zero decodes as ADD R0, R0, R0.
        instruction = '0;

        // Convert the byte address to a word index only for aligned addresses.
        if (address % cpu_pkg::INSTRUCTION_BYTES == 0 &&
            (address / cpu_pkg::INSTRUCTION_BYTES) < DEPTH)
            instruction = memory[address / cpu_pkg::INSTRUCTION_BYTES];
    end

endmodule
