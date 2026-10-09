`include "cache_defs.vh"

module l1_cache (
    input clk,
    input reset,

    // Core interface
    input req,
    input write_en,
    input [`ADDR_WIDTH-1:0] addr,
    input [`DATA_WIDTH-1:0] write_data,
    output reg [`DATA_WIDTH-1:0] read_data,
    output reg ready,
    output reg hit,

    // Lower level / shared bus
    output reg l2_req,
    output reg l2_write_en,
    output reg [`ADDR_WIDTH-1:0] l2_addr,
    output reg [`DATA_WIDTH-1:0] l2_write_data,
    input [`DATA_WIDTH-1:0] l2_read_data,
    input l2_ready,

    // Read coherence
    output reg coherence_read,
    output reg [`ADDR_WIDTH-1:0] coherence_addr,
    input coherence_shared,

    // Intervention
    input coherence_intervention_busy,
    output reg snoop_intervention_busy,

    // Invalidation
    output reg coherence_invalidate,
    output reg [`ADDR_WIDTH-1:0] coherence_invalidate_addr,

    // Snoop read
    input snoop_read,
    input [`ADDR_WIDTH-1:0] snoop_addr,
    output reg snoop_hit,

    // Snoop invalidation
    input snoop_invalidate,
    input [`ADDR_WIDTH-1:0] snoop_invalidate_addr,

    // Debug
    output reg [1:0] debug_mesi_state
);

    localparam MESI_I = 2'b00;
    localparam MESI_S = 2'b01;
    localparam MESI_E = 2'b10;
    localparam MESI_M = 2'b11;

    reg [7:0] tags [0:15];
    reg [`DATA_WIDTH-1:0] data [0:63];
    reg [1:0] mesi_state [0:15];

    reg [`ADDR_WIDTH-1:0] saved_addr;
    reg saved_write_en;
    reg [`DATA_WIDTH-1:0] saved_write_data;
    reg [7:0] saved_tag;
    reg [3:0] saved_index;
    reg [1:0] saved_word;
    reg saved_shared;
    reg [1:0] refill_word;
    integer latency_counter;

    // Modified-owner intervention
    reg [`ADDR_WIDTH-1:0] intervention_addr;
    reg [1:0] intervention_word;
    reg intervention_pending;

    // Dirty replacement writeback
    reg [`ADDR_WIDTH-1:0] eviction_base_addr;
    reg [3:0] eviction_index;
    reg [1:0] eviction_word;

    integer i;
    integer j;

    localparam IDLE                       = 5'd0;
    localparam L1_DELAY                   = 5'd1;
    localparam LOOKUP                     = 5'd2;
    localparam EVICTION_WRITE_REQUEST     = 5'd3;
    localparam EVICTION_WRITE_WAIT        = 5'd4;
    localparam COHERENCE_START            = 5'd5;
    localparam COHERENCE_CHECK            = 5'd6;
    localparam WAIT_INTERVENTION           = 5'd7;
    localparam L2_READ_REQUEST            = 5'd8;
    localparam L2_READ_WAIT               = 5'd9;
    localparam INVALIDATE                 = 5'd10;
    localparam INTERVENTION_WRITE_REQUEST = 5'd11;
    localparam INTERVENTION_WRITE_WAIT    = 5'd12;
    localparam COMPLETE                   = 5'd13;
    reg [4:0] state;

    // A snoop hits whenever this L1 has the requested line in S/E/M.
    always @(*) begin
        snoop_hit = 1'b0;

        if (snoop_read) begin
            if (
                mesi_state[snoop_addr[7:4]] != MESI_I &&
                tags[snoop_addr[7:4]] == snoop_addr[15:8]
            ) begin
                snoop_hit = 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;

            ready <= 1'b0;
            hit <= 1'b0;
            read_data <= 0;

            l2_req <= 1'b0;
            l2_write_en <= 1'b0;
            l2_addr <= 0;
            l2_write_data <= 0;

            coherence_read <= 1'b0;
            coherence_addr <= 0;
            coherence_invalidate <= 1'b0;
            coherence_invalidate_addr <= 0;

            snoop_intervention_busy <= 1'b0;
            debug_mesi_state <= MESI_I;

            saved_addr <= 0;
            saved_write_en <= 1'b0;
            saved_write_data <= 0;
            saved_tag <= 0;
            saved_index <= 0;
            saved_word <= 0;
            saved_shared <= 1'b0;
            refill_word <= 0;
            latency_counter <= 0;

            intervention_addr <= 0;
            intervention_word <= 0;
            intervention_pending <= 1'b0;

            eviction_base_addr <= 0;
            eviction_index <= 0;
            eviction_word <= 0;

            for (i = 0; i < 16; i = i + 1) begin
                tags[i] <= 0;
                mesi_state[i] <= MESI_I;

                for (j = 0; j < 4; j = j + 1) begin
                    data[(i * 4) + j] <= 0;
                end
            end
        end
        else begin
            // Default one-cycle signals
            ready <= 1'b0;
            l2_req <= 1'b0;
            coherence_read <= 1'b0;
            coherence_invalidate <= 1'b0;

            // Snoop an invalidation from the other L1.
            if (snoop_invalidate) begin
                if (
                    tags[snoop_invalidate_addr[7:4]] ==
                        snoop_invalidate_addr[15:8] &&
                    mesi_state[snoop_invalidate_addr[7:4]] != MESI_I
                ) begin
                    mesi_state[snoop_invalidate_addr[7:4]] <= MESI_I;
                    debug_mesi_state <= MESI_I;
                end
            end

            // Modified-owner intervention.
            // Start only while this L1 is otherwise idle.
            if (
                snoop_read &&
                tags[snoop_addr[7:4]] == snoop_addr[15:8] &&
                mesi_state[snoop_addr[7:4]] == MESI_M &&
                !intervention_pending &&
                state == IDLE
            ) begin
                intervention_addr <= snoop_addr;
                intervention_word <= 2'd0;
                intervention_pending <= 1'b1;
                snoop_intervention_busy <= 1'b1;
                state <= INTERVENTION_WRITE_REQUEST;
            end
            // Normal E -> S snoop transition.
            else if (snoop_read) begin
                if (
                    tags[snoop_addr[7:4]] == snoop_addr[15:8] &&
                    mesi_state[snoop_addr[7:4]] == MESI_E
                ) begin
                    mesi_state[snoop_addr[7:4]] <= MESI_S;
                    debug_mesi_state <= MESI_S;
                end
            end

            case (state)

                IDLE: begin
                    hit <= 1'b0;

                    if (req) begin
                        saved_addr <= addr;
                        saved_write_en <= write_en;
                        saved_write_data <= write_data;
                        saved_tag <= addr[15:8];
                        saved_index <= addr[7:4];
                        saved_word <= addr[3:2];

                        latency_counter <= `L1_LATENCY;
                        state <= L1_DELAY;
                    end
                end

                L1_DELAY: begin
                    if (latency_counter > 1)
                        latency_counter <= latency_counter - 1;
                    else
                        state <= LOOKUP;
                end

                LOOKUP: begin
                    // ---------------- HIT ----------------
                    if (
                        mesi_state[saved_index] != MESI_I &&
                        tags[saved_index] == saved_tag
                    ) begin
                        hit <= 1'b1;

                        if (!saved_write_en) begin
                            read_data <= data[{saved_index, saved_word}];
                            debug_mesi_state <= mesi_state[saved_index];
                            state <= COMPLETE;
                        end
                        else begin
                            data[{saved_index, saved_word}] <= saved_write_data;

                            if (mesi_state[saved_index] == MESI_S) begin
                                mesi_state[saved_index] <= MESI_M;
                                debug_mesi_state <= MESI_M;
                                state <= INVALIDATE;
                            end
                            else if (mesi_state[saved_index] == MESI_E) begin
                                mesi_state[saved_index] <= MESI_M;
                                debug_mesi_state <= MESI_M;
                                state <= COMPLETE;
                            end
                            else begin
                                // M -> M
                                debug_mesi_state <= MESI_M;
                                state <= COMPLETE;
                            end
                        end
                    end

                    // ---------------- MISS ----------------
                    else begin
                        hit <= 1'b0;

                        // If the indexed victim is Modified, it is the
                        // only up-to-date copy. Write the complete old
                        // line to L2 before replacing it.
                        if (mesi_state[saved_index] == MESI_M) begin
                            eviction_index <= saved_index;
                            eviction_word <= 2'd0;

                            // Old line address =
                            // old tag + same index + line offset 0000.
                            eviction_base_addr <= {
                                tags[saved_index],
                                saved_index,
                                4'b0000
                            };

                            state <= EVICTION_WRITE_REQUEST;
                        end
                        else begin
                            state <= COHERENCE_START;
                        end
                    end
                end

                // =================================================
                // DIRTY EVICTION
                // =================================================

                EVICTION_WRITE_REQUEST: begin
                    l2_req <= 1'b1;
                    l2_write_en <= 1'b1;

                    l2_addr <= {
                        eviction_base_addr[15:4],
                        eviction_word,
                        2'b00
                    };

                    l2_write_data <= data[{eviction_index, eviction_word}];

                    state <= EVICTION_WRITE_WAIT;
                end

                EVICTION_WRITE_WAIT: begin
                    if (l2_ready) begin
                        if (eviction_word == 2'd3) begin
                            // The old M line is now safely in L2.
                            // It will be replaced by the incoming line.
                            mesi_state[eviction_index] <= MESI_I;
                            eviction_word <= 2'd0;
                            state <= COHERENCE_START;
                        end
                        else begin
                            eviction_word <= eviction_word + 1'b1;
                            state <= EVICTION_WRITE_REQUEST;
                        end
                    end
                end

                // Start the normal miss/coherence sequence only AFTER
                // any dirty victim has been safely written back.
                COHERENCE_START: begin
                    coherence_addr <= saved_addr;
                    coherence_read <= 1'b1;
                    state <= COHERENCE_CHECK;
                end

                // The other L1 sees coherence_read on this clock edge.
                // Always wait at least one extra cycle so a Modified
                // owner has time to raise intervention_busy.
                COHERENCE_CHECK: begin
                    saved_shared <= coherence_shared;
                    refill_word <= 2'd0;
                    state <= WAIT_INTERVENTION;
                end

                WAIT_INTERVENTION: begin
                    if (!coherence_intervention_busy) begin
                        refill_word <= 2'd0;
                        state <= L2_READ_REQUEST;
                    end
                end

                L2_READ_REQUEST: begin
                    l2_req <= 1'b1;
                    l2_write_en <= 1'b0;

                    l2_addr <= {
                        saved_addr[15:4],
                        refill_word,
                        2'b00
                    };

                    state <= L2_READ_WAIT;
                end

                L2_READ_WAIT: begin
                    if (l2_ready) begin
                        data[{saved_index, refill_word}] <= l2_read_data;

                        if (refill_word == 2'd3) begin
                            tags[saved_index] <= saved_tag;

                            if (!saved_write_en) begin
                                if (saved_shared) begin
                                    mesi_state[saved_index] <= MESI_S;
                                    debug_mesi_state <= MESI_S;
                                end
                                else begin
                                    mesi_state[saved_index] <= MESI_E;
                                    debug_mesi_state <= MESI_E;
                                end

                                if (saved_word == refill_word)
                                    read_data <= l2_read_data;
                                else
                                    read_data <= data[{saved_index, saved_word}];

                                state <= COMPLETE;
                            end
                            else begin
                                // Write-allocate: refill the line first,
                                // then modify the requested word locally.
                                data[{saved_index, saved_word}] <= saved_write_data;
                                mesi_state[saved_index] <= MESI_M;
                                debug_mesi_state <= MESI_M;
                                state <= INVALIDATE;
                            end
                        end
                        else begin
                            refill_word <= refill_word + 1'b1;
                            state <= L2_READ_REQUEST;
                        end
                    end
                end

                INVALIDATE: begin
                    coherence_invalidate <= 1'b1;
                    coherence_invalidate_addr <= saved_addr;
                    state <= COMPLETE;
                end

                // =================================================
                // MODIFIED-OWNER INTERVENTION
                // =================================================

                INTERVENTION_WRITE_REQUEST: begin
                    snoop_intervention_busy <= 1'b1;

                    l2_req <= 1'b1;
                    l2_write_en <= 1'b1;

                    l2_addr <= {
                        intervention_addr[15:4],
                        intervention_word,
                        2'b00
                    };

                    l2_write_data <=
                        data[{intervention_addr[7:4], intervention_word}];

                    state <= INTERVENTION_WRITE_WAIT;
                end

                INTERVENTION_WRITE_WAIT: begin
                    snoop_intervention_busy <= 1'b1;

                    if (l2_ready) begin
                        if (intervention_word == 2'd3) begin
                            mesi_state[intervention_addr[7:4]] <= MESI_S;
                            debug_mesi_state <= MESI_S;

                            intervention_pending <= 1'b0;
                            snoop_intervention_busy <= 1'b0;
                            state <= IDLE;
                        end
                        else begin
                            intervention_word <= intervention_word + 1'b1;
                            state <= INTERVENTION_WRITE_REQUEST;
                        end
                    end
                end

                COMPLETE: begin
                    ready <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
