`timescale 1ns / 1ps

module btn_command_controller(
    input clk,
    input reset,
    input [3:0] debounced_btn_sig,
    input [7:0] sw,
    output [13:0] seg_data,
    output [2:0] mode,
    output reg [15:0] led
    );
    
    // MODE 정의
    parameter IDLE_MODE = 2'b00;
    parameter START_MODE = 2'b01;
    parameter STOP_MODE = 2'b10;

    // 시간 사이클 정의
    parameter MAIN_FREQUENCY = 100_000_000;             // 메인 클럭 주파수
    parameter CLOCK_CYCLE_10MS= MAIN_FREQUENCY/100;     // 10ms당 클럭 사이클 수
    parameter CLOCK_CYCLE_1SEC= MAIN_FREQUENCY;         // 1sec용 클럭 사이클 수
    parameter CLOCK_CYCLE_5SEC= MAIN_FREQUENCY*5;     // 5sec용 클럭 사이클 수
    parameter CLOCK_CYCLE_1MIN= 60;                     // 1min용 사이클 수
    parameter CLOCK_CYCLE_1HOUR= 60;                     // 1min용 사이클 수

    reg r_prev_btnL=0;
    reg r_prev_btnR=0;
    
    reg [4:0] r_mode = IDLE_MODE;

    // 분초시계용 카운터
    reg [$clog2(CLOCK_CYCLE_1SEC)-1:0] r_counter_10ns;      // 10ns마다 1증가
    reg [$clog2(CLOCK_CYCLE_1MIN)-1:0] r_counter_1sec = 59;      // 1s마다 1증가, 분초시계 표시용
    reg [$clog2(CLOCK_CYCLE_1HOUR)-1:0] r_counter_1min = 5;      // 1min마다 1증가, 분초시계 표시용

    // IDLE 자동 진입용 5초 타이머
    reg [$clog2(CLOCK_CYCLE_5SEC)-1:0] r_idle_timer = 0;        // 5초 타이머 카운터

    // mode check
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_mode <= IDLE_MODE;
            r_prev_btnL <= 0;
            r_prev_btnR <= 0;
            r_idle_timer <= CLOCK_CYCLE_5SEC-1;
        end else begin
            // IDLE 모드에서 아무 버튼이나 누르면 스톱워치 PAUSE 모드로 복귀
            if (r_mode == IDLE_MODE && (debounced_btn_sig != 4'b0000)) begin
                r_mode <= START_MODE;
                r_idle_timer <= 0;
            end
            // btnL: 모드 순환 (분초시계 <-> 스톱워치)
            else if (debounced_btn_sig[0] && !r_prev_btnL) begin
                case(r_mode)
                    IDLE_MODE: r_mode <= START_MODE; // 분초시계모드 -> 스톱워치 멈춤 모드
                    START_MODE: r_mode <= IDLE_MODE; // 스톱워치 멈춤 모드 -> 분초 시계 모드
                    STOP_MODE: r_mode <= IDLE_MODE; // 스톱워치 시작 모드 -> 분초 시계 모드
                    IDLE_MODE: r_mode <= START_MODE;          // IDLE 모드 -> 스톱워치 멈춤 모드
                    default: r_mode <= IDLE_MODE;
                endcase
                // r_stopwatch_running <= 0;   // 모드 전환 시 스톱워치 정지
                r_idle_timer <= 0;          // 타이머 리셋
            end
            // START_MODE에서 5초간 입력 없으면 IDLE로 전환
            else if (r_mode == START_MODE) begin
                if (r_idle_timer == (CLOCK_CYCLE_5SEC)-1) begin
                    r_mode <= IDLE_MODE;
                    r_idle_timer <= 0;
                end else begin
                    r_idle_timer <= r_idle_timer + 1;
                end
            end
            // 다른 모드들에 대해서는 타이머 리셋
            else begin
                r_idle_timer <= 0;
            end

            r_prev_btnL <= debounced_btn_sig[0];
            r_prev_btnR <= debounced_btn_sig[1];
        end
    end

    // 분초 시계: (00분 00초 ~ 59분 59초, 1sec 단위)
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter_10ns <= 0;
            r_counter_1sec <= 5;
            r_counter_1min <= 1;
        end else if (r_mode == IDLE_MODE) begin
            if (r_counter_10ns == MAIN_FREQUENCY-1) begin  // 100,000,000-1(1s)에 도달하면
                if (r_counter_1sec == 0) begin // 초단위가 0에 도달하면
                    if (r_counter_1min == 0) begin // 0에 도달하면
                        // r_counter_1min <= 59;
                        // stop 모드로 변경
                    end else begin
                        r_counter_1min <= r_counter_1min - 1;
                    end
                    r_counter_10ns <= 0;
                    r_counter_1sec <= 59;
                end else begin
                    r_counter_10ns <= 0;
                    r_counter_1sec <= r_counter_1sec - 1;
                end
            end else begin
                r_counter_10ns <= r_counter_10ns + 1;
            end
        end
    end

    // FND 출력
    reg [13:0] r_seg_data;
    always @(*) begin
        case(r_mode)
            IDLE_MODE: begin
                // 분:초 형식 (예: 12:34)
                r_seg_data = r_counter_1min * 100 + r_counter_1sec;
            end
            START_MODE, STOP_MODE: begin
                // 초.밀리초 형식 (예: 12.34초 = 1234)
                // r_seg_data = r_stopwatch_sec * 100 + r_stopwatch_10ms;
            end
            default: begin
                // IDLE 모드에서는 FND 컨트롤러에서 애니메이션 처리
                r_seg_data = 0;
            end
        endcase
    end

    assign seg_data = r_seg_data;
    assign mode = r_mode[2:0];

endmodule
