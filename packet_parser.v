`timescale 1ns / 1ps

module packet_parser (
    input  wire        clk,
    input  wire        rst_n,

    // 32-BIT AXI INPUT (From FIFO)
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output reg         s_axis_tready,

    // 32-BIT AXI OUTPUT (To Application)
    output reg  [31:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    output reg         m_axis_tlast,
    output reg         m_axis_tuser, // 1 = Checksum Error
    input  wire        m_axis_tready
);

    // =========================================================
    // STATES
    // =========================================================
    localparam S_SEARCH_AA55 = 0;
    localparam S_GET_LENGTH = 1;
    localparam S_STREAM_PAYLOAD = 2;

    reg [1:0]       state;
    reg [7:0]  calc_checksum; // The running XOR sum
    reg [31:0] prev_data;
    reg [7:0] bytes_left;
    reg [7:0] length;
    reg [0:0] middle_of_byte;
    
   always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_SEARCH_AA55;
            s_axis_tready <= 0;
            m_axis_tvalid <= 0;
            bytes_left [7:0] <= 8'b100;
            middle_of_byte <= 0;
            length <= 0;
            prev_data[31:0] <= 32'b0;
            m_axis_tdata[31:0] <= 32'b0;
            m_axis_tlast <= 0;
            
        end else begin
            // 1. Flow Control
            s_axis_tready <= m_axis_tready;

            if (s_axis_tvalid && s_axis_tready || length >= 0) begin
               
                
                    m_axis_tvalid <= 0;
                    case (state)
                    // STEP 1: Find Header (Look for AA)
                    S_SEARCH_AA55: begin
                        // Little Endian: [7:0]=AA, [15:8]=55, [23:16]=Len
                        if (s_axis_tdata[31:16] == 16'h55AA) begin
                            // Capture Length
                            m_axis_tvalid <= 0;
                            m_axis_tdata[31:0] <= 32'b0;
                            //s_axis_tready <= 0;
                            state <= S_GET_LENGTH;
                            
                        end
                    end
                                        
                    S_GET_LENGTH: begin
                        length[7:0] <= s_axis_tdata[7:0];
                        m_axis_tdata[31:0] <= {s_axis_tdata[31:8], 8'b0};
                        m_axis_tvalid <= 1;
                        state <= S_STREAM_PAYLOAD;
                    end

                    // STEP 3: Stream Body
                    S_STREAM_PAYLOAD: begin
                        m_axis_tvalid <= 1;                        
                        // Last Word Logic
                        if (length[7:0] <= 8'h5) begin
                            m_axis_tlast <= 1;
                            length[7:0] <= 8'b0;
                            state <= S_SEARCH_AA55;
                             m_axis_tdata[31:0]  <= {16'b0, s_axis_tdata[15:0]};
                        end else begin
                            m_axis_tlast <= 0;
                             m_axis_tdata[31:0]  <= s_axis_tdata[31:0];
                            length <= length - 8'h4;
                        end
                        
                    end
                endcase
            end
        end
    end
endmodule