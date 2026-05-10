// =============================================================================
// uart.v — Basic UART (TX + RX), 8N1, runtime-selectable baud rate
//
// Parameters:
//   CLK_FREQ  — System clock in Hz  (default 1.8432 MHz)
//
// baud_mode[1:0] encoding:
//   2'b00  →   9600 baud
//   2'b01  →  38400 baud
//   2'b10  → 115200 baud  (default)
//   2'b11  → 230400 baud
// =============================================================================

module uart3 #(
    parameter CLK_FREQ    = 1843200,
    parameter BIT_COUNT_EC = 8
)(
    input  wire       clk,
    input  wire       rst_n,

    // RX
    input  wire       rx,
    output reg  [BIT_COUNT_EC-1:0] rx_data,
    output reg        rx_valid,

    // Baud rate select: 2 pins, 4 modes
    input wire [1:0]  baud_mode
);

    // =========================================================================
    // Baud rate divisor lookup (runtime, from baud_mode pins)
    // All four values are exact for CLK_FREQ = 1_843_200 Hz.
    // For other clock frequencies, adjust the localparam values below.
    // =========================================================================
    localparam CLKS_9600   = CLK_FREQ /   9600;   // 192
    localparam CLKS_38400  = CLK_FREQ /  38400;   //  48
    localparam CLKS_115200 = CLK_FREQ / 115200;   //  16
    localparam CLKS_230400 = CLK_FREQ / 230400;   //   8

    reg [15:0] clks_per_bit;
    reg [15:0] clks_per_bit_x2;   // half-bit for RX start-bit centering

    always @(*) begin
        case (baud_mode)
            2'b00: begin clks_per_bit = CLKS_9600;   clks_per_bit_x2 = CLKS_9600   / 2; end
            2'b01: begin clks_per_bit = CLKS_38400;  clks_per_bit_x2 = CLKS_38400  / 2; end
            2'b10: begin clks_per_bit = CLKS_115200; clks_per_bit_x2 = CLKS_115200 / 2; end
            2'b11: begin clks_per_bit = CLKS_230400; clks_per_bit_x2 = CLKS_230400 / 2; end
        endcase
    end

    // =========================================================================
    // RX  (2-FF synchroniser + half-bit start centering)
    // =========================================================================
    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg rx_s1, rx_s2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rx_s1 <= 1'b1; rx_s2 <= 1'b1; end
        else        begin rx_s1 <= rx;    rx_s2 <= rx_s1; end
    end
    wire rx_sync = rx_s2;

    reg [1:0]  rx_state;
    reg [15:0] rx_cnt;
    reg [BIT_COUNT_EC-1:0] rx_shift;
    reg [3:0]  rx_bit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            rx_cnt   <= 0;
            rx_shift <= 0;
            rx_bit   <= 0;
            rx_data  <= 0;
            rx_valid <= 0;
        end else begin
            rx_valid <= 1'b0;

            case (rx_state)
                RX_IDLE: begin
                    if (!rx_sync) begin
                        rx_cnt   <= 0;
                        rx_state <= RX_START;
                    end
                end
                RX_START: begin
                    if (rx_cnt == clks_per_bit_x2 - 1) begin
                        rx_cnt   <= 0;
                        rx_bit   <= 0;
                        rx_state <= RX_DATA;
                    end else
                        rx_cnt <= rx_cnt + 1;
                end
                RX_DATA: begin
                    if (rx_cnt == clks_per_bit - 1) begin
                        rx_cnt   <= 0;
                        rx_shift <= {rx_sync, rx_shift[BIT_COUNT_EC-1:1]};
                        if (rx_bit == BIT_COUNT_EC - 1)
                            rx_state <= RX_STOP;
                        else
                            rx_bit <= rx_bit + 1;
                    end else
                        rx_cnt <= rx_cnt + 1;
                end
                RX_STOP: begin
                    if (rx_cnt == clks_per_bit - 1) begin
                        rx_cnt   <= 0;
                        rx_data  <= rx_shift;
                        rx_valid <= 1'b1;
                        rx_state <= RX_IDLE;
                    end else
                        rx_cnt <= rx_cnt + 1;
                end
            endcase
        end
    end

endmodule