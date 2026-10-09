`include "cache_defs.vh"

module cache_system (

    input clk,
    input reset,

    // =====================================================
    // CORE 0
    // =====================================================

    input core0_req,
    input core0_write_en,

    input [`ADDR_WIDTH-1:0]
        core0_addr,

    input [`DATA_WIDTH-1:0]
        core0_write_data,

    output [`DATA_WIDTH-1:0]
        core0_read_data,

    output core0_ready,
    output core0_l1_hit,

    output [1:0]
        core0_mesi_state,

    // =====================================================
    // CORE 1
    // =====================================================

    input core1_req,
    input core1_write_en,

    input [`ADDR_WIDTH-1:0]
        core1_addr,

    input [`DATA_WIDTH-1:0]
        core1_write_data,

    output [`DATA_WIDTH-1:0]
        core1_read_data,

    output core1_ready,
    output core1_l1_hit,

    output [1:0]
        core1_mesi_state,

    // =====================================================
    // DEBUG
    // =====================================================

    output shared_l2_hit

);


    // =====================================================
    // L1-0 -> BUS
    // =====================================================

    wire l1_0_bus_req;
    wire l1_0_bus_write_en;

    wire [`ADDR_WIDTH-1:0]
        l1_0_bus_addr;

    wire [`DATA_WIDTH-1:0]
        l1_0_bus_write_data;

    wire [`DATA_WIDTH-1:0]
        l1_0_bus_read_data;

    wire l1_0_bus_ready;


    // =====================================================
    // L1-1 -> BUS
    // =====================================================

    wire l1_1_bus_req;
    wire l1_1_bus_write_en;

    wire [`ADDR_WIDTH-1:0]
        l1_1_bus_addr;

    wire [`DATA_WIDTH-1:0]
        l1_1_bus_write_data;

    wire [`DATA_WIDTH-1:0]
        l1_1_bus_read_data;

    wire l1_1_bus_ready;


    // =====================================================
    // READ COHERENCE
    // =====================================================

    wire l1_0_coherence_read;

    wire [`ADDR_WIDTH-1:0]
        l1_0_coherence_addr;

    wire l1_1_coherence_read;

    wire [`ADDR_WIDTH-1:0]
        l1_1_coherence_addr;

    wire l1_0_snoop_hit;
    wire l1_1_snoop_hit;


    // =====================================================
    // INTERVENTION
    // =====================================================

    wire l1_0_intervention_busy;
    wire l1_1_intervention_busy;


    // =====================================================
    // INVALIDATION
    // =====================================================

    wire l1_0_invalidate;

    wire [`ADDR_WIDTH-1:0]
        l1_0_invalidate_addr;

    wire l1_1_invalidate;

    wire [`ADDR_WIDTH-1:0]
        l1_1_invalidate_addr;


    // =====================================================
    // BUS -> L2
    // =====================================================

    wire bus_l2_req;
    wire bus_l2_write_en;

    wire [`ADDR_WIDTH-1:0]
        bus_l2_addr;

    wire [`DATA_WIDTH-1:0]
        bus_l2_write_data;

    wire [`DATA_WIDTH-1:0]
        l2_read_data;

    wire l2_ready;


    // =====================================================
    // L2 -> MEMORY
    // =====================================================

    wire mem_req;
    wire mem_write_en;

    wire [`ADDR_WIDTH-1:0]
        mem_addr;

    wire [`DATA_WIDTH-1:0]
        mem_write_data;

    wire [`DATA_WIDTH-1:0]
        mem_read_data;

    wire mem_ready;


    // =====================================================
    // L1 CACHE 0
    // =====================================================

    l1_cache l1_0 (

        .clk(clk),
        .reset(reset),

        .req(core0_req),
        .write_en(core0_write_en),

        .addr(core0_addr),
        .write_data(core0_write_data),

        .read_data(core0_read_data),
        .ready(core0_ready),
        .hit(core0_l1_hit),

        .l2_req(l1_0_bus_req),
        .l2_write_en(l1_0_bus_write_en),

        .l2_addr(l1_0_bus_addr),

        .l2_write_data(
            l1_0_bus_write_data
        ),

        .l2_read_data(
            l1_0_bus_read_data
        ),

        .l2_ready(
            l1_0_bus_ready
        ),

        // ---------------------------------------------
        // Core 0 asks about a line
        // ---------------------------------------------

        .coherence_read(
            l1_0_coherence_read
        ),

        .coherence_addr(
            l1_0_coherence_addr
        ),

        .coherence_shared(
            l1_1_snoop_hit
        ),

        // ---------------------------------------------
        // Wait if Core 1 is writing back M
        // ---------------------------------------------

        .coherence_intervention_busy(
            l1_1_intervention_busy
        ),

        // ---------------------------------------------
        // Core 0 intervention status
        // ---------------------------------------------

        .snoop_intervention_busy(
            l1_0_intervention_busy
        ),

        // ---------------------------------------------
        // Core 0 snoops Core 1 read
        // ---------------------------------------------

        .snoop_read(
            l1_1_coherence_read
        ),

        .snoop_addr(
            l1_1_coherence_addr
        ),

        .snoop_hit(
            l1_0_snoop_hit
        ),

        // ---------------------------------------------
        // Core 0 invalidation output
        // ---------------------------------------------

        .coherence_invalidate(
            l1_0_invalidate
        ),

        .coherence_invalidate_addr(
            l1_0_invalidate_addr
        ),

        // ---------------------------------------------
        // Core 0 snoops Core 1 invalidation
        // ---------------------------------------------

        .snoop_invalidate(
            l1_1_invalidate
        ),

        .snoop_invalidate_addr(
            l1_1_invalidate_addr
        ),

        .debug_mesi_state(
            core0_mesi_state
        )

    );


    // =====================================================
    // L1 CACHE 1
    // =====================================================

    l1_cache l1_1 (

        .clk(clk),
        .reset(reset),

        .req(core1_req),
        .write_en(core1_write_en),

        .addr(core1_addr),
        .write_data(core1_write_data),

        .read_data(core1_read_data),
        .ready(core1_ready),
        .hit(core1_l1_hit),

        .l2_req(l1_1_bus_req),
        .l2_write_en(l1_1_bus_write_en),

        .l2_addr(l1_1_bus_addr),

        .l2_write_data(
            l1_1_bus_write_data
        ),

        .l2_read_data(
            l1_1_bus_read_data
        ),

        .l2_ready(
            l1_1_bus_ready
        ),

        // ---------------------------------------------
        // Core 1 asks about a line
        // ---------------------------------------------

        .coherence_read(
            l1_1_coherence_read
        ),

        .coherence_addr(
            l1_1_coherence_addr
        ),

        .coherence_shared(
            l1_0_snoop_hit
        ),

        // ---------------------------------------------
        // Wait if Core 0 is writing back M
        // ---------------------------------------------

        .coherence_intervention_busy(
            l1_0_intervention_busy
        ),

        // ---------------------------------------------
        // Core 1 intervention status
        // ---------------------------------------------

        .snoop_intervention_busy(
            l1_1_intervention_busy
        ),

        // ---------------------------------------------
        // Core 1 snoops Core 0 read
        // ---------------------------------------------

        .snoop_read(
            l1_0_coherence_read
        ),

        .snoop_addr(
            l1_0_coherence_addr
        ),

        .snoop_hit(
            l1_1_snoop_hit
        ),

        // ---------------------------------------------
        // Core 1 invalidation output
        // ---------------------------------------------

        .coherence_invalidate(
            l1_1_invalidate
        ),

        .coherence_invalidate_addr(
            l1_1_invalidate_addr
        ),

        // ---------------------------------------------
        // Core 1 snoops Core 0 invalidation
        // ---------------------------------------------

        .snoop_invalidate(
            l1_0_invalidate
        ),

        .snoop_invalidate_addr(
            l1_0_invalidate_addr
        ),

        .debug_mesi_state(
            core1_mesi_state
        )

    );


    // =====================================================
    // SHARED BUS
    // =====================================================

    shared_bus bus (

        .clk(clk),
        .reset(reset),

        .l1_0_req(
            l1_0_bus_req
        ),

        .l1_0_write_en(
            l1_0_bus_write_en
        ),

        .l1_0_addr(
            l1_0_bus_addr
        ),

        .l1_0_write_data(
            l1_0_bus_write_data
        ),

        .l1_0_read_data(
            l1_0_bus_read_data
        ),

        .l1_0_ready(
            l1_0_bus_ready
        ),

        .l1_1_req(
            l1_1_bus_req
        ),

        .l1_1_write_en(
            l1_1_bus_write_en
        ),

        .l1_1_addr(
            l1_1_bus_addr
        ),

        .l1_1_write_data(
            l1_1_bus_write_data
        ),

        .l1_1_read_data(
            l1_1_bus_read_data
        ),

        .l1_1_ready(
            l1_1_bus_ready
        ),

        .l2_req(
            bus_l2_req
        ),

        .l2_write_en(
            bus_l2_write_en
        ),

        .l2_addr(
            bus_l2_addr
        ),

        .l2_write_data(
            bus_l2_write_data
        ),

        .l2_read_data(
            l2_read_data
        ),

        .l2_ready(
            l2_ready
        )

    );


    // =====================================================
    // SHARED L2
    // =====================================================

    l2_cache l2 (

        .clk(clk),
        .reset(reset),

        .req(
            bus_l2_req
        ),

        .write_en(
            bus_l2_write_en
        ),

        .addr(
            bus_l2_addr
        ),

        .write_data(
            bus_l2_write_data
        ),

        .read_data(
            l2_read_data
        ),

        .ready(
            l2_ready
        ),

        .hit(
            shared_l2_hit
        ),

        .mem_req(
            mem_req
        ),

        .mem_write_en(
            mem_write_en
        ),

        .mem_addr(
            mem_addr
        ),

        .mem_write_data(
            mem_write_data
        ),

        .mem_read_data(
            mem_read_data
        ),

        .mem_ready(
            mem_ready
        )

    );


    // =====================================================
    // MAIN MEMORY
    // =====================================================

    main_memory memory (

        .clk(clk),
        .reset(reset),

        .req(
            mem_req
        ),

        .write_en(
            mem_write_en
        ),

        .addr(
            mem_addr
        ),

        .write_data(
            mem_write_data
        ),

        .read_data(
            mem_read_data
        ),

        .ready(
            mem_ready
        )

    );

endmodule