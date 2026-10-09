`timescale 1ns/1ps
`include "cache_defs.vh"

module dirty_eviction_tb;

    localparam MESI_I = 2'b00;
    localparam MESI_E = 2'b10;
    localparam MESI_M = 2'b11;

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
        .clk(clk),
        .reset(reset),

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


    task automatic core0_read;
        input [`ADDR_WIDTH-1:0] test_addr;

        begin
            @(negedge clk);

            core0_addr = test_addr;
            core0_write_en = 1'b0;
            core0_req = 1'b1;

            @(negedge clk);
            core0_req = 1'b0;

            wait(core0_ready);

            @(negedge clk);
        end
    endtask


    task automatic core0_write;
        input [`ADDR_WIDTH-1:0] test_addr;
        input [`DATA_WIDTH-1:0] test_data;

        begin
            @(negedge clk);

            core0_addr = test_addr;
            core0_write_en = 1'b1;
            core0_write_data = test_data;
            core0_req = 1'b1;

            @(negedge clk);
            core0_req = 1'b0;

            wait(core0_ready);

            @(negedge clk);
        end
    endtask


    initial begin

        $dumpfile("waves/dirty_eviction.vcd");
        $dumpvars(0, dirty_eviction_tb);


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
        // Initialize two conflicting L1 lines:
        // 0x0040 and 0x0140 have the same L1 index [7:4] = 4
        // ------------------------------------------------------------

        dut.memory.memory[16'h0040 >> 2] = 32'h11111111;
        dut.memory.memory[16'h0044 >> 2] = 32'h22222222;
        dut.memory.memory[16'h0048 >> 2] = 32'h33333333;
        dut.memory.memory[16'h004C >> 2] = 32'h44444444;

        dut.memory.memory[16'h0140 >> 2] = 32'hAAAAAAAA;
        dut.memory.memory[16'h0144 >> 2] = 32'hBBBBBBBB;
        dut.memory.memory[16'h0148 >> 2] = 32'hCCCCCCCC;
        dut.memory.memory[16'h014C >> 2] = 32'hDDDDDDDD;


        $display("");
        $display("============================================================");
        $display("              DIRTY EVICTION DEMONSTRATION");
        $display("============================================================");

        $display(
            "INITIAL | 0040 AND 0140 MAP TO SAME L1 INDEX | CORE0:I"
        );


        // ------------------------------------------------------------
        // STEP 1
        // Read 0040 into Core 0 L1.
        // Expected state: E
        // ------------------------------------------------------------

        core0_read(16'h0040);

        if ((core0_read_data == 32'h11111111) &&
            (dut.l1_0.mesi_state[4] == MESI_E)) begin

            $display(
                "STEP 1  | CORE0 READ 0040 | DATA:%h | STATE:I -> E | PASS",
                core0_read_data
            );

        end
        else begin

            $display(
                "STEP 1  | CORE0 READ 0040 | DATA:%h | STATE:%b | EXPECTED:E | FAIL",
                core0_read_data,
                dut.l1_0.mesi_state[4]
            );

            $finish;
        end


        // ------------------------------------------------------------
        // STEP 2
        // Modify 0040.
        // Expected state: M
        // ------------------------------------------------------------

        core0_write(16'h0040, 32'hDEADBEEF);

        if ((dut.l1_0.mesi_state[4] == MESI_M) &&
            (dut.l1_0.data[16] == 32'hDEADBEEF)) begin

            $display(
                "STEP 2  | CORE0 WRITE 0040=DEADBEEF | STATE:E -> M | DIRTY LINE CREATED | PASS"
            );

        end
        else begin

            $display(
                "STEP 2  | CORE0 WRITE 0040 | STATE:%b | DATA:%h | FAIL",
                dut.l1_0.mesi_state[4],
                dut.l1_0.data[16]
            );

            $finish;
        end


        // ------------------------------------------------------------
        // STEP 3
        // Access conflicting address 0140.
        // Since both map to the same L1 index, modified 0040 must be
        // written back before 0140 replaces it.
        // ------------------------------------------------------------

        core0_read(16'h0140);

        if ((core0_read_data == 32'hAAAAAAAA) &&
            (dut.l2.data[4] == 32'hDEADBEEF)) begin

            $display(
                "STEP 3  | CORE0 READ 0140 | L1 CONFLICT WITH 0040 | WRITE-BACK 0040=DEADBEEF | PASS"
            );

            $display(
                "STEP 4  | 0140 INSTALLED IN L1 | DATA:%h | PASS",
                core0_read_data
            );

        end
        else begin

            $display(
                "STEP 3  | CORE0 READ 0140 | DATA:%h | L2(0040):%h | FAIL",
                core0_read_data,
                dut.l2.data[4]
            );

            $finish;
        end


        // ------------------------------------------------------------
        // STEP 5
        // Read 0040 again.
        // The modified value must have been preserved by write-back.
        // ------------------------------------------------------------

        core0_read(16'h0040);

        if (core0_read_data == 32'hDEADBEEF) begin

            $display(
                "STEP 5  | CORE0 READ 0040 AGAIN | DATA:%h | MODIFIED DATA PRESERVED | PASS",
                core0_read_data
            );

            $display(
                "RESULT  | DIRTY 0040 WRITTEN BACK BEFORE REPLACEMENT | PASS"
            );

        end
        else begin

            $display(
                "STEP 5  | CORE0 READ 0040 AGAIN | DATA:%h | EXPECTED:DEADBEEF | FAIL",
                core0_read_data
            );

            $display(
                "RESULT  | DIRTY EVICTION DEMONSTRATION | FAIL"
            );
        end


        $display("============================================================");
        $display("");


        #20;
        $finish;

    end

endmodule