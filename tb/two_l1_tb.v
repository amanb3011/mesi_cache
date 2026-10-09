`timescale 1ns/1ps
`include "cache_defs.vh"

module two_l1_tb;

    reg clk;
    reg reset;

    reg core0_req;
    reg core0_write_en;
    reg [`ADDR_WIDTH-1:0] core0_addr;
    reg [`DATA_WIDTH-1:0] core0_write_data;
    wire [`DATA_WIDTH-1:0] core0_read_data;
    wire core0_ready;
    wire core0_l1_hit;
    wire [1:0] core0_mesi_state;

    reg core1_req;
    reg core1_write_en;
    reg [`ADDR_WIDTH-1:0] core1_addr;
    reg [`DATA_WIDTH-1:0] core1_write_data;
    wire [`DATA_WIDTH-1:0] core1_read_data;
    wire core1_ready;
    wire core1_l1_hit;
    wire [1:0] core1_mesi_state;

    wire shared_l2_hit;

    cache_system dut (
        .clk(clk), .reset(reset),

        .core0_req(core0_req),
        .core0_write_en(core0_write_en),
        .core0_addr(core0_addr),
        .core0_write_data(core0_write_data),
        .core0_read_data(core0_read_data),
        .core0_ready(core0_ready),
        .core0_l1_hit(core0_l1_hit),
        .core0_mesi_state(core0_mesi_state),

        .core1_req(core1_req),
        .core1_write_en(core1_write_en),
        .core1_addr(core1_addr),
        .core1_write_data(core1_write_data),
        .core1_read_data(core1_read_data),
        .core1_ready(core1_ready),
        .core1_l1_hit(core1_l1_hit),
        .core1_mesi_state(core1_mesi_state),

        .shared_l2_hit(shared_l2_hit)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    task automatic simultaneous_read;

        input [`ADDR_WIDTH-1:0] addr0;
        input [`ADDR_WIDTH-1:0] addr1;

        begin

            @(negedge clk);

            core0_addr = addr0;
            core0_write_en = 1'b0;
            core0_req = 1'b1;

            core1_addr = addr1;
            core1_write_en = 1'b0;
            core1_req = 1'b1;

            @(negedge clk);

            core0_req = 1'b0;
            core1_req = 1'b0;

            fork
                begin
                    wait(core0_ready);
                end

                begin
                    wait(core1_ready);
                end
            join

            @(negedge clk);

        end

    endtask


    initial begin

        $dumpfile("waves/two_l1.vcd");
        $dumpvars(0, two_l1_tb);


        reset = 1'b1;

        core0_req = 1'b0;
        core0_write_en = 1'b0;
        core0_addr = 0;
        core0_write_data = 0;

        core1_req = 1'b0;
        core1_write_en = 1'b0;
        core1_addr = 0;
        core1_write_data = 0;


        #20;
        reset = 1'b0;

        @(posedge clk);
        @(posedge clk);


        // ------------------------------------------------------------
        // Initialize two different memory lines
        // ------------------------------------------------------------

        dut.memory.memory[16'h0040 >> 2] = 32'hAAAAAAAA;
        dut.memory.memory[16'h0044 >> 2] = 32'h11111111;
        dut.memory.memory[16'h0048 >> 2] = 32'h22222222;
        dut.memory.memory[16'h004C >> 2] = 32'h33333333;

        dut.memory.memory[16'h0080 >> 2] = 32'hBBBBBBBB;
        dut.memory.memory[16'h0084 >> 2] = 32'h44444444;
        dut.memory.memory[16'h0088 >> 2] = 32'h55555555;
        dut.memory.memory[16'h008C >> 2] = 32'h66666666;


        $display("");
        $display("============================================================");
        $display("          SIMULTANEOUS REQUEST DEMONSTRATION");
        $display("============================================================");

        $display(
            "ISSUE  | C0 READ 0040 | C1 READ 0080 | BOTH REQUESTS ASSERTED TOGETHER"
        );


        // ------------------------------------------------------------
        // Both cores issue requests in the same cycle
        // ------------------------------------------------------------

        simultaneous_read(16'h0040, 16'h0080);


        // ------------------------------------------------------------
        // Report individual results
        // ------------------------------------------------------------

        if (core0_read_data == 32'hAAAAAAAA)
            $display(
                "CORE 0 | READ 0040 | DATA:%h | PASS",
                core0_read_data
            );
        else
            $display(
                "CORE 0 | READ 0040 | DATA:%h | EXPECTED:aaaaaaaa | FAIL",
                core0_read_data
            );


        if (core1_read_data == 32'hBBBBBBBB)
            $display(
                "CORE 1 | READ 0080 | DATA:%h | PASS",
                core1_read_data
            );
        else
            $display(
                "CORE 1 | READ 0080 | DATA:%h | EXPECTED:bbbbbbbb | FAIL",
                core1_read_data
            );


        // ------------------------------------------------------------
        // Final result
        // ------------------------------------------------------------

        if ((core0_read_data == 32'hAAAAAAAA) &&
            (core1_read_data == 32'hBBBBBBBB)) begin

            $display(
                "RESULT | BOTH SIMULTANEOUS REQUESTS SERVICED CORRECTLY | PASS"
            );

        end
        else begin

            $display(
                "RESULT | SIMULTANEOUS REQUEST DEMONSTRATION | FAIL"
            );

        end


        $display("============================================================");
        $display("");


        #20;
        $finish;

    end

endmodule