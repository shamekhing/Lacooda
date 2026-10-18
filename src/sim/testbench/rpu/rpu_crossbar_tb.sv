`timescale 1ns/1ps

// ============================================================
// LACOODA RPU CROSSBAR TESTBENCH — STAGE 5
// ============================================================
//
// Verifies:
//   - Reset behavior
//   - CPU_I -> ROM routing and local translation
//   - CPU_D -> RAM / GPU MMIO / DDR3 routing
//   - Parallel transactions to four different slaves
//   - Same-slave round-robin contention
//   - Unmapped, reserved, and unaligned error responses
//   - Backpressure isolation between slaves
//   - Request-field preservation
//   - No spurious responses
// ============================================================

module rpu_crossbar_tb;

    import cpu_pkg::*;
    import bus_pkg::*;

    logic clk = 1'b0;
    logic rst;

    bus_req_s m0_req;
    bus_req_s m1_req;
    bus_req_s m2_req;
    bus_req_s m3_req;

    bus_rsp_s m0_rsp;
    bus_rsp_s m1_rsp;
    bus_rsp_s m2_rsp;
    bus_rsp_s m3_rsp;

    bus_req_s s0_req;
    bus_req_s s1_req;
    bus_req_s s2_req;
    bus_req_s s3_req;

    bus_rsp_s s0_rsp;
    bus_rsp_s s1_rsp;
    bus_rsp_s s2_rsp;
    bus_rsp_s s3_rsp;

    logic [3:0] master_pending;
    logic [3:0] slave_active;

    integer tests;
    integer errors;

    always #5 clk = ~clk;

    rpu_crossbar dut (
        .clk(clk),
        .rst(rst),
        .m0_req(m0_req),
        .m0_rsp(m0_rsp),
        .m1_req(m1_req),
        .m1_rsp(m1_rsp),
        .m2_req(m2_req),
        .m2_rsp(m2_rsp),
        .m3_req(m3_req),
        .m3_rsp(m3_rsp),
        .s0_req(s0_req),
        .s0_rsp(s0_rsp),
        .s1_req(s1_req),
        .s1_rsp(s1_rsp),
        .s2_req(s2_req),
        .s2_rsp(s2_rsp),
        .s3_req(s3_req),
        .s3_rsp(s3_rsp),
        .master_pending(master_pending),
        .slave_active(slave_active)
    );

    // ========================================================
    // ARCHITECTURAL INVARIANTS
    // ========================================================
    //
    // Checked every clock edge while out of reset:
    //
    //   1. A master is routed to at most one slave.
    //   2. A slave port responds to at most one master.
    //   3. A master receives at most one slave response.
    //
    // These catch duplicate routing, broadcast responses, and
    // response-ownership mistakes that directed checks can miss.
    // ========================================================

    always @(posedge clk) begin

        if (!rst) begin

            if ((dut.s0_from_m0.valid + dut.s1_from_m0.valid +
                 dut.s2_from_m0.valid + dut.s3_from_m0.valid) > 1)
                $fatal(1, "CPU_I routed to more than one slave");

            if ((dut.s0_from_m1.valid + dut.s1_from_m1.valid +
                 dut.s2_from_m1.valid + dut.s3_from_m1.valid) > 1)
                $fatal(1, "CPU_D routed to more than one slave");

            if ((dut.s0_from_m2.valid + dut.s1_from_m2.valid +
                 dut.s2_from_m2.valid + dut.s3_from_m2.valid) > 1)
                $fatal(1, "GPU routed to more than one slave");

            if ((dut.s0_from_m3.valid + dut.s1_from_m3.valid +
                 dut.s2_from_m3.valid + dut.s3_from_m3.valid) > 1)
                $fatal(1, "TPU routed to more than one slave");

            if ((dut.s0_to_m0.ready + dut.s0_to_m1.ready +
                 dut.s0_to_m2.ready + dut.s0_to_m3.ready) > 1)
                $fatal(1, "ROM port responded to more than one master");

            if ((dut.s1_to_m0.ready + dut.s1_to_m1.ready +
                 dut.s1_to_m2.ready + dut.s1_to_m3.ready) > 1)
                $fatal(1, "RAM port responded to more than one master");

            if ((dut.s2_to_m0.ready + dut.s2_to_m1.ready +
                 dut.s2_to_m2.ready + dut.s2_to_m3.ready) > 1)
                $fatal(1, "GPU MMIO port responded to more than one master");

            if ((dut.s3_to_m0.ready + dut.s3_to_m1.ready +
                 dut.s3_to_m2.ready + dut.s3_to_m3.ready) > 1)
                $fatal(1, "DDR3 port responded to more than one master");

            if ((dut.s0_to_m0.ready + dut.s1_to_m0.ready +
                 dut.s2_to_m0.ready + dut.s3_to_m0.ready) > 1)
                $fatal(1, "CPU_I received more than one slave response");

            if ((dut.s0_to_m1.ready + dut.s1_to_m1.ready +
                 dut.s2_to_m1.ready + dut.s3_to_m1.ready) > 1)
                $fatal(1, "CPU_D received more than one slave response");

            if ((dut.s0_to_m2.ready + dut.s1_to_m2.ready +
                 dut.s2_to_m2.ready + dut.s3_to_m2.ready) > 1)
                $fatal(1, "GPU received more than one slave response");

            if ((dut.s0_to_m3.ready + dut.s1_to_m3.ready +
                 dut.s2_to_m3.ready + dut.s3_to_m3.ready) > 1)
                $fatal(1, "TPU received more than one slave response");

            // A response may only appear while the slot has a request.

            if ((dut.s0_to_m0.ready || dut.s0_to_m1.ready ||
                 dut.s0_to_m2.ready || dut.s0_to_m3.ready) &&
                !dut.s0_req.valid)
                $fatal(1, "ROM response without an active request");

            if ((dut.s1_to_m0.ready || dut.s1_to_m1.ready ||
                 dut.s1_to_m2.ready || dut.s1_to_m3.ready) &&
                !dut.s1_req.valid)
                $fatal(1, "RAM response without an active request");

            if ((dut.s2_to_m0.ready || dut.s2_to_m1.ready ||
                 dut.s2_to_m2.ready || dut.s2_to_m3.ready) &&
                !dut.s2_req.valid)
                $fatal(1, "GPU MMIO response without an active request");

            if ((dut.s3_to_m0.ready || dut.s3_to_m1.ready ||
                 dut.s3_to_m2.ready || dut.s3_to_m3.ready) &&
                !dut.s3_req.valid)
                $fatal(1, "DDR3 response without an active request");

        end

    end

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

    function automatic bus_req_s make_request(
        input word_t address,
        input bus_op_e operation,
        input word_t write_data,
        input bus_strb_t strobes
    );

        bus_req_s result;

        result = '0;
        result.valid = 1'b1;
        result.op    = operation;
        result.addr  = address;
        result.wdata = write_data;
        result.wstrb = strobes;

        return result;

    endfunction

    task automatic clear_all();

        begin

            @(negedge clk);

            m0_req = '0;
            m1_req = '0;
            m2_req = '0;
            m3_req = '0;

            s0_rsp = '0;
            s1_rsp = '0;
            s2_rsp = '0;
            s3_rsp = '0;

            #1;

        end

    endtask

    task automatic reset_dut();

        begin

            @(negedge clk);

            rst = 1'b1;

            m0_req = '0;
            m1_req = '0;
            m2_req = '0;
            m3_req = '0;

            s0_rsp = '0;
            s1_rsp = '0;
            s2_rsp = '0;
            s3_rsp = '0;

            repeat (2) @(posedge clk);

            @(negedge clk);

            rst = 1'b0;

            #1;

        end

    endtask

    task automatic check_no_slave_requests(
        input string description
    );

        begin

            check(
                !s0_req.valid && !s1_req.valid &&
                !s2_req.valid && !s3_req.valid,
                description
            );

        end

    endtask

    initial begin

        tests  = 0;
        errors = 0;

        rst = 1'b1;

        m0_req = '0;
        m1_req = '0;
        m2_req = '0;
        m3_req = '0;

        s0_rsp = '0;
        s1_rsp = '0;
        s2_rsp = '0;
        s3_rsp = '0;

        $dumpfile("rpu_crossbar.vcd");
        $dumpvars(0, rpu_crossbar_tb);

        // ====================================================
        // RESET
        // ====================================================

        reset_dut();

        check_no_slave_requests(
            "Reset leaves all slave requests idle"
        );

        check(
            !m0_rsp.ready && !m1_rsp.ready &&
            !m2_rsp.ready && !m3_rsp.ready,
            "Reset leaves all master responses idle"
        );

        // ====================================================
        // CPU_I FETCH -> ROM
        // ====================================================

        @(negedge clk);

        m0_req = make_request(
            word_t'(32'h0000_0004),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        #1;

        check(
            s0_req.valid && (s0_req.addr == word_t'(32'h0000_0004)),
            "CPU_I fetch reaches ROM with local address"
        );

        check(
            !s1_req.valid && !s2_req.valid && !s3_req.valid,
            "CPU_I fetch reaches only ROM"
        );

        check(
            !m1_rsp.ready && !m2_rsp.ready && !m3_rsp.ready,
            "CPU_I fetch does not disturb data masters"
        );

        s0_rsp = bus_success(word_t'(32'h0160_1000));

        #1;

        check(
            m0_rsp.ready && !m0_rsp.error &&
            (m0_rsp.rdata == word_t'(32'h0160_1000)),
            "CPU_I receives ROM instruction"
        );

        @(posedge clk);
        @(negedge clk);

        m0_req = '0;
        s0_rsp = '0;

        #1;

        // ====================================================
        // CPU_D RAM ACCESS
        // ====================================================

        @(negedge clk);

        m1_req = make_request(
            word_t'(32'h0000_0048),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        #1;

        check(
            s1_req.valid && (s1_req.addr == word_t'(32'h0000_0048)),
            "CPU_D RAM access translates locally"
        );

        check(
            !s0_req.valid && !s2_req.valid && !s3_req.valid,
            "CPU_D RAM access reaches only RAM"
        );

        s1_rsp = bus_success(word_t'(32'h0000_0064));

        #1;

        check(
            m1_rsp.ready && (m1_rsp.rdata == word_t'(32'h0000_0064)),
            "CPU_D receives RAM read data"
        );

        check(
            !m0_rsp.ready && !m2_rsp.ready && !m3_rsp.ready,
            "CPU_D RAM response is not broadcast"
        );

        @(posedge clk);
        @(negedge clk);

        m1_req = '0;
        s1_rsp = '0;

        #1;

        // ====================================================
        // PARTIAL-BYTE WRITE PRESERVATION
        // ====================================================

        @(negedge clk);

        m1_req = make_request(
            word_t'(32'h0000_0048),
            BUS_WRITE,
            word_t'(32'hAABB_CCDD),
            4'b0010
        );

        #1;

        check(
            s1_req.valid && (s1_req.wstrb == 4'b0010),
            "Partial-byte write strobe preserved through RPU"
        );

        check(
            (s1_req.op == BUS_WRITE) &&
            (s1_req.wdata == word_t'(32'hAABB_CCDD)),
            "Partial-byte write data preserved through RPU"
        );

        s1_rsp = bus_success('0);

        #1;

        check(
            m1_rsp.ready && !m1_rsp.error,
            "Partial-byte write completes"
        );

        @(posedge clk);
        @(negedge clk);

        m1_req = '0;
        s1_rsp = '0;

        #1;

        // ====================================================
        // CPU_D GPU MMIO ACCESS
        // ====================================================

        @(negedge clk);

        m1_req = make_request(
            word_t'(32'h1000_0020),
            BUS_WRITE,
            word_t'(32'hDEAD_BEEF),
            BUS_STRB_ALL
        );

        #1;

        check(
            s2_req.valid && (s2_req.addr == word_t'(32'h0000_0020)),
            "GPU MMIO address translates to local 0x20"
        );

        check(
            (s2_req.op == BUS_WRITE) &&
            (s2_req.wdata == word_t'(32'hDEAD_BEEF)) &&
            (s2_req.wstrb == BUS_STRB_ALL),
            "GPU MMIO write fields are preserved"
        );

        s2_rsp = bus_success('0);

        #1;

        check(
            m1_rsp.ready && !m1_rsp.error,
            "CPU_D GPU MMIO write completes"
        );

        @(posedge clk);
        @(negedge clk);

        m1_req = '0;
        s2_rsp = '0;

        #1;

        // ====================================================
        // CPU_D DDR3 ACCESS
        // ====================================================

        @(negedge clk);

        m1_req = make_request(
            word_t'(32'h8000_0100),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        #1;

        check(
            s3_req.valid && (s3_req.addr == word_t'(32'h0000_0100)),
            "DDR3 address translates to local 0x100"
        );

        s3_rsp = bus_success(word_t'(32'hCAFE_F00D));

        #1;

        check(
            m1_rsp.ready && (m1_rsp.rdata == word_t'(32'hCAFE_F00D)),
            "CPU_D DDR3 read completes"
        );

        @(posedge clk);
        @(negedge clk);

        m1_req = '0;
        s3_rsp = '0;

        #1;

        // ====================================================
        // UNMAPPED, RESERVED, UNALIGNED ERRORS
        // ====================================================

        @(negedge clk);

        m1_req = make_request(
            word_t'(32'h4000_0000),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        #1;

        check(
            m1_rsp.ready && m1_rsp.error,
            "Unmapped address returns immediate bus error"
        );

        check_no_slave_requests(
            "Unmapped address generates no slave traffic"
        );

        m1_req = make_request(
            word_t'(32'h1000_1000),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        #1;

        check(
            m1_rsp.ready && m1_rsp.error,
            "Reserved TPU MMIO returns bus error"
        );

        m1_req = make_request(
            word_t'(32'h0000_0046),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        #1;

        check(
            m1_rsp.ready && m1_rsp.error,
            "Unaligned address returns bus error"
        );

        check_no_slave_requests(
            "Unaligned address generates no slave traffic"
        );

        @(posedge clk);
        @(negedge clk);

        m1_req = '0;

        #1;


        // ====================================================
        // PARALLEL TRANSACTIONS TO FOUR DIFFERENT SLAVES
        // ====================================================

        reset_dut();

        @(negedge clk);

        m0_req = make_request(word_t'(32'h0000_0004), BUS_READ, '0, BUS_STRB_NONE);
        m1_req = make_request(word_t'(32'h0000_0048), BUS_READ, '0, BUS_STRB_NONE);
        m2_req = make_request(word_t'(32'h1000_0020), BUS_READ, '0, BUS_STRB_NONE);
        m3_req = make_request(word_t'(32'h8000_0100), BUS_READ, '0, BUS_STRB_NONE);

        #1;

        check(
            s0_req.valid && s1_req.valid &&
            s2_req.valid && s3_req.valid,
            "All four slaves receive a request in parallel"
        );

        check(
            (s0_req.addr == word_t'(32'h0000_0004)) &&
            (s1_req.addr == word_t'(32'h0000_0048)) &&
            (s2_req.addr == word_t'(32'h0000_0020)) &&
            (s3_req.addr == word_t'(32'h0000_0100)),
            "Parallel requests carry correct local addresses"
        );

        check(
            master_pending == 4'b1111,
            "All four masters report pending"
        );

        s0_rsp = bus_success(word_t'(32'h1111_1111));
        s1_rsp = bus_success(word_t'(32'h2222_2222));
        s2_rsp = bus_success(word_t'(32'h3333_3333));
        s3_rsp = bus_success(word_t'(32'h4444_4444));

        #1;

        check(
            m0_rsp.ready && (m0_rsp.rdata == word_t'(32'h1111_1111)),
            "Parallel CPU_I response returns from ROM"
        );

        check(
            m1_rsp.ready && (m1_rsp.rdata == word_t'(32'h2222_2222)),
            "Parallel CPU_D response returns from RAM"
        );

        check(
            m2_rsp.ready && (m2_rsp.rdata == word_t'(32'h3333_3333)),
            "Parallel GPU response returns from GPU MMIO"
        );

        check(
            m3_rsp.ready && (m3_rsp.rdata == word_t'(32'h4444_4444)),
            "Parallel TPU response returns from DDR3"
        );

        @(posedge clk);
        @(negedge clk);

        clear_all();

        // ====================================================
        // SAME-SLAVE ROUND-ROBIN CONTENTION
        // ====================================================

        reset_dut();

        @(negedge clk);

        m1_req = make_request(word_t'(32'h0000_0100), BUS_READ, '0, BUS_STRB_NONE);
        m2_req = make_request(word_t'(32'h0000_0200), BUS_READ, '0, BUS_STRB_NONE);
        m3_req = make_request(word_t'(32'h0000_0300), BUS_READ, '0, BUS_STRB_NONE);

        s1_rsp = bus_success(word_t'(32'h0000_0001));

        #1;

        check(
            s1_req.addr == word_t'(32'h0000_0100),
            "RAM contention round 1 selects CPU_D"
        );

        @(posedge clk);
        @(negedge clk);
        #1;

        check(
            s1_req.addr == word_t'(32'h0000_0200),
            "RAM contention round 2 selects GPU"
        );

        @(posedge clk);
        @(negedge clk);
        #1;

        check(
            s1_req.addr == word_t'(32'h0000_0300),
            "RAM contention round 3 selects TPU"
        );

        @(posedge clk);
        @(negedge clk);
        #1;

        check(
            s1_req.addr == word_t'(32'h0000_0100),
            "RAM contention wraps to CPU_D"
        );

        @(posedge clk);
        @(negedge clk);

        clear_all();

        // ====================================================
        // SAME-ADDRESS READ/WRITE COLLISION
        // ====================================================
        //
        // The data RAM has one shared operation slot. A write and
        // a read to the same address must serialize; they may not
        // be admitted concurrently.
        // ====================================================

        reset_dut();

        @(negedge clk);

        m1_req = make_request(
            word_t'(32'h0000_0100),
            BUS_WRITE,
            word_t'(32'h1111_1111),
            BUS_STRB_ALL
        );

        m2_req = make_request(
            word_t'(32'h0000_0100),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        s1_rsp = bus_success(word_t'(32'h2222_2222));

        #1;

        check(
            s1_req.valid &&
            (s1_req.op == BUS_WRITE) &&
            (s1_req.addr == word_t'(32'h0000_0100)),
            "Same-address collision admits the first requester only"
        );

        check(
            m1_rsp.ready && !m2_rsp.ready,
            "Only the first same-address requester completes"
        );

        @(posedge clk);
        @(negedge clk);

        m1_req = '0;

        #1;

        check(
            s1_req.valid &&
            (s1_req.op == BUS_READ) &&
            (s1_req.addr == word_t'(32'h0000_0100)),
            "Same-address read follows the write"
        );

        check(
            m2_rsp.ready && !m1_rsp.ready,
            "Second same-address requester completes after the first"
        );

        @(posedge clk);
        @(negedge clk);

        clear_all();


        // ====================================================
        // BACKPRESSURE ISOLATION
        // ====================================================

        reset_dut();

        @(negedge clk);

        // RAM is backpressured; ROM is not.

        m1_req = make_request(word_t'(32'h0000_0048), BUS_READ, '0, BUS_STRB_NONE);
        m0_req = make_request(word_t'(32'h0000_0004), BUS_READ, '0, BUS_STRB_NONE);

        s1_rsp = '0;
        s0_rsp = bus_success(word_t'(32'hBEEF_0001));

        #1;

        check(
            s1_req.valid && (s1_req.addr == word_t'(32'h0000_0048)),
            "Backpressured RAM request remains valid"
        );

        check(
            s0_req.valid && m0_rsp.ready &&
            (m0_rsp.rdata == word_t'(32'hBEEF_0001)),
            "ROM transaction completes while RAM is stalled"
        );

        check(
            !m1_rsp.ready,
            "Stalled RAM master receives no response"
        );

        @(posedge clk);
        @(negedge clk);

        m0_req = '0;
        s0_rsp = '0;

        #1;

        check(
            s1_req.valid &&
            (s1_req.addr == word_t'(32'h0000_0048)) &&
            !m1_rsp.ready,
            "RAM request stays stable after ROM completes"
        );

        check(
            s1_req === m1_req,
            "Stalled RAM request fields remain identical"
        );

        check(
            slave_active[1],
            "RAM slave port reports an active owner"
        );

        s1_rsp = bus_success(word_t'(32'hBEEF_0002));

        #1;

        check(
            m1_rsp.ready && (m1_rsp.rdata == word_t'(32'hBEEF_0002)),
            "Stalled RAM transaction completes after release"
        );

        @(posedge clk);
        @(negedge clk);

        clear_all();

        // ====================================================
        // LONG-LATENCY DDR3 DOES NOT BLOCK ROM
        // ====================================================

        reset_dut();

        @(negedge clk);

        m1_req = make_request(
            word_t'(32'h8000_0100),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        m0_req = make_request(
            word_t'(32'h0000_0004),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        s3_rsp = '0;
        s0_rsp = bus_success(word_t'(32'h1234_5678));

        #1;

        check(
            s3_req.valid && !m1_rsp.ready,
            "DDR3 request pending under stall"
        );

        check(
            s0_req.valid && m0_rsp.ready &&
            (m0_rsp.rdata == word_t'(32'h1234_5678)),
            "ROM completes while DDR3 is stalled"
        );

        @(posedge clk);
        @(negedge clk);

        m0_req = '0;
        s0_rsp = '0;

        #1;

        check(
            s3_req.valid && !m1_rsp.ready,
            "DDR3 request remains pending after ROM completes"
        );

        repeat (3) @(posedge clk);

        @(negedge clk);

        check(
            s3_req.valid && !m1_rsp.ready,
            "DDR3 request stable across a long stall"
        );

        s3_rsp = bus_success(word_t'(32'hCAFE_F00D));

        #1;

        check(
            m1_rsp.ready && (m1_rsp.rdata == word_t'(32'hCAFE_F00D)),
            "DDR3 completes after long latency"
        );

        @(posedge clk);
        @(negedge clk);

        clear_all();

        // ====================================================
        // NO SPURIOUS RESPONSES
        // ====================================================

        reset_dut();

        @(negedge clk);

        m1_req = make_request(word_t'(32'h1000_0020), BUS_READ, '0, BUS_STRB_NONE);

        #1;

        check(
            !m0_rsp.ready && !m2_rsp.ready && !m3_rsp.ready,
            "Idle masters receive no response"
        );

        check(
            !s0_req.valid && !s1_req.valid && !s3_req.valid,
            "GPU MMIO access reaches only the GPU slave"
        );

        s2_rsp = bus_success(word_t'(32'h0000_0010));

        #1;

        check(
            m1_rsp.ready && !m0_rsp.ready &&
            !m2_rsp.ready && !m3_rsp.ready,
            "Only the requesting master receives the response"
        );

        @(posedge clk);
        @(negedge clk);

        clear_all();

        // ====================================================
        // RESET WITH OUTSTANDING TRANSACTION
        // ====================================================

        reset_dut();

        @(negedge clk);

        m1_req = make_request(
            word_t'(32'h0000_0048),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        s1_rsp = '0;

        @(posedge clk);
        @(negedge clk);

        check(
            slave_active[1],
            "RAM transaction active before reset"
        );

        rst = 1'b1;

        @(posedge clk);
        #1;

        check_no_slave_requests(
            "Reset clears all outstanding slave requests"
        );

        check(
            !m0_rsp.ready && !m1_rsp.ready &&
            !m2_rsp.ready && !m3_rsp.ready,
            "Reset clears all outstanding master responses"
        );

        @(negedge clk);

        rst = 1'b0;
        m1_req = '0;
        s1_rsp = '0;

        #1;

        // ====================================================
        // FINAL RESULTS
        // ====================================================

        $display("==========================================");
        $display("LACOODA STAGE 5 RPU CROSSBAR");
        $display("Tests:  %0d", tests);
        $display("Passed: %0d", tests - errors);
        $display("Failed: %0d", errors);
        $display("==========================================");

        if (errors != 0)
            $fatal(1, "LACOODA STAGE 5 RPU CROSSBAR TEST FAILED");

        $display("LACOODA STAGE 5 RPU CROSSBAR TEST PASSED");
        $finish;

    end

    initial begin
        #400000;
        $fatal(1, "LACOODA Stage 5 RPU crossbar test timed out");
    end

endmodule
