`timescale 1ns / 1ps

module multiple_button_debouncer( 
    input i_clk,
    input i_reset,
    input i_btn,
    output reg [2:0] o_clean_btn
);

endmodule

module button_debouncer_timer_counter(
    input i_clk,
    input i_reset,
    input i_btn,
    output reg o_clean_btn
    );
    
    parameter DEBOUNCE_COUNT = 100_000_000/100; //10ms(1초의 100분할) 주기의 클럭을 만들기 위한 메인 클럭 사이클의 수

    reg [$clog2(DEBOUNCE_COUNT)-1:0] counter = 0;   // 버튼이 바운싱되는 동안 동작하는 카운터(10ms용)
    reg prev_btn_state = 0;   // 마지막으로 안정적이었던 버튼의 상태 저장용 변수

    always @(posedge i_clk, posedge i_reset) begin  // 버튼이나 리셋 누르면 트리거
        if (i_reset) begin  // 리셋 눌렀으면 초기화
            counter <= 0;
            prev_btn_state <= 0;
            o_clean_btn <= 0;
        end else begin  // 버튼 눌렀으면
            if(i_btn == prev_btn_state) begin  // 현재 버튼 입력(바운싱 신호)과 이전 안정된 신호의 상태가 같으면(바운싱 중이면)
                counter <= 0;   // 카운터 0으로 초기화
            end else begin // 현재 버튼 입력(바운싱 신호)과 이전 안정된 신호의 상태가 다르면(안정됐으면)
                if (counter >= DEBOUNCE_COUNT) begin    // 안정된지 10ms 지났으면
                    prev_btn_state <= i_btn;    // 현재 상태(High, Low)를 이전 안정된 신호의 상태로 저장
                    o_clean_btn <= i_btn;
                    counter <= 0;
                end else begin  // 안정된 시간이 아직 10ms가 지나지 않았으면 카운터 1증가
                    counter <= counter + 1;
                end
            end
        end
    end
endmodule
