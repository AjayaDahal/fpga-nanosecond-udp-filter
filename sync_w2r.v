module sync_w2r (
    input[DEPTH:0] wptr,
    input rclk,
    input rwst,
    output[DEPTH:0] rwptr
);

parameter DEPTH = 4;

reg [DEPTH:0] rwptr_reg, temp_reg;
assign rwptr = rwptr_reg;
always @(posedge rclk or negedge rwst) begin
    if(!rwst) 
        {rwptr_reg, temp_reg}  <= 0;
    else
       {rwptr_reg, temp_reg} <= {temp_reg, wptr}; 
end

endmodule