`timescale 1ns / 1ps

/**
* signal이 입력되면 토글하여 LED[0]로 출력
*/
module led_toggle(
    input sig,      // signal
    input reset,
    output[1:0] led // 출력 LED
    );

    reg r_led_toggled = 1'b0;

    always @(posedge sig, posedge reset) begin
        if(reset) begin
            r_led_toggled<=0;
        end else begin
            r_led_toggled <= ~r_led_toggled;            
        end
    end

    //assign led[0] = (r_led_toggled==1)? 1'b1: 1'b0;
    assign led[0] = r_led_toggled;
endmodule

/**
* 500ms 마다 LED 출력을 반전하는 모듈
*/
module tick_led_on_off(
    input tick,
    input reset,
    output [1:0] led
    );

    reg [$clog2(500)-1:0] r_ms_counter = 0;
    reg r_led_bit = 1'b0;
    
    always @(posedge tick, posedge reset) begin
        if(reset) begin
            r_ms_counter <= 0;
        end else begin
            if(r_ms_counter == 500-1) begin     // 500ms가 되면
                r_ms_counter <= 0;
                r_led_bit <= ~r_led_bit;        // LED 값 반전
            end else begin
                r_ms_counter <= r_ms_counter +1;
            end
        end
    end 
    
    assign led[1] = r_led_bit;
endmodule
