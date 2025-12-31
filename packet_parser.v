module packet_parser (
    input             clk,
    input             rst_n,

    // Input Stream
    input      [7:0]  s_axis_tdata,
    input             s_axis_tvalid,
    output            s_axis_tready, 

    // Output Stream
    output reg [7:0]  m_axis_tdata,
    output reg        m_axis_tvalid,
    output reg        m_axis_tlast,
    output reg        m_axis_tuser, 
    input             m_axis_tready
);

    localparam STATE_IDLE      = 3'd0;
    localparam STATE_HEADER_2  = 3'd1;
    localparam STATE_LENGTH    = 3'd2;
    localparam STATE_PAYLOAD   = 3'd3;

    reg [2:0] state;
    reg [7:0] len_cntr;
    reg [7:0] target_len;
    reg [7:0] calc_cs;
    reg [7:0] s_axis_tdata_prev;

    assign s_axis_tready = m_axis_tready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= STATE_IDLE;
            m_axis_tvalid     <= 0;
            m_axis_tlast      <= 0;
            m_axis_tuser      <= 0;
            m_axis_tdata      <= 0;
            s_axis_tdata_prev <= 0;
            calc_cs           <= 0;
            len_cntr          <= 0;
        end 
        else if (m_axis_tready) begin
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            m_axis_tuser  <= 0;

            if (s_axis_tvalid) begin
                case (state)
                    STATE_IDLE: begin
                        if (s_axis_tdata == 8'hAA)
                            state <= STATE_HEADER_2;
                    end

                    STATE_HEADER_2: begin
                        if (s_axis_tdata == 8'h55) state <= STATE_LENGTH;
                        else if (s_axis_tdata == 8'hAA) state <= STATE_HEADER_2; 
                        else state <= STATE_IDLE;
                    end

                    STATE_LENGTH: begin
                        target_len <= s_axis_tdata;
                        len_cntr   <= 0;
                        calc_cs    <= 0;
                        state      <= STATE_PAYLOAD;
                    end

                    STATE_PAYLOAD: begin
                        s_axis_tdata_prev <= s_axis_tdata;

                        // LAST BYTE LOGIC
                        if (len_cntr == target_len) begin
                            m_axis_tdata  <= s_axis_tdata_prev;
                            m_axis_tlast  <= 1;
                            m_axis_tvalid <= 1; // Correctly set to 1

                            // Compare Input (Checksum) vs Calculated
                            if (s_axis_tdata != calc_cs) 
                                m_axis_tuser <= 1; // Error
                            else 
                                m_axis_tuser <= 0; // Good
                            
                            state <= STATE_IDLE;
 
                        end 
                        // NORMAL PAYLOAD LOGIC
                        else begin
                            calc_cs <= calc_cs ^ s_axis_tdata;
                            len_cntr <= len_cntr + 1;

                            if (len_cntr > 0) begin
                                m_axis_tdata  <= s_axis_tdata_prev;
                                m_axis_tvalid <= 1;
                            end
                        end
                    end
                endcase
            end
        end
    end

endmodule