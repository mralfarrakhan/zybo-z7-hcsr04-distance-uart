// HC-SR04 distance -> UART, "D=xxxcm\r\n" once per second
`timescale 1ns / 1ps
module top (
    input  wire clk,
    output wire hc_trig,
    input  wire hc_echo,
    output wire uart_tx
);

    localparam integer CLK_FREQ_HZ = 125_000_000;
    localparam integer ONE_SEC     = CLK_FREQ_HZ;

    wire [15:0] distance_cm;
    wire        data_valid;
    wire        tx_busy;

    hc_sr04_controller #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ)
    ) u_hc_sr04 (
        .clk         (clk),
        .rst         (1'b0),
        .echo        (hc_echo),
        .trig        (hc_trig),
        .distance_cm (distance_cm),
        .data_valid  (data_valid)
    );

    uart_tx #(
        .CLK_FREQ  (CLK_FREQ_HZ),
        .BAUD_RATE (115200)
    ) u_uart_tx (
        .clk     (clk),
        .rst     (1'b0),
        .data_in (data_to_send),
        .send    (send),
        .tx      (uart_tx),
        .busy    (tx_busy)
    );

    // Latest measurement, kept fresh independently of the transmit schedule
    reg [15:0] distance_reg;
    always @(posedge clk) begin
        if (data_valid) distance_reg <= distance_cm;
    end

    // 1 second timer
    reg [26:0] second_timer;
    always @(posedge clk) begin
        if (second_timer < ONE_SEC - 1) second_timer <= second_timer + 1'b1;
        else                            second_timer <= 27'd0;
    end
    wire one_sec_pulse = (second_timer == ONE_SEC - 1);

    // Binary to BCD conversion for 3-digit decimal display (0..999)
    wire [9:0] dist_clamped = (distance_reg > 16'd999) ? 10'd999 : distance_reg[9:0];
    reg [3:0] bcd_hundreds, bcd_tens, bcd_units;

    integer i;
    reg [11:0] bcd_temp;
    always @(*) begin
        bcd_temp = 12'd0;
        for (i = 9; i >= 0; i = i - 1) begin
            if (bcd_temp[3:0] >= 5)  bcd_temp[3:0]  = bcd_temp[3:0] + 4'd3;
            if (bcd_temp[7:4] >= 5)  bcd_temp[7:4]  = bcd_temp[7:4] + 4'd3;
            if (bcd_temp[11:8] >= 5) bcd_temp[11:8] = bcd_temp[11:8] + 4'd3;
            bcd_temp = {bcd_temp[10:0], dist_clamped[i]};
        end
        bcd_hundreds = bcd_temp[11:8];
        bcd_tens     = bcd_temp[7:4];
        bcd_units    = bcd_temp[3:0];
    end

    // "D=xxxcm\r\n" send FSM, one character per UART frame
    reg [7:0] data_to_send;
    reg       send;
    reg [3:0] char_index;
    reg       sending;
    reg [3:0] hundreds, tens, units;

    function [7:0] get_char;
        input [3:0] index;
        begin
            case (index)
                4'd0: get_char = "D";
                4'd1: get_char = "=";
                4'd2: get_char = 8'h30 + hundreds;
                4'd3: get_char = 8'h30 + tens;
                4'd4: get_char = 8'h30 + units;
                4'd5: get_char = "c";
                4'd6: get_char = "m";
                4'd7: get_char = 8'h0D; // CR
                4'd8: get_char = 8'h0A; // LF
                default: get_char = " ";
            endcase
        end
    endfunction

    always @(posedge clk) begin
        send <= 1'b0; // pulse for exactly 1 clock per character
        if (!sending) begin
            if (one_sec_pulse) begin
                hundreds   <= bcd_hundreds;
                tens       <= bcd_tens;
                units      <= bcd_units;
                char_index <= 4'd0;
                sending    <= 1'b1;
            end
        end
        else begin
            if (!tx_busy && !send) begin
                data_to_send <= get_char(char_index);
                send         <= 1'b1;
                if (char_index == 4'd8) sending <= 1'b0;
                else                    char_index <= char_index + 1'b1;
            end
        end
    end
endmodule
