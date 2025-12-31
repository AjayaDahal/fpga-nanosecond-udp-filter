module udp_filter #(
    parameter TARGET_PORT = 16'h04D2 // Default: Port 1234
)(
    input  wire       clk,
    input  wire       rst_n,

    // Input Stream (From AXI Ethernet MAC)
    input  wire [31:0] s_axis_tdata,
    input  wire       s_axis_tvalid,
    input  wire       s_axis_tlast,
    output wire       s_axis_tready,

    // Output Stream (To FIFO -> Parser)
    output reg  [31:0] m_axis_tdata,
    output reg        m_axis_tvalid,
    output reg        m_axis_tlast,
    input  wire       m_axis_tready
);

    // =========================================================================
    // Constants (Ethernet Frame Offsets)
    // =========================================================================
    localparam CNT_ETH_TYPE_H = 12; // 0x08 (IPv4)
    localparam CNT_ETH_TYPE_L = 13; // 0x00
    localparam CNT_IP_PROTO   = 23; // 0x11 (UDP)
    localparam CNT_UDP_DEST_H = 36; // Target Port High Byte
    localparam CNT_UDP_DEST_L = 37; // Target Port Low Byte
    localparam HEADER_SIZE    = 42; // Total bytes to strip

    // =========================================================================
    // Internal State
    // =========================================================================
    reg [15:0] byte_cnt;
    reg        packet_drop; // High if we detect a mismatch
    
    // =========================================================================
    // Ready Logic (Upstream Backpressure)
    // =========================================================================
    // We are ready to accept data if:
    // 1. We are processing headers (we swallow these, so we are always ready)
    // 2. We decided to DROP the packet (we swallow the rest, so always ready)
    // 3. We are passing payload (we reflect the downstream ready signal)
    assign s_axis_tready = (byte_cnt < HEADER_SIZE) || packet_drop ? 1'b1 : m_axis_tready;

    // =========================================================================
    // Main Filtering Logic
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_cnt      <= 0;
            packet_drop   <= 0;
            m_axis_tvalid <= 0;
            m_axis_tdata  <= 0;
            m_axis_tlast  <= 0;
        end else begin
            
            // Default output states
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;

            if (s_axis_tvalid && s_axis_tready) begin
                // 1. Byte Counting
                if (s_axis_tlast) begin
                    byte_cnt    <= 0;      // Reset for next packet
                    packet_drop <= 0;      // Reset drop flag
                end else begin
                    byte_cnt    <= byte_cnt + 1;
                end

                // 2. Filtering Checks (Only during Header phase)
                if (!packet_drop && byte_cnt < HEADER_SIZE) begin
                    case (byte_cnt)
                        CNT_ETH_TYPE_H: if (s_axis_tdata != 8'h08) packet_drop <= 1; // Not IP
                        CNT_ETH_TYPE_L: if (s_axis_tdata != 8'h00) packet_drop <= 1;
                        CNT_IP_PROTO:   if (s_axis_tdata != 8'h11) packet_drop <= 1; // Not UDP
                        CNT_UDP_DEST_H: if (s_axis_tdata != TARGET_PORT[15:8]) packet_drop <= 1; // Wrong Port
                        CNT_UDP_DEST_L: if (s_axis_tdata != TARGET_PORT[7:0])  packet_drop <= 1;
                    endcase
                end

                // 3. Payload Passing
                // If we are past the header AND not dropping, stream to output
                if (byte_cnt >= HEADER_SIZE && !packet_drop) begin
                    m_axis_tdata  <= s_axis_tdata;
                    m_axis_tvalid <= 1; 
                    m_axis_tlast  <= s_axis_tlast;
                end
            end
        end
    end

endmodule