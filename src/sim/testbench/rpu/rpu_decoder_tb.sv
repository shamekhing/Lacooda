`timescale 1ns/1ps

// ============================================================
// LACOODA RPU DECODER TESTBENCH — STAGE 5
// ============================================================
//
// Verifies static map validation, master-qualified routing,
// reserved-region classification, local-address translation,
// and agreement with the package reference function.
// ============================================================

module rpu_decoder_tb;

    import cpu_pkg::*;
    import rpu_pkg::*;

    word_t cpu_i_addr;
    word_t cpu_d_addr;
    word_t gpu_addr;
    word_t tpu_addr;

    rpu_route_s cpu_i_route;
    rpu_route_s cpu_d_route;
    rpu_route_s gpu_route;
    rpu_route_s tpu_route;

    rpu_slave_caps_s caps_rom;
    rpu_slave_caps_s caps_ram;
    rpu_slave_caps_s caps_gpu;
    rpu_slave_caps_s caps_ddr3;

    integer tests;
    integer errors;
    integer i;
    word_t sweep_addr;

    rpu_decoder dut (
        .cpu_i_addr (cpu_i_addr),
        .cpu_d_addr (cpu_d_addr),
        .gpu_addr   (gpu_addr),
        .tpu_addr   (tpu_addr),
        .cpu_i_route(cpu_i_route),
        .cpu_d_route(cpu_d_route),
        .gpu_route  (gpu_route),
        .tpu_route  (tpu_route)
    );

    task automatic check(
        input logic condition,
        input string description
    );

        begin

            tests = tests + 1;

            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("[FAIL] %0d: %s", tests, description);
            end else begin
                $display("[PASS] %0d: %s", tests, description);
            end

        end

    endtask

    task automatic set_addrs(
        input word_t a_i,
        input word_t a_d,
        input word_t a_g,
        input word_t a_t
    );

        begin

            cpu_i_addr = a_i;
            cpu_d_addr = a_d;
            gpu_addr   = a_g;
            tpu_addr   = a_t;
            #1;

        end

    endtask

    initial begin

        tests  = 0;
        errors = 0;

        cpu_i_addr = '0;
        cpu_d_addr = '0;
        gpu_addr   = '0;
        tpu_addr   = '0;
        #1;

        check(
            rpu_pkg::rpu_validate_map() === 1'b1,
            "Static route map is valid"
        );

        // ----------------------------------------------------
        // SLAVE CAPABILITY MODEL
        // ----------------------------------------------------

        caps_rom   = rpu_pkg::rpu_slave_caps(RPU_S_ROM);
        caps_ram   = rpu_pkg::rpu_slave_caps(RPU_S_DATA_RAM);
        caps_gpu   = rpu_pkg::rpu_slave_caps(RPU_S_GPU_MMIO);
        caps_ddr3  = rpu_pkg::rpu_slave_caps(RPU_S_DDR3);

        check(
            caps_rom.read_ports == 2'd1 &&
            caps_rom.write_ports == 2'd0,
            "ROM is read-only and single-port"
        );

        check(
            caps_ram.total_ports == 2'd1 &&
            caps_ram.concurrent_read_write == 1'b0,
            "Data RAM is a single shared read/write port"
        );

        check(
            caps_gpu.response_latency == 8'd0,
            "GPU MMIO is a same-cycle response slave"
        );

        check(
            caps_ddr3.max_outstanding == 2'd1,
            "DDR3 bridge accepts one outstanding transaction"
        );

        check(
            caps_ddr3.response_latency == 8'd255,
            "DDR3 response latency is variable"
        );

        // ----------------------------------------------------
        // CPU INSTRUCTION FETCH
        // ----------------------------------------------------

        set_addrs('0, '0, '0, '0);

        check(
            cpu_i_route.mapped && cpu_i_route.valid &&
            (cpu_i_route.slave == RPU_S_ROM) &&
            (cpu_i_route.local_addr == '0),
            "CPU_I address 0 routes to ROM"
        );

        set_addrs(word_t'(32'h0000_7FFC), '0, '0, '0);

        check(
            cpu_i_route.valid &&
            (cpu_i_route.local_addr == word_t'(32'h0000_7FFC)),
            "CPU_I last ROM word translates locally"
        );

        set_addrs(word_t'(32'h0000_8000), '0, '0, '0);

        check(
            !cpu_i_route.mapped && !cpu_i_route.valid,
            "CPU_I address past ROM is unmapped"
        );

        set_addrs(word_t'(32'h1000_0000), '0, '0, '0);

        check(
            !cpu_i_route.mapped && !cpu_i_route.valid,
            "CPU_I cannot route to GPU MMIO"
        );

        // ----------------------------------------------------
        // CPU DATA - RAM / GPU MMIO
        // ----------------------------------------------------

        set_addrs('0, word_t'(32'h0000_0048), '0, '0);

        check(
            cpu_d_route.mapped && cpu_d_route.valid &&
            (cpu_d_route.slave == RPU_S_DATA_RAM) &&
            (cpu_d_route.local_addr == word_t'(32'h0000_0048)),
            "CPU_D address 0x48 routes to RAM"
        );

        set_addrs('0, word_t'(32'h1000_0020), '0, '0);

        check(
            cpu_d_route.mapped && cpu_d_route.valid &&
            (cpu_d_route.slave == RPU_S_GPU_MMIO) &&
            (cpu_d_route.local_addr == word_t'(32'h0000_0020)),
            "CPU_D GPU MMIO translates to local 0x20"
        );

        set_addrs('0, word_t'(32'h1000_1000), '0, '0);

        check(
            cpu_d_route.mapped && !cpu_d_route.valid &&
            (cpu_d_route.slave == RPU_S_NONE),
            "TPU MMIO is mapped but has no slave"
        );

        set_addrs('0, word_t'(32'h4000_0000), '0, '0);

        check(
            !cpu_d_route.mapped && !cpu_d_route.valid,
            "Unmapped data address is rejected"
        );

        set_addrs('0, word_t'(32'h8000_0100), '0, '0);

        check(
            cpu_d_route.mapped && cpu_d_route.valid &&
            (cpu_d_route.slave == RPU_S_DDR3) &&
            (cpu_d_route.local_addr == word_t'(32'h0000_0100)),
            "CPU_D DDR3 access translates locally"
        );

        // ----------------------------------------------------
        // GPU / TPU DATA MASTERS
        // ----------------------------------------------------

        set_addrs('0, '0, word_t'(32'h0000_0010), '0);

        check(
            gpu_route.valid &&
            (gpu_route.slave == RPU_S_DATA_RAM),
            "GPU address 0x10 routes to RAM"
        );

        set_addrs('0, '0, '0, word_t'(32'h0000_0020));

        check(
            tpu_route.valid &&
            (tpu_route.slave == RPU_S_DATA_RAM),
            "TPU address 0x20 routes to RAM"
        );

        // ----------------------------------------------------
        // REFERENCE CROSS-CHECK
        // ----------------------------------------------------

        sweep_addr = '0;

        for (i = 0; i < 64; i = i + 1) begin

            set_addrs(
                sweep_addr,
                sweep_addr,
                sweep_addr,
                sweep_addr
            );

            check(
                (cpu_i_route === rpu_pkg::rpu_decode(RPU_M_CPU_I, sweep_addr)) &&
                (cpu_d_route === rpu_pkg::rpu_decode(RPU_M_CPU_D, sweep_addr)) &&
                (gpu_route   === rpu_pkg::rpu_decode(RPU_M_GPU,   sweep_addr)) &&
                (tpu_route   === rpu_pkg::rpu_decode(RPU_M_TPU,   sweep_addr)),
                "Decoder matches package reference"
            );

            sweep_addr = sweep_addr + word_t'(32'h0010_0000);

        end

        // ----------------------------------------------------
        // RESULTS
        // ----------------------------------------------------

        $display("==========================================");
        $display("LACOODA STAGE 5 RPU DECODER");
        $display("Tests:  %0d", tests);
        $display("Passed: %0d", tests - errors);
        $display("Failed: %0d", errors);
        $display("==========================================");

        if (errors != 0)
            $fatal(1, "LACOODA STAGE 5 RPU DECODER TEST FAILED");

        $display("LACOODA STAGE 5 RPU DECODER TEST PASSED");
        $finish;

    end

    initial begin
        #100000;
        $fatal(1, "LACOODA Stage 5 RPU decoder test timed out");
    end

endmodule
