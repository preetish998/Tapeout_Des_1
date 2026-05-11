module tt_um_pree(
    input wire clk,
    input wire rst_n,
    // UART
    input wire rx_uart, 

    output reg led, 
    input wire [1:0] baud_mode,

    // Debugging outputs (remove)
    output reg [152:0] switches
);

integer i;

wire rx_valid;
wire [7:0] rx_data;


uart3 #(
    .CLK_FREQ(1843200),
    .BIT_COUNT_EC(8)
) uart_inst (
    .clk(clk),
    .rst_n(rst_n),
    .rx(rx_uart),
    .rx_data(rx_data), // Connect to your data sink
    .rx_valid(rx_valid), // Monitor this signal for received data
    .baud_mode(baud_mode) // Connect baud_mode to control baud rate
);

// reg [15:0] switches [7:0];

always @(posedge clk) begin
    if (!rst_n) begin
        led <= 1'b0;
        switches <= 153'd0; // Clear all switches on reset
    end
    else begin
        led <= 1'b1;
        
        if (rx_valid) begin
            switches[rx_data[7:0]] <= 1'b1; // Store in lower 8 bits
        end

    end

end



endmodule
