`timescale 1ns / 1ps

module tb_trading_pipeline();

    // Clock and Reset
    reg clk;
    reg rst_n;
    
    // AXI Stream from Ethernet (input to DUT)
    reg [31:0]  eth_tdata;
    reg         eth_tvalid;
    reg         eth_tlast;
    wire        eth_tready;
    
    // Outputs from DUT
    wire [31:0] book_best_bid;
    wire [31:0] book_best_ask;
    wire        book_bbo_updated;
    
    // Debug outputs
    wire [31:0] debug_tick_price;
    wire [31:0] debug_tick_qty;
    wire        debug_tick_is_buy;
    wire        debug_tick_valid;
    
    // Clock generation: 125 MHz
    initial begin
        clk = 0;
        forever #4 clk = ~clk; // 8ns period = 125 MHz
    end
    
    // DUT Instantiation - Single top-level module
    trading_pipeline_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .eth_axis_tdata(eth_tdata),
        .eth_axis_tvalid(eth_tvalid),
        .eth_axis_tlast(eth_tlast),
        .eth_axis_tready(eth_tready),
        .best_bid(book_best_bid),
        .best_ask(book_best_ask),
        .bbo_updated(book_bbo_updated),
        .debug_tick_price(debug_tick_price),
        .debug_tick_qty(debug_tick_qty),
        .debug_tick_is_buy(debug_tick_is_buy),
        .debug_tick_valid(debug_tick_valid)
    );
    
    // Task to send a complete Ethernet frame - matching Python script format
    task send_udp_packet;
        input [31:0] price;
        input [31:0] qty;
        input [7:0]  side; // 'B' or 'S'
        reg [7:0] checksum;
        reg [7:0] payload [0:8]; // 9 bytes: 4 price + 4 qty + 1 side
        integer i;
        begin
            // Build payload (big-endian - matching Python struct.pack('>IIc'))
            payload[0] = price[31:24];
            payload[1] = price[23:16];
            payload[2] = price[15:8];
            payload[3] = price[7:0];
            payload[4] = qty[31:24];
            payload[5] = qty[23:16];
            payload[6] = qty[15:8];
            payload[7] = qty[7:0];
            payload[8] = side;
            
            // Calculate checksum (XOR of all payload bytes)
            checksum = 8'h00;
            for (i = 0; i < 9; i = i + 1) begin
                checksum = checksum ^ payload[i];
            end
            
            $display("=== Sending UDP Packet ===");
            $display("  Price: %d (0x%08x)", price, price);
            $display("  Qty:   %d (0x%08x)", qty, qty);
            $display("  Side:  '%c' (0x%02x)", side, side);
            $display("  Checksum: 0x%02x", checksum);
            
            // Send packet word by word (little-endian per word, as Ethernet MAC presents it)
            // Word 0: Dest MAC bytes 0-3 (little-endian within word)
            @(posedge clk);
            eth_tdata <= 32'hFFFFFFFF;
            eth_tvalid <= 1'b1;
            eth_tlast <= 1'b0;
            
            // Word 1: Dest MAC bytes 4-5 + Src MAC bytes 0-1
            @(posedge clk);
            eth_tdata <= 32'hAAAAFFFF;
            
            // Word 2: Src MAC bytes 2-5
            @(posedge clk);
            eth_tdata <= 32'hAAAAAAAA;
            
            // Word 3: EtherType 0x0800 (IPv4) at bytes [7:0] and [15:8]
            // Plus first 2 bytes of IP header
            @(posedge clk);
            eth_tdata <= {16'h4500, 8'h00, 8'h08}; // Little-endian: [08][00][00][45]
            
            // Word 4: IP header continuation
            @(posedge clk);
            eth_tdata <= 32'h0000002C; // Length and ID
            
            // Word 5: IP header with Protocol=0x11 at byte [31:24]
            @(posedge clk);
            eth_tdata <= {8'h11, 8'h00, 8'h40, 8'h00}; // [00][40][00][11]
            
            // Word 6: IP Checksum + Source IP start
            @(posedge clk);
            eth_tdata <= 32'hC0A80000; // [00][A8][C0][xx]
            
            // Word 7: Source IP end + Dest IP start (192.168.1.5 -> 192.168.1.10)
            @(posedge clk);
            eth_tdata <= {8'hC0, 8'hA8, 8'h01, 8'h05}; // [05][01][A8][C0]
            
            // Word 8: Dest IP end + UDP Source Port start
            @(posedge clk);
            eth_tdata <= {16'h1234, 8'h01, 8'h0A}; // [0A][01][34][12]
            
            // Word 9: UDP Src Port end + UDP Dest Port (1234 = 0x04D2)
            //         Port must be: [7:0]=0x04, [15:8]=0xD2 for filter to pass
            @(posedge clk);
            eth_tdata <= {16'h0018, 8'hD2, 8'h04}; // [04][D2][18][00] - Length 0x0018=24
            
            // Word 10: UDP Checksum (2 bytes) + [AA][55] header
            // Real HW capture shows: [83][85][AA][55]
            @(posedge clk);
            eth_tdata <= {8'h55, 8'hAA, 8'h85, 8'h83}; // [83][85][AA][55]
            
            // Word 11: [09] length + payload bytes 0-2 (price MSB bytes)
            // Real HW shows: [09][00][00][00] for price starting with 0x00000064
            @(posedge clk);
            eth_tdata <= {payload[2], payload[1], payload[0], 8'h09};
            
            // Word 12: Payload bytes 3-6
            @(posedge clk);
            eth_tdata <= {payload[6], payload[5], payload[4], payload[3]};
            
            // Word 13: Payload bytes 7-8 + checksum + padding
            @(posedge clk);
            eth_tdata <= {8'h00, checksum, payload[8], payload[7]};
            eth_tlast <= 1'b1;
            
            // End of packet
            @(posedge clk);
            eth_tvalid <= 1'b0;
            eth_tlast <= 1'b0;
            eth_tdata <= 32'h0;
            
            // Add idle cycles between packets
            repeat(10) @(posedge clk);
            
            $display("  Packet sent!");
        end
    endtask
    
    // Monitor book_builder updates
    always @(posedge clk) begin
        if (book_bbo_updated) begin
            $display("*** BBO UPDATED at time %0t ***", $time);
            $display("    best_bid = %d (0x%08x)", book_best_bid, book_best_bid);
            $display("    best_ask = %d (0x%08x)", book_best_ask, book_best_ask);
        end
    end
    
    // Monitor parser_shim ticks
    always @(posedge clk) begin
        if (debug_tick_valid) begin
            $display("  → parser_shim output at time %0t:", $time);
            $display("      price=%d, qty=%d, is_buy=%b", 
                     debug_tick_price, debug_tick_qty, debug_tick_is_buy);
        end
    end
    
    // Note: packet_parser output monitoring removed - can add back if needed for debug
    
    // Main test sequence
    initial begin
        $display("===========================================");
        $display("  Trading Pipeline Testbench Starting");
        $display("===========================================");
        
        // Initialize
        rst_n = 0;
        eth_tdata = 0;
        eth_tvalid = 0;
        eth_tlast = 0;
        
        // Reset pulse
        #100;
        rst_n = 1;
        #50;
        
        $display("\n--- Test 1: BUY order, price=100, qty=50 ---");
        send_udp_packet(32'd100, 32'd50, 8'h42); // 'B' = 0x42
        #500;
        
        $display("\n--- Test 2: BUY order, price=105, qty=75 ---");
        send_udp_packet(32'd105, 32'd75, 8'h42);
        #500;
        
        $display("\n--- Test 3: SELL order, price=110, qty=25 ---");
        send_udp_packet(32'd110, 32'd25, 8'h53); // 'S' = 0x53
        #500;
        
        $display("\n--- Test 4: SELL order, price=108, qty=30 ---");
        send_udp_packet(32'd108, 32'd30, 8'h53);
        #500;
        
        $display("\n===========================================");
        $display("  Final Book State:");
        $display("    best_bid = %d", book_best_bid);
        $display("    best_ask = %d", book_best_ask);
        $display("===========================================");
        
        if (book_best_bid == 105 && book_best_ask == 108) begin
            $display("*** TEST PASSED ***");
        end else begin
            $display("*** TEST FAILED ***");
        end
        
        #1000;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
    // Optional: dump waveforms
    initial begin
        $dumpfile("tb_trading_pipeline.vcd");
        $dumpvars(0, tb_trading_pipeline);
    end

endmodule
