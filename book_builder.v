module book_builder (
    input wire          clk,
    input wire          rst_n,

    // --- Input Interface (From Parser) ---
    input wire [31:0]   s_tick_price,   // Price (Integer, e.g., 15000 = $150.00)
    input wire [31:0]   s_tick_qty,     // Quantity (e.g., 100)
    input wire          s_tick_is_buy,  // 1 = Buy (Bid), 0 = Sell (Ask)
    input wire          s_tick_valid,   // Trigger signal

    // --- Output Interface (To ILA or Strategy) ---
    output reg [31:0]   best_bid,       // Highest Buy Price seen
    output reg [31:0]   best_ask,       // Lowest Sell Price seen
    output reg          bbo_updated     // Pulses high when BBO changes
);

    // =========================================================================
    // 1. Storage (Order Log in BRAM)
    // =========================================================================
    // We store the last 1024 ticks for debugging/replay
    // Format: {1'bSide, 31'bPrice} - packing for efficiency
    (* ram_style = "block" *) reg [31:0] order_log [0:1023]; 
    reg [9:0] log_ptr;

    // =========================================================================
    // 2. Main Logic
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            best_bid    <= 32'd0;           // Start at 0
            best_ask    <= 32'hFFFFFFFF;    // Start at Max Value (Infinity)
            bbo_updated <= 0;
            log_ptr     <= 0;
        end else begin
            bbo_updated <= 0; // Default: Pulse lasts 1 cycle

            if (s_tick_valid) begin
                
                // --- A. Store in Memory (Circular Buffer) ---
                // Store metadata: Bit 31 = Side, Bits 30:0 = Price (Simplified for log)
                if (s_tick_price > 0) begin
                
                    order_log[log_ptr] <= {s_tick_is_buy, s_tick_price[30:0]};
                    log_ptr            <= log_ptr + 1;
    
                    // --- B. Update Best Bid / Best Ask ---
                    if (s_tick_is_buy) begin
                        // BID LOGIC: If new price > current best, update it.
                        if (s_tick_price > best_bid) begin
                            best_bid    <= s_tick_price;
                            bbo_updated <= 1;
                        end
                    end else begin
                        // ASK LOGIC: If new price < current best, update it.
                        if (s_tick_price < best_ask) begin
                            best_ask    <= s_tick_price;
                            bbo_updated <= 1;
                        end
                    end
                end
             end
        end
    end

endmodule