module gray2bin 
#(
    parameter ADDRSIZE = 4
)

(
    input [ADDRSIZE:0] grayin,
    output [ADDRSIZE:0] bout    
);

reg [ADDRSIZE:0] bout_temp;
assign bout = bout_temp;
integer i;

always @(*) begin
    bout_temp[ADDRSIZE] = grayin[ADDRSIZE];
    for (i = ADDRSIZE-1; i >= 0; i = i -1) begin
        bout_temp [i] = bout_temp[i+1] ^ grayin[i];
    end    
end

endmodule
