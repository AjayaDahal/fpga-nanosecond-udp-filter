module bin2gray
#(
    parameter ADDRSIZE = 4
)
(
    input [ADDRSIZE:0] bin,
    output [ADDRSIZE:0] grayout
);

assign grayout = bin ^(bin >> 1);

endmodule
