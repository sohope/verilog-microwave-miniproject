`timescale 1ns / 1ps

module rotary(
        input clk,
        input reset,
        input clean_key,
        input clean_s1,
        input clean_s2,
        output [15:0] led,
        output [7:0] count
        // output [1:0] direction
    );
    
    reg [1:0] r_prev_state = 2'b00;
    reg [1:0] r_curr_state = 2'b00;
    reg [7:0] r_count = 8'h00;    // 00 ~ ff
    reg r_led_toggle = 1'b0;
    reg r_prev_key = 1'b0;
    
    // 시계방향일 때는 카운터를 증가, 반시계방향일 때는 카운터를 감소
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_prev_state <= 0;            
            r_curr_state <= 0;            
            r_count <= 0;            
        end else begin
            r_prev_state <= r_curr_state;
            r_curr_state <= {clean_s1, clean_s2};
            case ({r_prev_state, r_curr_state})
                //  CW: 00 -> 10 -> 11 -> 01 -> 00
                4'b0010, 4'b1011, 4'b1101, 4'b0100: begin
                    if (r_count < 8'hFF) // overflow
                        r_count <= r_count + 1;
                end
                // CCW: 00 -> 01 -> 11 -> 10 -> 00
                4'b0001, 4'b0111, 4'b1110, 4'b1000: begin
                    if (r_count > 8'h00) // underflow
                        r_count <= r_count - 1;
                end
                default: begin
                    
                end
            endcase
        end
    end
    
    // key 버튼 입력 시 LED 토글
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_led_toggle <= 1'b0;
            r_prev_key <= 1'b0;
        end else begin
            r_prev_key <= clean_key;
            if (clean_key && !r_prev_key) begin
                r_led_toggle <= ~ r_led_toggle;
            end
        end
    end

    assign led[13] = r_led_toggle;
    assign led[12:8] = 5'b00000;    // 안쓰는 LED OFF
    assign led[7:0] = r_count;
    assign count = r_count;

endmodule
