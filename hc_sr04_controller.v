`timescale 1ns / 1ps
module hc_sr04_controller #(
    parameter integer CLK_FREQ_HZ = 125_000_000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        echo,
    output reg         trig,
    output reg [15:0]  distance_cm,
    output reg         data_valid
);

    localparam integer CLOCKS_PER_US = CLK_FREQ_HZ / 1_000_000; // = 125
    localparam integer MAX_ECHO_US   = 20_000;                  // timeout 20ms
    localparam integer TRIG_US       = 10;                      // 10us trigger pulse

    // State Machine
    localparam [1:0]
        S_IDLE       = 2'd0,
        S_TRIGGER    = 2'd1,
        S_WAIT_ECHO  = 2'd2,
        S_MEASURE    = 2'd3;

    reg [1:0]  state;
    reg [6:0]  us_counter;
    reg [15:0] timer_us;
    reg [5:0]  tick_58;

    wire us_tick = (us_counter == CLOCKS_PER_US - 1);

    // 1us tick generator
    always @(posedge clk) begin
        if (rst || us_tick) us_counter <= 7'd0;
        else                us_counter <= us_counter + 7'd1;
    end

    // 2FF synchronizer for the async echo input
    reg echo_ff1, echo_ff2, echo_prev;
    always @(posedge clk) begin
        echo_ff1  <= echo;
        echo_ff2  <= echo_ff1;
        echo_prev <= echo_ff2;
    end
    wire echo_rising  = echo_ff2 & ~echo_prev;
    wire echo_falling = ~echo_ff2 & echo_prev;

    // Main FSM
    always @(posedge clk) begin
        if (rst) begin
            state       <= S_IDLE;
            trig        <= 1'b0;
            data_valid  <= 1'b0;
            timer_us    <= 16'd0;
            tick_58     <= 6'd0;
            distance_cm <= 16'd0;
        end
        else begin
            data_valid <= 1'b0;
            case (state)

                S_IDLE: begin
                    trig     <= 1'b0;
                    timer_us <= 16'd0;
                    state    <= S_TRIGGER;
                end

                // TRIG stays high for exactly TRIG_US microseconds
                S_TRIGGER: begin
                    trig <= 1'b1;
                    if (us_tick) begin
                        if (timer_us < TRIG_US - 1)
                            timer_us <= timer_us + 16'd1;
                        else begin
                            trig     <= 1'b0;
                            timer_us <= 16'd0;
                            state    <= S_WAIT_ECHO;
                        end
                    end
                end

                // Wait for ECHO to go high; bail out on timeout so we never deadlock
                S_WAIT_ECHO: begin
                    if (echo_rising) begin
                        tick_58     <= 6'd0;
                        distance_cm <= 16'd0;
                        timer_us    <= 16'd0;
                        state       <= S_MEASURE;
                    end
                    else if (us_tick) begin
                        if (timer_us < MAX_ECHO_US - 1)
                            timer_us <= timer_us + 16'd1;
                        else begin
                            distance_cm <= 16'd0;
                            data_valid  <= 1'b1;
                            state       <= S_IDLE;
                        end
                    end
                end

                // Count how long ECHO stays high; 58 us corresponds to 1 cm
                S_MEASURE: begin
                    if (echo_falling) begin
                        data_valid <= 1'b1;
                        state      <= S_IDLE;
                    end
                    else if (us_tick) begin
                        if (timer_us < MAX_ECHO_US - 1) begin
                            timer_us <= timer_us + 16'd1;
                            if (tick_58 == 6'd57) begin
                                tick_58     <= 6'd0;
                                distance_cm <= distance_cm + 16'd1;
                            end
                            else begin
                                tick_58 <= tick_58 + 6'd1;
                            end
                        end
                        else begin
                            // Timeout
                            distance_cm <= 16'd0;
                            data_valid  <= 1'b1;
                            state       <= S_IDLE;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
