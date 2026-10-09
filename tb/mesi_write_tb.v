`timescale 1ns/1ps
`include "cache_defs.vh"

module mesi_write_tb;

    localparam MESI_I = 2'b00;
    localparam MESI_S = 2'b01;
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


    task automatic core1_read;
        input [`ADDR_WIDTH-1:0] test_addr;

        begin
            @(negedge clk);

            core1_addr = test_addr;
            core1_write_en = 1'b0;
            core1_req = 1'b1;

            @(negedge clk);
            core1_req = 1'b0;

            wait(core1_ready);

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

        $dumpfile("waves/mesi_write.vcd");
        $dumpvars(0, mesi_write_tb);


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
        // Initialize memory line at 0x0040
        // ------------------------------------------------------------

        dut.memory.memory[16'h0040 >> 2] = 32'h11111111;
        dut.memory.memory[16'h0044 >> 2] = 32'h22222222;
        dut.memory.memory[16'h0048 >> 2] = 32'h33333333;
        dut.memory.memory[16'h004C >> 2] = 32'h44444444;


        $display("");
        $display("============================================================");
        $display("          MESI WRITE + INVALIDATION DEMONSTRATION");
        $display("============================================================");

        $display(
            "INITIAL | ADDRESS 0040 | CORE0:I | CORE1:I"
        );


        // ------------------------------------------------------------
        // STEP 1:
        // Core 0 reads first.
        // Expected: I,I -> E,I
        // ------------------------------------------------------------

        core0_read(16'h0040);

        if ((dut.l1_0.mesi_state[4] == 2'b10) &&
            (dut.l1_1.mesi_state[4] == MESI_I)) begin

            $display(
                "STEP 1  | CORE0 READ 0040 | DATA:%h | STATES:I,I -> E,I | PASS",
                core0_read_data
            );

        end
        else begin

            $display(
                "STEP 1  | CORE0 READ 0040 | STATES:%b,%b | EXPECTED:E,I | FAIL",
                dut.l1_0.mesi_state[4],
                dut.l1_1.mesi_state[4]
            );

            $finish;
        end


        // ------------------------------------------------------------
        // STEP 2:
        // Core 1 reads the same line.
        // Expected: E,I -> S,S
        // ------------------------------------------------------------

        core1_read(16'h0040);

        if ((dut.l1_0.mesi_state[4] == MESI_S) &&
            (dut.l1_1.mesi_state[4] == MESI_S)) begin

            $display(
                "STEP 2  | CORE1 READ 0040 | DATA:%h | STATES:E,I -> S,S | PASS",
                core1_read_data
            );

        end
        else begin

            $display(
                "STEP 2  | CORE1 READ 0040 | STATES:%b,%b | EXPECTED:S,S | FAIL",
                dut.l1_0.mesi_state[4],
                dut.l1_1.mesi_state[4]
            );

            $finish;
        end


        // ------------------------------------------------------------
        // STEP 3:
        // Core 0 writes to the shared line.
        // Expected: S,S -> M,I
        // Core 1 must be invalidated.
        // ------------------------------------------------------------

        core0_write(16'h0040, 32'hDEADBEEF);

        if ((dut.l1_0.mesi_state[4] == MESI_M) &&
            (dut.l1_1.mesi_state[4] == MESI_I) &&
            (dut.l1_0.data[16] == 32'hDEADBEEF)) begin

            $display(
                "STEP 3  | CORE0 WRITE 0040=DEADBEEF | STATES:S,S -> M,I | PASS"
            );

            $display(
                "RESULT  | CORE0 OWNS MODIFIED COPY | CORE1 INVALIDATED | FINAL:M,I | PASS"
            );

        end
        else begin

            $display(
                "STEP 3  | CORE0 WRITE 0040=DEADBEEF | FINAL:%b,%b | C0 DATA:%h | FAIL",
                dut.l1_0.mesi_state[4],
                dut.l1_1.mesi_state[4],
                dut.l1_0.data[16]
            );

            $display(
                "RESULT  | MESI WRITE + INVALIDATION DEMONSTRATION | FAIL"
            );
        end


        $display("============================================================");
        $display("");


        #20;
        $finish;

    end

endmodule