module wptr_full 
#(
parameter ADDRSIZE = 4
)
(
    input wincr,
    input [ADDRSIZE:0] wrptr,  //this is the read pointer
    input wclk,
    input wrst,
    output [ADDRSIZE-1:0] waddr,
    output reg [ADDRSIZE:0] wptr,  //this is the write pointer    
    output reg wfull
);

reg [ADDRSIZE:0] wbin;
wire [ADDRSIZE:0] wgraynext, wbinnext;

assign wbinnext = wbin + (wincr & ~wfull);
assign wgraynext = (wbinnext >> 1) ^ wbinnext;

always @(posedge wclk or negedge wrst) begin
    if (!wrst) begin
        wptr <= 0;
        wbin <= 0;
    end else begin
        wbin <= wbinnext;      
        wptr <= wgraynext;    
    end
end

assign waddr = wbin[ADDRSIZE-1:0];

wire wfull_val;
assign wfull_val = (wgraynext == {~wrptr[ADDRSIZE:ADDRSIZE-1], wrptr[ADDRSIZE-2:0]});

always @(posedge wclk or negedge wrst) begin
    if (!wrst) begin
        wfull <= 0;
    end
    else
        wfull <= wfull_val;
end

endmodule