`include "cache_defs.vh"

module shared_bus (

    input clk,
    input reset,


    // =====================================================
    // L1-0 DATA REQUEST
    // =====================================================

    input l1_0_req,

    input l1_0_write_en,

    input [`ADDR_WIDTH-1:0] l1_0_addr,

    input [`DATA_WIDTH-1:0] l1_0_write_data,

    output reg [`DATA_WIDTH-1:0] l1_0_read_data,

    output reg l1_0_ready,


    // =====================================================
    // L1-1 DATA REQUEST
    // =====================================================

    input l1_1_req,

    input l1_1_write_en,

    input [`ADDR_WIDTH-1:0] l1_1_addr,

    input [`DATA_WIDTH-1:0] l1_1_write_data,

    output reg [`DATA_WIDTH-1:0] l1_1_read_data,

    output reg l1_1_ready,


    // =====================================================
    // L2
    // =====================================================

    output reg l2_req,

    output reg l2_write_en,

    output reg [`ADDR_WIDTH-1:0] l2_addr,

    output reg [`DATA_WIDTH-1:0] l2_write_data,

    input [`DATA_WIDTH-1:0] l2_read_data,

    input l2_ready

);


    // =====================================================
    // PENDING REQUEST FROM L1-0
    // =====================================================

    reg pending_0;

    reg pending_0_write_en;

    reg [`ADDR_WIDTH-1:0] pending_0_addr;

    reg [`DATA_WIDTH-1:0] pending_0_write_data;


    // =====================================================
    // PENDING REQUEST FROM L1-1
    // =====================================================

    reg pending_1;

    reg pending_1_write_en;

    reg [`ADDR_WIDTH-1:0] pending_1_addr;

    reg [`DATA_WIDTH-1:0] pending_1_write_data;


    // =====================================================
    // CURRENT OWNER
    //
    // 0 = L1-0
    // 1 = L1-1
    // =====================================================

    reg owner;


    // Used for round-robin selection

    reg last_owner;


    localparam BUS_IDLE = 2'd0;
    localparam BUS_SEND = 2'd1;
    localparam BUS_WAIT = 2'd2;
    reg [1:0] state;


    // =====================================================
    // MAIN BUS LOGIC
    // =====================================================

    always @(posedge clk) begin


        if (reset) begin

            pending_0 <= 0;
            pending_1 <= 0;


            pending_0_write_en <= 0;
            pending_1_write_en <= 0;


            pending_0_addr <= 0;
            pending_1_addr <= 0;


            pending_0_write_data <= 0;
            pending_1_write_data <= 0;


            owner <= 0;

            last_owner <= 1;


            l2_req <= 0;

            l2_write_en <= 0;

            l2_addr <= 0;

            l2_write_data <= 0;


            l1_0_read_data <= 0;

            l1_1_read_data <= 0;


            l1_0_ready <= 0;

            l1_1_ready <= 0;


            state <= BUS_IDLE;

        end


        else begin


            // =================================================
            // DEFAULT ONE-CYCLE SIGNALS
            // =================================================

            l2_req <= 0;

            l1_0_ready <= 0;

            l1_1_ready <= 0;


            // =================================================
            // CAPTURE L1-0 REQUEST
            // =================================================

            if (l1_0_req && !pending_0) begin

                pending_0 <= 1;

                pending_0_write_en
                    <= l1_0_write_en;

                pending_0_addr
                    <= l1_0_addr;

                pending_0_write_data
                    <= l1_0_write_data;

            end


            // =================================================
            // CAPTURE L1-1 REQUEST
            // =================================================

            if (l1_1_req && !pending_1) begin

                pending_1 <= 1;

                pending_1_write_en
                    <= l1_1_write_en;

                pending_1_addr
                    <= l1_1_addr;

                pending_1_write_data
                    <= l1_1_write_data;

            end


            case (state)


                // =============================================
                // CHOOSE NEXT REQUEST
                // =============================================

                BUS_IDLE: begin


                    // Both waiting

                    if (pending_0 && pending_1) begin


                        // Last was Core 1,
                        // so Core 0 gets this turn.

                        if (last_owner == 1) begin

                            owner <= 0;

                            last_owner <= 0;

                        end


                        else begin

                            owner <= 1;

                            last_owner <= 1;

                        end


                        state <= BUS_SEND;

                    end


                    // Only Core 0 waiting

                    else if (pending_0) begin

                        owner <= 0;

                        last_owner <= 0;

                        state <= BUS_SEND;

                    end


                    // Only Core 1 waiting

                    else if (pending_1) begin

                        owner <= 1;

                        last_owner <= 1;

                        state <= BUS_SEND;

                    end

                end


                // =============================================
                // SEND REQUEST TO L2
                // =============================================

                BUS_SEND: begin


                    l2_req <= 1;


                    if (owner == 0) begin

                        l2_write_en
                            <= pending_0_write_en;

                        l2_addr
                            <= pending_0_addr;

                        l2_write_data
                            <= pending_0_write_data;


                        // Request has now been consumed.

                        pending_0 <= 0;

                    end


                    else begin

                        l2_write_en
                            <= pending_1_write_en;

                        l2_addr
                            <= pending_1_addr;

                        l2_write_data
                            <= pending_1_write_data;


                        pending_1 <= 0;

                    end


                    state <= BUS_WAIT;

                end


                // =============================================
                // WAIT FOR L2
                // =============================================

                BUS_WAIT: begin


                    if (l2_ready) begin


                        if (owner == 0) begin

                            l1_0_read_data
                                <= l2_read_data;

                            l1_0_ready <= 1;

                        end


                        else begin

                            l1_1_read_data
                                <= l2_read_data;

                            l1_1_ready <= 1;

                        end


                        state <= BUS_IDLE;

                    end

                end


                default: begin

                    state <= BUS_IDLE;

                end


            endcase

        end

    end


endmodule