`timescale 1ns / 1ps

module tb_udp_filter;

    // --------------------------------------------------------
    // 1. Signals
    // --------------------------------------------------------
    reg clk = 0;
    reg rst_n = 0;

    // Input (Simulating MAC RX)
    reg [7:0] s_axis_tdata;
    reg       s_axis_tvalid;
    reg       s_axis_tlast;
    wire      s_axis_tready;

    // Output (To FIFO/Parser)
    wire [7:0] m_axis_tdata;
    wire       m_axis_tvalid;
    wire       m_axis_tlast;
    reg        m_axis_tready = 1; // Always ready to sink data

    // --------------------------------------------------------
    // 2. Instantiate the DUT (Device Under Test)
    // --------------------------------------------------------
    udp_filter DUT (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tready(m_axis_tready)
    );

    // --------------------------------------------------------
    // 3. Clock Generation (125 MHz)
    // --------------------------------------------------------
    always #4 clk = ~clk; // 8ns period

    // --------------------------------------------------------
    // 4. Helper Task: Send Byte
    // --------------------------------------------------------
    task send_byte(input [7:0] data, input last);
        begin
            @(posedge clk);
            s_axis_tdata  <= data;
            s_axis_tvalid <= 1;
            s_axis_tlast  <= last;
            wait(s_axis_tready); // Wait if filter applies backpressure
        end
    endtask

    // --------------------------------------------------------
    // 5. Main Test Sequence
    // --------------------------------------------------------
    integer i;
    initial begin
        $dumpfile("udp_filter.vcd");
        $dumpvars(0, tb_udp_filter);

        // Init
        s_axis_tdata = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        
        // Reset
        rst_n = 0; #20; rst_n = 1; #20;

        $display("[TB] Sending UDP Packet (Port 1234)...");

        // ---------------------------------------------------------
        // A. ETHERNET HEADER (14 Bytes)
        // ---------------------------------------------------------
        // Dest MAC (6) + Src MAC (6)
        repeat(12) send_byte(8'h00, 0); 
        // EtherType (0x0800 = IPv4)
        send_byte(8'h08, 0); // Byte 12
        send_byte(8'h00, 0); // Byte 13

        // ---------------------------------------------------------
        // B. IP HEADER (20 Bytes)
        // ---------------------------------------------------------
        // Version/Len..
        repeat(9) send_byte(8'h00, 0); 
        // Protocol (Byte 23) -> 0x11 = UDP
        send_byte(8'h11, 0); 
        // Src/Dest IP...
        repeat(10) send_byte(8'h00, 0);

        // ---------------------------------------------------------
        // C. UDP HEADER (8 Bytes)
        // ---------------------------------------------------------
        // Src Port (2 bytes)
        send_byte(8'h00, 0); send_byte(8'h00, 0);
        // Dest Port (Bytes 36-37) -> 0x04D2 = 1234
        send_byte(8'h04, 0); // Byte 36
        send_byte(8'hD2, 0); // Byte 37
        // Length/Checksum (4 bytes)
        repeat(4) send_byte(8'h00, 0);

        // ---------------------------------------------------------
        // D. PAYLOAD (Your Parser Data) - Bytes 42+
        // ---------------------------------------------------------
        $display("[TB] Headers Done. Sending Payload...");
        send_byte(8'hAA, 0); // Should appear on Output!
        send_byte(8'h55, 0); // Should appear on Output!
        send_byte(8'hFF, 1); // Last Byte (TLAST)

        @(posedge clk);
        s_axis_tvalid <= 0;
        s_axis_tlast  <= 0;

        #100;
        $finish;
    end

endmodule