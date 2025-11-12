`timescale 1ns / 1ps

/**
* 1ms마다 10ns의 High 신호를 주는 틱 생성 모듈
*/
module tick_generator(
    input clk,
    input reset,
    output reg tick
    );
    
    parameter INPUT_FREQ = 100_000_000;             // 입력 클록의 파형수가 100MHz임을 의미
    parameter TICK_HZ = 1000;                       // 틱의 파형수가 1KHz가 됨을 의미, 1ms를 만드려면 1/f=0.001s에서 f=1000이 되어야 함을 의미
    parameter TICK_COUNT = INPUT_FREQ / TICK_HZ;    // 입력 클록 안에 틱의 파형이 몇번 들어가는지를 의미 
    
    reg [$clog2(TICK_COUNT)-1:0] r_tick_counter = 0;    // 정수 100,000을 저장할 수 있는 최소 비트 수 계산, 0000_0000_0000_0000_0000로 초기화

    always @(posedge clk or posedge reset) begin // clk 100MHz이므로 10ns마다 트리거(1초에 1억번 트리거)
        if(reset) begin
            r_tick_counter<=0;
            tick<=0;
        end else begin
            if(r_tick_counter == TICK_COUNT-1) begin    // 틱 카운트가 99,999이면(1ms 지나면) 10ns동안만 High 유지
                r_tick_counter<=0;
                tick <= 1'b1;
            end else begin
                r_tick_counter <= r_tick_counter + 1;   // 틱 카운트가 1초가 안됐으면 증가시키면서 Low로 유지
                tick <= 1'b0;
            end
        end
    end
    
endmodule
