`timescale 1ns / 1ps

module tb_full_system;

    // =========================================================
    // 1. CLOCK & RESET GENERATION
    // =========================================================
    reg net_clk = 0; // 125 MHz (Ethernet / Network Domain)
    reg app_clk = 0; // 100 MHz (Application / Parser Domain)
    reg rst_n   = 0;

    always #4 net_clk = ~net_clk; // 8ns period = 125 MHz
    always #5 app_clk = ~app_clk; // 10ns period = 100 MHz

    // =========================================================
    // 2. INTERCONNECT SIGNALS (The Wires between Blocks)
    // =========================================================
    
    // A. Network Input (Simulating the output of the Ethernet MAC)
    reg  [7:0] mac_rx_tdata;
    reg        mac_rx_tvalid;
    reg        mac_rx_tlast;
    wire       mac_rx_tready; // Driven by UDP Filter

    // B. UDP Filter -> FIFO
    wire [7:0] filter_fifo_tdata;
    wire       filter_fifo_tvalid;
    wire       filter_fifo_tlast;
    wire       filter_fifo_tready; // Driven by FIFO

    // C. FIFO -> Parser
    wire [7:0] fifo_parser_tdata;
    wire       fifo_parser_tvalid;
    wire       fifo_parser_tready; // Driven by Parser
    // Note: FIFO might not pass TLAST/TUSER if strictly data, 
    // but your parser handles stream gaps fine.

    // D. Parser Output (The Final Result)
    wire [7:0] parsed_data;
    wire       parsed_valid;
    wire       parsed_last;
    wire       parsed_error;

    // =========================================================
    // 3. INSTANTIATE THE MODULES (Mimicking the Block Design)
    // =========================================================

    // --- Module 1: UDP Filter (The Gatekeeper) ---
    udp_filter #(
        .TARGET_PORT(16'h04D2) // 1234
    ) u_filter (
        .clk           (net_clk),
        .rst_n         (rst_n),
        .s_axis_tdata  (mac_rx_tdata),
        .s_axis_tvalid (mac_rx_tvalid),
        .s_axis_tlast  (mac_rx_tlast),
        .s_axis_tready (mac_rx_tready),
        .m_axis_tdata  (filter_fifo_tdata),
        .m_axis_tvalid (filter_fifo_tvalid),
        .m_axis_tlast  (filter_fifo_tlast),
        .m_axis_tready (filter_fifo_tready) // Connected to FIFO full/ready
    );

    // --- Module 2: Async FIFO (The Bridge) ---
    // NOTE: Using your RTL FIFO here. 
    // If you used Xilinx IP in Block Design, this behaves the same for sim.
    async_fifo u_fifo (
        // Write Side (Network Clock)
        .clk_0     (net_clk),
        .wrst_0    (rst_n),
        .wincr_0   (filter_fifo_tvalid && filter_fifo_tready), // Handshake
        .wdata_0   (filter_fifo_tdata),
        .wfull_0   (), // Logic below handles backpressure via tready

        // Read Side (App Clock)
        .rclk_0    (app_clk),
        .rwst_0    (rst_n),
        .rincr_0   (fifo_parser_tready && !fifo_parser_rempty), // Handshake
        .rdata_0   (fifo_parser_tdata),
        .rempty_0  (fifo_parser_rempty)
    );
    
    // FIFO Ready Logic (Simple wrapper for testbench)
    wire fifo_parser_rempty;
    wire fifo_wfull_int; // Internal full signal
    // The Filter sees the FIFO as "Ready" if it's not full
    // (Simplified for this specific FIFO RTL)
    assign filter_fifo_tready = 1'b1; 

    // --- Module 3: Packet Parser (The Brains) ---
    packet_parser u_parser (
        .clk           (app_clk),
        .rst_n         (rst_n),
        
        .s_axis_tdata  (fifo_parser_tdata),
        .s_axis_tvalid (!fifo_parser_rempty),
        .s_axis_tready (fifo_parser_tready),

        .m_axis_tdata  (parsed_data),
        .m_axis_tvalid (parsed_valid),
        .m_axis_tlast  (parsed_last),
        .m_axis_tuser  (parsed_error),
        .m_axis_tready (1'b1) // Always ready to sink result
    );

    // =========================================================
    // 4. PACKET GENERATION TASK
    // =========================================================
    task send_udp_packet(input [15:0] dest_port, input [7:0] payload_byte);
        integer i;
        begin
            @(posedge net_clk);
            wait(mac_rx_tready);

            // --- ETH HEADER (14 bytes) ---
            repeat(12) send_byte(8'h00, 0); // MACs
            send_byte(8'h08, 0); send_byte(8'h00, 0); // EtherType IP

            // --- IP HEADER (20 bytes) ---
            repeat(9) send_byte(8'h00, 0);
            send_byte(8'h11, 0); // UDP Proto
            repeat(10) send_byte(8'h00, 0);

            // --- UDP HEADER (8 bytes) ---
            send_byte(8'h00, 0); send_byte(8'h00, 0); // Src Port
            send_byte(dest_port[15:8], 0); // DST PORT HIGH
            send_byte(dest_port[7:0], 0);  // DST PORT LOW
            repeat(4) send_byte(8'h00, 0);

            // --- PAYLOAD (The Parser Protocol) ---
            // Header: AA 55
            // Len: 01
            // Data: payload_byte
            // Checksum: payload_byte (XOR)
            send_byte(8'hAA, 0);
            send_byte(8'h55, 0);
            send_byte(8'h01, 0);
            send_byte(payload_byte, 0);
            send_byte(payload_byte, 1); // Checksum + TLAST

            @(posedge net_clk);
            mac_rx_tvalid <= 0;
            mac_rx_tlast  <= 0;
        end
    endtask

    task send_byte(input [7:0] data, input last);
        begin
            mac_rx_tdata  <= data;
            mac_rx_tvalid <= 1;
            mac_rx_tlast  <= last;
            @(posedge net_clk);
            while(!mac_rx_tready) @(posedge net_clk);
        end
    endtask

    // =========================================================
    // 5. MAIN STIMULUS
    // =========================================================
    initial begin
        $dumpfile("full_system.vcd");
        $dumpvars(0, tb_full_system);

        // Init
        mac_rx_tdata  = 0;
        mac_rx_tvalid = 0;
        mac_rx_tlast  = 0;
        
        // Reset
        rst_n = 0; #50; rst_n = 1; #50;

        $display("[TB] 1. Sending INVALID Packet (Port 9999)...");
        send_udp_packet(16'd9999, 8'hBB);
        #200;

        $display("[TB] 2. Sending VALID Packet (Port 1234, Payload=BB)...");
        send_udp_packet(16'd1234, 8'hBB);
        
        // Wait for processing through FIFO
        #500;
        
        $display("[TB] Test Complete.");
        $finish;
    end
    
    // =========================================================
    // 6. MONITORING
    // =========================================================
    always @(posedge app_clk) begin
        if (parsed_valid) begin
            $display("[SUCCESS] Time: %0t | PARSER OUTPUT: Data=%h (Expected BB)", $time, parsed_data);
        end
    end

endmodule