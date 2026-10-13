`timescale 1ns/1ps

module data_ram_tb;
    import cpu_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rst = 1'b1;
    bus_pkg::bus_req_s data_ram_req;
    bus_pkg::bus_rsp_s data_ram_rsp;

    data_ram dut (
        .clk(clk), .rst(rst), .data_ram_req(data_ram_req), .data_ram_rsp(data_ram_rsp)
    );

    task automatic transact(
        input bus_pkg::bus_op_e op,
        input word_t addr,
        input word_t wdata,
        input word_t expected_rdata
    );
        @(negedge clk);
        data_ram_req.valid = 1'b1;
        data_ram_req.op = op;
        data_ram_req.addr = addr;
        data_ram_req.wdata = wdata;
        #1;
        if (data_ram_rsp.ready !== 1'b0)
            $fatal(1, "memory responded before synchronous access");
        @(posedge clk);
        #1;
        if (data_ram_rsp.ready !== 1'b1)
            $fatal(1, "memory did not complete access at address %h", addr);
        if (op == bus_pkg::BUS_READ && data_ram_rsp.rdata !== expected_rdata)
            $fatal(1, "read at %h: expected %h, got %h", addr, expected_rdata, data_ram_rsp.rdata);
        @(negedge clk);
        data_ram_req.valid = 1'b0;
        @(posedge clk);
        #1;
        if (data_ram_rsp.ready !== 1'b0)
            $fatal(1, "memory response did not clear");
    endtask

    initial begin
        $dumpfile("data_ram.vcd");
        $dumpvars(0, data_ram_tb);
        data_ram_req = '0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        transact(bus_pkg::BUS_WRITE, word_t'(WORD_BYTES), word_t'(32'hDEAD_BEEF), '0);
        transact(bus_pkg::BUS_READ, word_t'(WORD_BYTES), '0, word_t'(32'hDEAD_BEEF));
        transact(bus_pkg::BUS_READ, word_t'(2 * WORD_BYTES), '0, '0);
        transact(bus_pkg::BUS_WRITE, word_t'(1), '1, '0);
        transact(bus_pkg::BUS_READ, word_t'(0), '0, '0);
        transact(bus_pkg::BUS_READ, word_t'(WORD_BYTES + 1), '0, '0);
        $display("PASS: synchronous data BRAM handshake, read/write, and alignment");
        $finish;
    end
endmodule
