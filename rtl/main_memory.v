`include "cache_defs.vh"

module main_memory (
    input                    clk,
    input                    reset,

    // Request interface
    input                    req,
    input                    write_en,
    input [`ADDR_WIDTH-1:0]  addr,
    input [`DATA_WIDTH-1:0]  write_data,

    // Response interface
    output reg [`DATA_WIDTH-1:0]  read_data,
    output reg                    ready
);

    // ---------------------------------------------------------
    // Main memory
    //
    // 64 KB memory
    // Each entry = 32-bit word = 4 bytes
    //
    // 65536 / 4 = 16384 words
    // ---------------------------------------------------------

    localparam NUM_WORDS =
        `MEMORY_SIZE_BYTES / (`DATA_WIDTH / 8);

    reg [`DATA_WIDTH-1:0] memory [0:NUM_WORDS-1];

    // Latched request
    reg [`ADDR_WIDTH-1:0] addr_reg;
    reg [`DATA_WIDTH-1:0] write_data_reg;
    reg                   write_en_reg;

    integer latency_counter;
    integer i;

    localparam IDLE    = 1'b0;
    localparam WAITING = 1'b1;
    reg state;

    // Convert byte address into word address.
    wire [`ADDR_WIDTH-3:0] word_addr;
    assign word_addr = addr_reg[`ADDR_WIDTH-1:2];

    // ---------------------------------------------------------
    // Memory behaviour
    // ---------------------------------------------------------

    always @(posedge clk) begin

        if (reset) begin

            state           <= IDLE;
            ready           <= 1'b0;
            read_data       <= 0;
            latency_counter <= 0;

            // Initialise memory for simulation.
            for (i = 0; i < NUM_WORDS; i = i + 1) begin
                memory[i] <= 32'h0;
            end

        end else begin

            // ready is asserted for only one clock cycle
            ready <= 1'b0;

            case (state)

                // -------------------------------------------------
                // Wait for a memory request
                // -------------------------------------------------

                IDLE: begin

                    if (req) begin

                        addr_reg       <= addr;
                        write_data_reg <= write_data;
                        write_en_reg   <= write_en;

                        latency_counter <= `MEMORY_LATENCY;

                        state <= WAITING;

                    end

                end

                // -------------------------------------------------
                // Model main-memory latency
                // -------------------------------------------------

                WAITING: begin

                    if (latency_counter > 1) begin

                        latency_counter <= latency_counter - 1;

                    end else begin

                        if (write_en_reg) begin

                            memory[word_addr] <= write_data_reg;

                        end else begin

                            read_data <= memory[word_addr];

                        end

                        ready <= 1'b1;
                        state <= IDLE;

                    end

                end

            endcase

        end

    end

endmodule