`timescale 1ns/1ps

module instruction_rom_tb;
    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rst = 1'b1;
    bus_pkg::bus_req_s req;
    bus_pkg::bus_rsp_s rsp;

    instruction_rom dut (.clk(clk), .rst(rst),
                         .cpu_instr_bus_req(req), .cpu_instr_bus_rsp(rsp));

    initial begin
        req = '0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        req.valid = 1'b1;
        req.op = bus_pkg::BUS_READ;
        req.addr = '0;
        #1;
        assert (!rsp.ready) else $fatal(1, "ROM responded combinationally");
        @(posedge clk);
        #1;
        assert (rsp.ready && !rsp.error && rsp.rdata === dut.rom_words[0])
            else $fatal(1, "registered ROM read failed");
        @(posedge clk);
        #1;
        assert (!rsp.ready) else $fatal(1, "ROM response did not clear");

        @(negedge clk);
        req.addr = cpu_pkg::word_t'(memory_pkg::INSTRUCTION_ROM_BYTES);
        @(posedge clk);
        #1;
        assert (rsp.ready && rsp.error) else $fatal(1, "ROM range error missing");
        @(posedge clk);
        @(negedge clk);
        req.addr = cpu_pkg::word_t'(1);
        @(posedge clk);
        #1;
        assert (rsp.ready && rsp.error) else $fatal(1, "ROM alignment error missing");
        $display("REGISTERED INSTRUCTION ROM TEST PASSED");
        $finish;
    end
endmodule
