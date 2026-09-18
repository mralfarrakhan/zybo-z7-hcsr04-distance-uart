// cetak dan ganti baris
`timescale 1ns / 1ps
module uart_tx #(
    parameter CLK_FREQ = 125_000_000,
    parameter BAUD_RATE = 115200
)(
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire send,
    output reg tx,
    output reg busy
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // 1085

    localparam IDLE = 2'b00;
    localparam START = 2'b01;
    localparam DATA = 2'b10;
    localparam STOP = 2'b11;

    reg [1:0] state = IDLE;
    reg [31:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    reg [9:0] data_reg = 10'b1111; // <-- PENTING: LATCH DATA DISINI

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                tx <= 1'b1;
                busy <= 1'b0;
                clk_count <= 0;
                if (send) begin
                    data_reg <= {1'b1, data_in, 1'b0}; // STOP + DATA + START
                    busy <= 1'b1;
                    state <= START;
                end
            end
            START: begin
                tx <= data_reg[0]; // kirim start bit = 0
                if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                else begin
                    clk_count <= 0;
                    state <= DATA;
                    bit_index <= 0;
                end
            end
            DATA: begin
                tx <= data_reg[bit_index + 1]; // kirim data bit
                if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                else begin
                    clk_count <= 0;
                    if (bit_index < 7) bit_index <= bit_index + 1;
                    else state <= STOP;
                end
            end
            STOP: begin
                tx <= data_reg[9]; // kirim stop bit = 1
                if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                else begin
                    clk_count <= 0;
                    busy <= 1'b0;
                    state <= IDLE;
                end
            end
        endcase
    end
endmodule
