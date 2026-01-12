module udp_filter #(
    parameter TARGET_PORT = 16'h04D2 // 1234
)(
    input  wire        clk,
    input  wire        rst_n,

    // 32-BIT INPUT (Native Ethernet Width)
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tlast,
    output wire        s_axis_tready,

    // 32-BIT OUTPUT
    output reg  [31:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    output reg         m_axis_tlast,
    input  wire        m_axis_tready
);

    // =========================================================================
    // Word Offsets (Byte Offset / 4)
    // =========================================================================
    // EthType (12) is in Word 3 (Bytes 12,13,14,15)
    localparam WRD_ETH_TYPE = 3; 
    // Protocol (23) is in Word 5 (Bytes 20,21,22,23)
    localparam WRD_IP_PROTO = 5; 
    // Dest Port (36) is in Word 9 (Bytes 36,37,38,39)
    localparam WRD_UDP_DEST = 9; 
    
    // Payload starts after UDP Header (42 bytes). 
    // We pass data starting from Word 10 (Bytes 40-43) to capture it all.
    localparam WRD_PAYLOAD  = 10; 

    // =========================================================================
    // Internal State
    // =========================================================================
    reg [15:0] word_cnt; // Counts 32-bit words (0, 1, 2...)
    reg        packet_drop;

    // Always ready unless downstream is stuck (and we are passing payload)
    assign s_axis_tready = (word_cnt < WRD_PAYLOAD) || packet_drop ? 1'b1 : m_axis_tready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            word_cnt      <= 0;
            packet_drop   <= 0;
            m_axis_tvalid <= 0;
            m_axis_tdata  <= 0;
            m_axis_tlast  <= 0;
        end else begin
            
            // Defaults
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;

            if (s_axis_tvalid && s_axis_tready) begin
                
                // 1. Word Counting
                if (s_axis_tlast) begin
                    word_cnt    <= 0;
                    packet_drop <= 0;
                end else begin
                    word_cnt    <= word_cnt + 1;
                end

                // 2. Parallel Filtering (Check 4 bytes at once)
                if (!packet_drop && word_cnt < WRD_PAYLOAD) begin
                    case (word_cnt)
                        WRD_ETH_TYPE: begin
                            // EthType is at [7:0] and [15:8] of Word 3
                            if (s_axis_tdata[7:0]  != 8'h08) packet_drop <= 1;
                            if (s_axis_tdata[15:8] != 8'h00) packet_drop <= 1;
                        end
                        WRD_IP_PROTO: begin
                            // Protocol is at [31:24] of Word 5
                            if (s_axis_tdata[31:24] != 8'h11) packet_drop <= 1;
                        end
                        WRD_UDP_DEST: begin
                            // Port is at [7:0] and [15:8] of Word 9
                            if (s_axis_tdata[7:0]  != TARGET_PORT[15:8]) packet_drop <= 1;
                            if (s_axis_tdata[15:8] != TARGET_PORT[7:0])  packet_drop <= 1;
                        end
                    endcase
                end

                // 3. Passthrough (32-bit)
                // Note: This starts passing at Word 10 (Byte 40). 
                // This includes the last 2 bytes of UDP Checksum, which is fine.
                if (word_cnt >= WRD_PAYLOAD && !packet_drop) begin
                    m_axis_tdata  <= s_axis_tdata;
                    m_axis_tvalid <= 1;
                    m_axis_tlast  <= s_axis_tlast;
                end
            end
        end
    end

endmodule