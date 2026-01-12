`timescale 1ns / 1ps

//
// Top-level wrapper for the complete trading pipeline
// Instantiates: udp_filter -> FIFO -> packet_parser -> parser_shim -> book_builder
//

module trading_pipeline_top (
    input wire          clk,
    input wire          rst_n,
    
    // Input: Ethernet AXI Stream (32-bit)
    input wire [31:0]   eth_axis_tdata,
    input wire          eth_axis_tvalid,
    input wire          eth_axis_tlast,
    output wire         eth_axis_tready,
    
    // Output: Book Builder Results
    output wire [31:0]  best_bid,
    output wire [31:0]  best_ask,
    output wire         bbo_updated,
    
    // Debug outputs (optional)
    output wire [31:0]  debug_tick_price,
    output wire [31:0]  debug_tick_qty,
    output wire         debug_tick_is_buy,
    output wire         debug_tick_valid
);

    // Interconnect signals
    wire [31:0] udp_to_parser_tdata;
    wire        udp_to_parser_tvalid;
    wire        udp_to_parser_tlast;
    wire        udp_to_parser_tready;
    
    wire [31:0] parser_to_shim_tdata;
    wire        parser_to_shim_tvalid;
    wire        parser_to_shim_tlast;
    wire        parser_to_shim_tready;
    wire        parser_to_shim_tuser;
    
    wire [31:0] shim_tick_price;
    wire [31:0] shim_tick_qty;
    wire        shim_tick_is_buy;
    wire        shim_tick_valid;
    
    // Assign debug outputs
    assign debug_tick_price = shim_tick_price;
    assign debug_tick_qty = shim_tick_qty;
    assign debug_tick_is_buy = shim_tick_is_buy;
    assign debug_tick_valid = shim_tick_valid;
    
    // =========================================================================
    // Stage 1: UDP Filter
    // =========================================================================
    udp_filter udp_filter_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(eth_axis_tdata),
        .s_axis_tvalid(eth_axis_tvalid),
        .s_axis_tlast(eth_axis_tlast),
        .s_axis_tready(eth_axis_tready),
        .m_axis_tdata(udp_to_parser_tdata),
        .m_axis_tvalid(udp_to_parser_tvalid),
        .m_axis_tlast(udp_to_parser_tlast),
        .m_axis_tready(udp_to_parser_tready)
    );
    
    // =========================================================================
    // Stage 2: Packet Parser (32-bit to 8-bit serializer with protocol parser)
    // Note: packet_parser does NOT have s_axis_tlast input - it was removed
    // =========================================================================
    packet_parser packet_parser_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(udp_to_parser_tdata),
        .s_axis_tvalid(udp_to_parser_tvalid),
        .s_axis_tready(udp_to_parser_tready),
        .m_axis_tdata(parser_to_shim_tdata),
        .m_axis_tvalid(parser_to_shim_tvalid),
        .m_axis_tlast(parser_to_shim_tlast),
        .m_axis_tready(parser_to_shim_tready),
        .m_axis_tuser(parser_to_shim_tuser)
    );
    
    // =========================================================================
    // Stage 3: Parser Shim (Byte stream to structured tick data)
    // =========================================================================
    parser_shim parser_shim_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(parser_to_shim_tdata),
        .s_axis_tvalid(parser_to_shim_tvalid),
        .s_axis_tlast(parser_to_shim_tlast),
        .s_axis_tready(parser_to_shim_tready),
        .m_tick_price(shim_tick_price),
        .m_tick_qty(shim_tick_qty),
        .m_tick_is_buy(shim_tick_is_buy),
        .m_tick_valid(shim_tick_valid)
    );
    
    // =========================================================================
    // Stage 4: Book Builder (Maintains Best Bid/Offer)
    // =========================================================================
    book_builder book_builder_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_tick_price(shim_tick_price),
        .s_tick_qty(shim_tick_qty),
        .s_tick_is_buy(shim_tick_is_buy),
        .s_tick_valid(shim_tick_valid),
        .best_bid(best_bid),
        .best_ask(best_ask),
        .bbo_updated(bbo_updated)
    );

endmodule
