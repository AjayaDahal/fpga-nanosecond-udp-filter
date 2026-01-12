module parser_shim (

    input wire          clk,
    input wire          rst_n,

    // --- Input from Packet Parser (byte stream) ---
    input wire [31:0]   s_axis_tdata,  // Only [7:0] used for byte data
    input wire          s_axis_tvalid,
    input wire          s_axis_tlast,
    output wire         s_axis_tready,

    // --- Output to Book Builder ---
    output reg [31:0]   m_tick_price,
    output reg [31:0]   m_tick_qty,
    output reg          m_tick_is_buy,
    output reg          m_tick_valid
);
    
    localparam[1:0] S_IDLE = 0;
    localparam[1:0] S_GET_PRICE = 1;
    localparam[1:0] S_GET_QTY = 2;
    
    
    reg [2:0] counter = 3'b0;
    reg [1:0] state = S_IDLE;
    //reg [31:0] prev_data;
    reg last_tlast;
    // We are always ready to accept data from the parser.
    assign s_axis_tready = 1'b1;

    //first let's just see what is coming in in the sim
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            counter[2:0] <= 3'h0;
            m_tick_price[31:0] <= 32'b0;
            m_tick_qty[31:0] <= 32'b0;
            state <= S_IDLE;
           // m_tick_is_buy <= 0;
                                
            //prev_data [31:0] <= 32'b0;
        end 
        else begin        
            if(s_axis_tvalid) begin
//                    prev_data [31:0] <= s_axis_tdata[31:0];
                    last_tlast <= s_axis_tlast;
                    case(state)
                        S_IDLE: begin
                                state <= S_GET_PRICE;
                                m_tick_valid <= 0;
                                //m_tick_is_buy <= 0;
                                
                        end                   
                        
                        S_GET_PRICE: begin
                            m_tick_price[31:0] <= s_axis_tdata[31:0];
                            
                            //m_tick_is_buy <= 0;
                                
                            state <= S_GET_QTY;
                        end
                        
                        S_GET_QTY: begin
                            if(s_axis_tdata[15:8] == 8'h42) begin
                                  m_tick_is_buy <= 1;
                                  m_tick_valid <= 1;
                                end
                             else begin
                                m_tick_is_buy <= 0;
                                m_tick_valid <= 1;
                            end                                
                            m_tick_qty[7:0] <= s_axis_tdata[7:0];
                            m_tick_valid <= 1;
                            
                            
                            state <= S_IDLE;
                        end
                                               
                    endcase
             end
        end
    end
endmodule