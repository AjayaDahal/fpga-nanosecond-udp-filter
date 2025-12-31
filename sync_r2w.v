module sync_r2w (
    input[DEPTH:0] rptr,
    input wclk,
    input wrst,
    output[DEPTH:0] wrptr
);

parameter DEPTH = 4;

reg [DEPTH:0] wrptr_reg, temp_reg;
assign wrptr = wrptr_reg;
always @(posedge wclk or negedge wrst) begin
    if(!wrst) 
        {wrptr_reg, temp_reg}  <= 0;
    else
       {wrptr_reg, temp_reg} <= {temp_reg, rptr}; 
end

endmodule