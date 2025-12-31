module rptr_empty #(parameter ADDRSIZE = 4) (
    input rincr,
    input [ADDRSIZE:0] rwptr,
    input rclk,
    input rrst,
    output [ADDRSIZE-1:0] raddr,
    output reg [ADDRSIZE:0] rptr,
    output reg rempty
);

    reg [ADDRSIZE:0] rbin;
    // FIX: Remove underscore to match usage
    wire [ADDRSIZE:0] rgraynext, rbinnext; 

    assign rbinnext = rbin + (rincr & ~rempty);
    assign rgraynext = (rbinnext >> 1) ^ rbinnext;

    always @(posedge rclk or negedge rrst) begin
        if (!rrst) begin
            rptr <= 0;
            rbin <= 0;
        end else begin
            rbin <= rbinnext;
            rptr <= rgraynext;
        end
    end

    assign raddr = rbin;

    always @(posedge rclk or negedge rrst) begin
        if (!rrst) rempty <= 1;
        else rempty <= (rgraynext == rwptr);
    end
endmodule