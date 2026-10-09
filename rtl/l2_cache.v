`include "cache_defs.vh"

module l2_cache (

    input clk,
    input reset,

    // Request coming into L2
    input req,
    input write_en,

    input [`ADDR_WIDTH-1:0] addr,
    input [`DATA_WIDTH-1:0] write_data,

    // Response from L2
    output reg [`DATA_WIDTH-1:0] read_data,
    output reg ready,
    output reg hit,

    // Connection to main memory
    output reg mem_req,
    output reg mem_write_en,

    output reg [`ADDR_WIDTH-1:0] mem_addr,
    output reg [`DATA_WIDTH-1:0] mem_write_data,

    input [`DATA_WIDTH-1:0] mem_read_data,
    input mem_ready
);


    // =====================================================
    // L2 CACHE STORAGE
    //
    // L2 size = 1024 bytes
    // Cache line = 16 bytes
    //
    // Number of lines = 1024 / 16 = 64
    // =====================================================

    localparam NUM_LINES = 64;


    // Each line stores a tag.
    reg [5:0] tags [0:63];

    // Is this cache line actually holding useful data?
    reg valid [0:63];

    // Has this cache line been changed by a write?
    reg dirty [0:63];


    // Each cache line contains 4 words.
    reg [`DATA_WIDTH-1:0] data [0:255];


    // =====================================================
    // SAVED REQUEST
    //
    // We save the request because processing takes
    // multiple clock cycles.
    // =====================================================

    reg [`ADDR_WIDTH-1:0] saved_addr;
    reg saved_write_en;

    reg [`DATA_WIDTH-1:0] saved_write_data;

    reg [5:0] saved_tag;
    reg [5:0] saved_index;
    reg [1:0] saved_word;


    // Which word are we currently fetching from RAM?
    reg [1:0] refill_word;

    // Which word are we currently writing back to RAM?
    reg [1:0] writeback_word;


    integer latency_counter;

    integer i;
    integer j;


    // =====================================================
    // L2 CONTROL STATES
    // =====================================================

    localparam IDLE              = 4'd0;
    localparam L2_DELAY          = 4'd1;
    localparam LOOKUP            = 4'd2;
    localparam WRITEBACK_REQUEST = 4'd3;
    localparam WRITEBACK_WAIT    = 4'd4;
    localparam MEMORY_REQUEST    = 4'd5;
    localparam MEMORY_WAIT       = 4'd6;
    localparam COMPLETE          = 4'd7;
    reg [3:0] state;


    // =====================================================
    // MAIN CACHE LOGIC
    // =====================================================

    always @(posedge clk) begin


        // =================================================
        // RESET
        // =================================================

        if (reset) begin

            state <= IDLE;

            ready <= 0;
            hit   <= 0;

            read_data <= 0;

            mem_req        <= 0;
            mem_write_en   <= 0;
            mem_addr       <= 0;
            mem_write_data <= 0;

            latency_counter <= 0;

            refill_word    <= 0;
            writeback_word <= 0;


            // Start with an empty cache.

            for (i = 0; i < NUM_LINES; i = i + 1) begin

                valid[i] <= 0;
                dirty[i] <= 0;
                tags[i]  <= 0;

                for (j = 0; j < 4; j = j + 1) begin

                    data[(i * 4) + j] <= 0;

                end

            end

        end


        // =================================================
        // NORMAL OPERATION
        // =================================================

        else begin

            // These signals normally stay low.
            ready   <= 0;
            mem_req <= 0;


            case (state)


                // =========================================
                // WAIT FOR A REQUEST
                // =========================================

                IDLE: begin

                    hit <= 0;

                    if (req) begin

                        // Save the request.

                        saved_addr       <= addr;
                        saved_write_en   <= write_en;
                        saved_write_data <= write_data;


                        /*
                         * Address:
                         *
                         * 15       10 9        4 3  2 1  0
                         * +----------+----------+----+----+
                         * |   TAG    |  INDEX   |WORD|BYTE|
                         * +----------+----------+----+----+
                         */

                        saved_tag   <= addr[15:10];
                        saved_index <= addr[9:4];
                        saved_word  <= addr[3:2];


                        // L2 takes 5 cycles.

                        latency_counter <= `L2_LATENCY;

                        state <= L2_DELAY;

                    end

                end


                // =========================================
                // WAIT FOR L2 LATENCY
                // =========================================

                L2_DELAY: begin

                    if (latency_counter > 1) begin

                        latency_counter <= latency_counter - 1;

                    end

                    else begin

                        state <= LOOKUP;

                    end

                end


                // =========================================
                // CHECK WHETHER DATA EXISTS IN L2
                // =========================================

                LOOKUP: begin


                    // -------------------------------------
                    // CACHE HIT
                    // -------------------------------------

                    if (
                        valid[saved_index] &&
                        tags[saved_index] == saved_tag
                    ) begin

                        hit <= 1;


                        // WRITE

                        if (saved_write_en) begin

                            data[{saved_index, saved_word}]
                                <= saved_write_data;

                            // We changed the cached copy.
                            dirty[saved_index] <= 1;

                        end


                        // READ

                        else begin

                            read_data
                                <= data[{saved_index, saved_word}];

                        end


                        state <= COMPLETE;

                    end


                    // -------------------------------------
                    // CACHE MISS
                    // -------------------------------------

                    else begin

                        hit <= 0;

                        refill_word <= 0;


                        /*
                         * If we're throwing away a cache
                         * line that was modified, save it
                         * back to RAM first.
                         */

                        if (
                            valid[saved_index] &&
                            dirty[saved_index]
                        ) begin

                            writeback_word <= 0;

                            state <= WRITEBACK_REQUEST;

                        end


                        // Otherwise simply fetch new data.

                        else begin

                            state <= MEMORY_REQUEST;

                        end

                    end

                end


                // =========================================
                // WRITE OLD DATA BACK TO MEMORY
                // =========================================

                WRITEBACK_REQUEST: begin

                    mem_req      <= 1;
                    mem_write_en <= 1;


                    mem_addr <= {

                        tags[saved_index],

                        saved_index,

                        writeback_word,

                        2'b00

                    };


                    mem_write_data
                        <= data[{saved_index, writeback_word}];


                    state <= WRITEBACK_WAIT;

                end


                // =========================================

                WRITEBACK_WAIT: begin

                    if (mem_ready) begin


                        // Last word written back?

                        if (writeback_word == 2'd3) begin

                            dirty[saved_index] <= 0;

                            refill_word <= 0;

                            state <= MEMORY_REQUEST;

                        end


                        else begin

                            writeback_word
                                <= writeback_word + 1;

                            state <= WRITEBACK_REQUEST;

                        end

                    end

                end


                // =========================================
                // ASK MAIN MEMORY FOR DATA
                // =========================================

                MEMORY_REQUEST: begin

                    mem_req      <= 1;
                    mem_write_en <= 0;


                    /*
                     * Fetch one word from the required
                     * cache line.
                     */

                    mem_addr <= {

                        saved_addr[15:4],

                        refill_word,

                        2'b00

                    };


                    state <= MEMORY_WAIT;

                end


                // =========================================
                // WAIT FOR MAIN MEMORY
                // =========================================

                MEMORY_WAIT: begin

                    if (mem_ready) begin


                        // Store returned word in L2.

                        data[{saved_index, refill_word}]
                            <= mem_read_data;


                        // Have all four words arrived?

                        if (refill_word == 2'd3) begin


                            // Cache line is now valid.

                            valid[saved_index] <= 1;

                            tags[saved_index]
                                <= saved_tag;

                            dirty[saved_index]
                                <= 0;


                            // -----------------------------
                            // Original request was WRITE
                            // -----------------------------

                            if (saved_write_en) begin

                                data[{saved_index, saved_word}]
                                    <= saved_write_data;

                                dirty[saved_index]
                                    <= 1;

                            end


                            // -----------------------------
                            // Original request was READ
                            // -----------------------------

                            else begin

                                /*
                                 * If the requested word is
                                 * the final word arriving,
                                 * directly use memory output.
                                 */

                                if (saved_word == refill_word)

                                    read_data
                                        <= mem_read_data;

                                else

                                    read_data
                                        <= data[{saved_index, saved_word}];

                            end


                            state <= COMPLETE;

                        end


                        else begin

                            refill_word
                                <= refill_word + 1;

                            state <= MEMORY_REQUEST;

                        end

                    end

                end


                // =========================================
                // TELL REQUESTER WE ARE FINISHED
                // =========================================

                COMPLETE: begin

                    ready <= 1;

                    state <= IDLE;

                end


                default: begin

                    state <= IDLE;

                end


            endcase

        end

    end

endmodule