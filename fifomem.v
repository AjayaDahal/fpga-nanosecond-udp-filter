module fifomem #(
    parameter ADDRSIZE = 4,
    parameter DATASIZE = 8
)
(
    input [DATASIZE-1:0] wdata,
    input [ADDRSIZE-1:0] waddr,
    input clk,
    input wen, 
    input [ADDRSIZE-1:0] raddr,
    output reg [DATASIZE-1:0] rdata
);

localparam DEPTH = 1 << ADDRSIZE;  //4 bits will give depth of 16

reg [DATASIZE-1:0] ram [0:DEPTH-1];

always @(posedge clk) begin
    if (wen) begin
        ram[waddr] <= wdata;
    end
end

always @(posedge clk) begin
        rdata <= ram[raddr];
end

endmodule