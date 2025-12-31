module ethernet_init (
    input  wire        clk,
    input  wire        rst_n,

    // AXI4-Lite Master Interface (Connect to Ethernet s_axi)
    output reg  [31:0] m_axi_awaddr,
    output reg         m_axi_awvalid,
    input  wire        m_axi_awready,

    output reg  [31:0] m_axi_wdata,
    output reg  [3:0]  m_axi_wstrb,
    output reg         m_axi_wvalid,
    input  wire        m_axi_wready,

    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output reg         m_axi_bready,

    // Unused Read Channels (Tie off in Block Design or ignore)
    output wire [31:0] m_axi_araddr,
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready
);

    // =========================================================
    // CONSTANTS
    // =========================================================
    // TEMAC Register Offsets
    localparam ADDR_RCW1 = 32'h0000_0404; // RX Config Word 1
    localparam ADDR_TCW  = 32'h0000_0408; // TX Config Word
    
    // Commands (Bit 28 = Enable)
    localparam CMD_ENABLE = 32'h1000_0000;

    // States
    localparam S_IDLE       = 0;
    localparam S_WRITE_RX_A = 1; // Write Address for RX
    localparam S_WRITE_RX_D = 2; // Write Data for RX
    localparam S_RESP_RX    = 3; // Wait Response for RX
    localparam S_WRITE_TX_A = 4; // Write Address for TX
    localparam S_WRITE_TX_D = 5; // Write Data for TX
    localparam S_RESP_TX    = 6; // Wait Response for TX
    localparam S_DONE       = 7;

    reg [2:0] state;

    // Tie off Read Channels (We never read)
    assign m_axi_araddr  = 0;
    assign m_axi_arvalid = 0;
    assign m_axi_rready  = 0;

    // Tie off Write Strobes (Always write full 32-bits)
    always @(*) m_axi_wstrb = 4'b1111;

    // =========================================================
    // STATE MACHINE
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            m_axi_awvalid <= 0;
            m_axi_wvalid  <= 0;
            m_axi_bready  <= 0;
            m_axi_awaddr  <= 0;
            m_axi_wdata   <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    // Wait 100 cycles for Ethernet Core to wake up? 
                    // (Optional counter here). For now, go immediately.
                    state <= S_WRITE_RX_A;
                end

                // -----------------------------------------------------
                // TRANSACTION 1: ENABLE RECEIVER
                // -----------------------------------------------------
                S_WRITE_RX_A: begin
                    m_axi_awaddr  <= ADDR_RCW1;
                    m_axi_awvalid <= 1;
                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 0;
                        state <= S_WRITE_RX_D;
                    end
                end

                S_WRITE_RX_D: begin
                    m_axi_wdata  <= CMD_ENABLE;
                    m_axi_wvalid <= 1;
                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 0;
                        m_axi_bready <= 1; // Ready for response
                        state <= S_RESP_RX;
                    end
                end

                S_RESP_RX: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 0;
                        state <= S_WRITE_TX_A;
                    end
                end

                // -----------------------------------------------------
                // TRANSACTION 2: ENABLE TRANSMITTER
                // -----------------------------------------------------
                S_WRITE_TX_A: begin
                    m_axi_awaddr  <= ADDR_TCW;
                    m_axi_awvalid <= 1;
                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 0;
                        state <= S_WRITE_TX_D;
                    end
                end

                S_WRITE_TX_D: begin
                    m_axi_wdata  <= CMD_ENABLE;
                    m_axi_wvalid <= 1;
                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 0;
                        m_axi_bready <= 1;
                        state <= S_RESP_TX;
                    end
                end

                S_RESP_TX: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 0;
                        state <= S_DONE;
                    end
                end

                // -----------------------------------------------------
                // DONE
                // -----------------------------------------------------
                S_DONE: begin
                    // Stay here forever. Logic initialized.
                end
            endcase
        end
    end

endmodule