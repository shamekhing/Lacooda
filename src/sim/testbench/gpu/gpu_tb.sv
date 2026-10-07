`timescale 1ns/1ps

module gpu_tb;

    // ========================================================
    // Clock / reset
    // ========================================================

    logic clk;
    logic rst;

    // ========================================================
    // GPU bus
    // ========================================================

    bus_pkg::bus_req_s ibus_req;
    bus_pkg::bus_rsp_s ibus_rsp;

    // ========================================================
    // Test values
    // ========================================================

    cpu_pkg::word_t read_data;
    gpu_pkg::gpu_status_s read_status;

    // ========================================================
    // DUT
    // ========================================================

    gpu dut (
        .clk       (clk),
        .rst       (rst),

        .ibus_req (ibus_req),
        .ibus_rsp (ibus_rsp)
    );

    // ========================================================
    // Clock
    // ========================================================

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end

    // ========================================================
    // Write helper
    // ========================================================

    task automatic gpu_write (
        input gpu_pkg::gpu_addr_t addr,
        input cpu_pkg::word_t data
    );

        begin

            @(negedge clk);

            ibus_req.valid = 1'b1;
            ibus_req.op    = bus_pkg::BUS_WRITE;
            ibus_req.addr  = cpu_pkg::word_t'(addr);
            ibus_req.wdata = data;

            #1;

            if (!ibus_rsp.ready)
                $fatal(
                    1,
                    "GPU write did not complete: addr=%h",
                    addr
                );

            @(posedge clk);

            @(negedge clk);

            ibus_req = '0;

        end

    endtask

    // ========================================================
    // Read helper
    // ========================================================

    task automatic gpu_read (
        input  gpu_pkg::gpu_addr_t addr,
        output cpu_pkg::word_t data
    );

        begin

            @(negedge clk);

            ibus_req.valid = 1'b1;
            ibus_req.op    = bus_pkg::BUS_READ;
            ibus_req.addr  = cpu_pkg::word_t'(addr);
            ibus_req.wdata = '0;

            #1;

            if (!ibus_rsp.ready)
                $fatal(
                    1,
                    "GPU read did not complete: addr=%h",
                    addr
                );

            data = ibus_rsp.rdata;

            @(negedge clk);

            ibus_req = '0;

        end

    endtask

    // ========================================================
    // Tests
    // ========================================================

    initial begin

        $dumpfile("gpu.vcd");
        $dumpvars(0, gpu_tb);

        ibus_req = '0;
        rst       = 1'b1;

        repeat (2)
            @(posedge clk);

        rst = 1'b0;

        // ----------------------------------------------------
        // ID
        // ----------------------------------------------------

        gpu_read(
            gpu_pkg::GPU_REG_ID,
            read_data
        );

        if (read_data !== gpu_pkg::GPU_ID_VALUE)
            $fatal(
                1,
                "GPU ID mismatch"
            );

        // ----------------------------------------------------
        // Initial STATUS
        // ----------------------------------------------------

        gpu_read(
            gpu_pkg::GPU_REG_STATUS,
            read_data
        );

        read_status =
            gpu_pkg::gpu_status_s'(read_data);

        if (read_status.enabled !== 1'b0)
            $fatal(
                1,
                "GPU should be disabled after reset"
            );

        if (read_status.idle !== 1'b1)
            $fatal(
                1,
                "GPU should be idle"
            );

        if (read_status.busy !== 1'b0)
            $fatal(
                1,
                "GPU should not be busy"
            );

        if (read_status.error !== 1'b0)
            $fatal(
                1,
                "GPU should not report an error"
            );

        // ----------------------------------------------------
        // Enable GPU
        // ----------------------------------------------------

        gpu_write(
            gpu_pkg::GPU_REG_CONTROL,
            cpu_pkg::word_t'(1)
        );

        gpu_read(
            gpu_pkg::GPU_REG_CONTROL,
            read_data
        );

        if (read_data !== cpu_pkg::word_t'(1))
            $fatal(
                1,
                "CONTROL readback failed"
            );

        // ----------------------------------------------------
        // STATUS enabled
        // ----------------------------------------------------

        gpu_read(
            gpu_pkg::GPU_REG_STATUS,
            read_data
        );

        read_status =
            gpu_pkg::gpu_status_s'(read_data);

        if (read_status.enabled !== 1'b1)
            $fatal(
                1,
                "GPU STATUS did not report enabled"
            );

        // ----------------------------------------------------
        // Framebuffer base
        // ----------------------------------------------------

        gpu_write(
            gpu_pkg::GPU_REG_FRAMEBUFFER_BASE,
            cpu_pkg::word_t'('h8000_0000)
        );

        gpu_read(
            gpu_pkg::GPU_REG_FRAMEBUFFER_BASE,
            read_data
        );

        if (read_data !== cpu_pkg::word_t'('h8000_0000))
            $fatal(
                1,
                "FRAMEBUFFER_BASE readback failed"
            );

        // ----------------------------------------------------
        // Width
        // ----------------------------------------------------

        gpu_write(
            gpu_pkg::GPU_REG_FRAMEBUFFER_WIDTH,
            cpu_pkg::word_t'(320)
        );

        gpu_read(
            gpu_pkg::GPU_REG_FRAMEBUFFER_WIDTH,
            read_data
        );

        if (read_data !== cpu_pkg::word_t'(320))
            $fatal(
                1,
                "FRAMEBUFFER_WIDTH readback failed"
            );

        // ----------------------------------------------------
        // Height
        // ----------------------------------------------------

        gpu_write(
            gpu_pkg::GPU_REG_FRAMEBUFFER_HEIGHT,
            cpu_pkg::word_t'(240)
        );

        gpu_read(
            gpu_pkg::GPU_REG_FRAMEBUFFER_HEIGHT,
            read_data
        );

        if (read_data !== cpu_pkg::word_t'(240))
            $fatal(
                1,
                "FRAMEBUFFER_HEIGHT readback failed"
            );

        // ----------------------------------------------------
        // Clear color
        // ----------------------------------------------------

        gpu_write(
            gpu_pkg::GPU_REG_CLEAR_COLOR,
            cpu_pkg::word_t'(32'h0011_2233)
        );

        gpu_read(
            gpu_pkg::GPU_REG_CLEAR_COLOR,
            read_data
        );

        if (read_data !== cpu_pkg::word_t'(32'h0011_2233))
            $fatal(
                1,
                "CLEAR_COLOR readback failed"
            );

        // ----------------------------------------------------
        // ID must remain read-only
        // ----------------------------------------------------

        gpu_write(
            gpu_pkg::GPU_REG_ID,
            cpu_pkg::word_t'(32'hDEAD_BEEF)
        );

        gpu_read(
            gpu_pkg::GPU_REG_ID,
            read_data
        );

        if (read_data !== gpu_pkg::GPU_ID_VALUE)
            $fatal(
                1,
                "GPU ID was modified"
            );

        // ----------------------------------------------------
        // STATUS must remain read-only
        // ----------------------------------------------------

        gpu_write(
            gpu_pkg::GPU_REG_STATUS,
            cpu_pkg::word_t'(32'hFFFF_FFFF)
        );

        gpu_read(
            gpu_pkg::GPU_REG_STATUS,
            read_data
        );

        read_status =
            gpu_pkg::gpu_status_s'(read_data);

        if (read_status.enabled !== 1'b1)
            $fatal(
                1,
                "STATUS write corrupted enabled state"
            );

        if (read_status.idle !== 1'b1)
            $fatal(
                1,
                "STATUS write corrupted GPU state"
            );

        $display(
            "[PASS] GPU Stage-2 MMIO register block"
        );

        $finish;

    end

endmodule