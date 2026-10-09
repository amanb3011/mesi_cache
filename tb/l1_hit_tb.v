`timescale 1ns/1ps
`include "cache_defs.vh"

module l1_hit_tb;

    reg clk;
    reg reset;

    reg cpu_req;
    reg cpu_write_en;
    reg [`ADDR_WIDTH-1:0] cpu_addr;
    reg [`DATA_WIDTH-1:0] cpu_write_data;

    wire [`DATA_WIDTH-1:0] cpu_read_data;
    wire cpu_ready;
    wire l1_hit;

    wire l1_l2_req;
    wire l1_l2_write_en;
    wire [`ADDR_WIDTH-1:0] l1_l2_addr;
    wire [`DATA_WIDTH-1:0] l1_l2_write_data;

    wire [`DATA_WIDTH-1:0] l2_read_data;
    wire l2_ready;
    wire l2_hit;

    wire mem_req;
    wire mem_write_en;
    wire [`ADDR_WIDTH-1:0] mem_addr;
    wire [`DATA_WIDTH-1:0] mem_write_data;
    wire [`DATA_WIDTH-1:0] mem_read_data;
    wire mem_ready;

    wire coherence_read_unused;
    wire [`ADDR_WIDTH-1:0] coherence_addr_unused;
    wire coherence_invalidate_unused;
    wire [`ADDR_WIDTH-1:0] coherence_invalidate_addr_unused;
    wire snoop_hit_unused;
    wire snoop_intervention_busy_unused;
    wire [1:0] debug_mesi_state;

    integer cycle_count;
    integer transaction_start_cycle;
    integer transaction_latency;
    reg monitor_active;
    reg saw_l2_req;
    reg saw_mem_req;
    reg first_l2_result_seen;
    reg first_l2_hit;

    l1_cache l1 (
        .clk(clk), .reset(reset),
        .req(cpu_req), .write_en(cpu_write_en),
        .addr(cpu_addr), .write_data(cpu_write_data),
        .read_data(cpu_read_data), .ready(cpu_ready), .hit(l1_hit),
        .l2_req(l1_l2_req), .l2_write_en(l1_l2_write_en),
        .l2_addr(l1_l2_addr), .l2_write_data(l1_l2_write_data),
        .l2_read_data(l2_read_data), .l2_ready(l2_ready),
        .coherence_read(coherence_read_unused),
        .coherence_addr(coherence_addr_unused),
        .coherence_shared(1'b0),
        .coherence_intervention_busy(1'b0),
        .snoop_intervention_busy(snoop_intervention_busy_unused),
        .coherence_invalidate(coherence_invalidate_unused),
        .coherence_invalidate_addr(coherence_invalidate_addr_unused),
        .snoop_read(1'b0),
        .snoop_addr({`ADDR_WIDTH{1'b0}}),
        .snoop_hit(snoop_hit_unused),
        .snoop_invalidate(1'b0),
        .snoop_invalidate_addr({`ADDR_WIDTH{1'b0}}),
        .debug_mesi_state(debug_mesi_state)
    );

    l2_cache l2 (
        .clk(clk), .reset(reset),
        .req(l1_l2_req), .write_en(l1_l2_write_en),
        .addr(l1_l2_addr), .write_data(l1_l2_write_data),
        .read_data(l2_read_data), .ready(l2_ready), .hit(l2_hit),
        .mem_req(mem_req), .mem_write_en(mem_write_en),
        .mem_addr(mem_addr), .mem_write_data(mem_write_data),
        .mem_read_data(mem_read_data), .mem_ready(mem_ready)
    );

    main_memory memory (
        .clk(clk), .reset(reset),
        .req(mem_req), .write_en(mem_write_en),
        .addr(mem_addr), .write_data(mem_write_data),
        .read_data(mem_read_data), .ready(mem_ready)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (monitor_active) begin
            if (l1_l2_req) saw_l2_req <= 1'b1;
            if (mem_req) saw_mem_req <= 1'b1;
            if (l2_ready && !first_l2_result_seen) begin
                first_l2_result_seen <= 1'b1;
                first_l2_hit <= l2_hit;
            end
        end
    end

    task automatic cpu_read;
        input [`ADDR_WIDTH-1:0] test_addr;
        begin
            saw_l2_req = 1'b0;
            saw_mem_req = 1'b0;
            first_l2_result_seen = 1'b0;
            first_l2_hit = 1'b0;
            monitor_active = 1'b1;

            @(negedge clk);
            cpu_addr = test_addr;
            cpu_write_en = 1'b0;
            cpu_req = 1'b1;
            transaction_start_cycle = cycle_count;

            @(negedge clk);
            cpu_req = 1'b0;

            wait(cpu_ready);
            #1;
            transaction_latency = cycle_count - transaction_start_cycle;
            monitor_active = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("waves/l1_hit.vcd");
        $dumpvars(0, l1_hit_tb);

        reset = 1'b1;
        cpu_req = 1'b0;
        cpu_write_en = 1'b0;
        cpu_addr = 0;
        cpu_write_data = 0;
        cycle_count = 0;
        transaction_start_cycle = 0;
        transaction_latency = 0;
        monitor_active = 1'b0;
        saw_l2_req = 1'b0;
        saw_mem_req = 1'b0;
        first_l2_result_seen = 1'b0;
        first_l2_hit = 1'b0;

        #20;
        reset = 1'b0;
        @(posedge clk);
        @(posedge clk);

        memory.memory[16'h0040 >> 2] = 32'h11111111;
        memory.memory[16'h0044 >> 2] = 32'h22222222;
        memory.memory[16'h0048 >> 2] = 32'h33333333;
        memory.memory[16'h004C >> 2] = 32'h44444444;

        $display("============================================================");
        $display("                    L1 HIT DEMONSTRATION");
        $display("============================================================");

        // Setup: first read fills the line into L1.
        cpu_read(16'h0040);

        if ((l1_hit == 1'b0) && saw_l2_req && first_l2_result_seen &&
            !first_l2_hit && saw_mem_req && (cpu_read_data == 32'h11111111))
            $display("SETUP | READ 0040 | L1:MISS | L2:MISS | MEM:YES | DATA:%h | LINE LOADED INTO L1 | PASS",
                     cpu_read_data);
        else
            $display("SETUP | READ 0040 | L1:%s | L2_FIRST_HIT:%b | MEM:%s | DATA:%h | FAIL",
                     l1_hit ? "HIT " : "MISS", first_l2_hit,
                     saw_mem_req ? "YES" : "NO ", cpu_read_data);

        // Demonstration transaction: same address must now hit in L1.
        cpu_read(16'h0040);

        if ((l1_hit == 1'b1) && !saw_l2_req && !saw_mem_req &&
            (cpu_read_data == 32'h11111111))
            $display("TEST  | READ 0040 | L1:HIT  | L2:NO ACCESS | MEM:NO | DATA:%h | LAT:%0d cycles | PASS",
                     cpu_read_data, transaction_latency);
        else
            $display("TEST  | READ 0040 | L1:%s | L2_REQ:%b | MEM:%s | DATA:%h | LAT:%0d cycles | FAIL",
                     l1_hit ? "HIT " : "MISS", saw_l2_req,
                     saw_mem_req ? "YES" : "NO ", cpu_read_data, transaction_latency);

        #20;
        $finish;
    end

endmodule
