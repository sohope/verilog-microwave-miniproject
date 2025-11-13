`timescale 1ns / 1ps

module btn_command_controller(
        input clk,
        input reset,
        input btnL,
        input btnR,
        input [7:0] rotary_count,  // rotary encoder 카운트 입력
        input sw,             // SW0 스위치 입력 (서보모터용)
        input buzzer_done,    // 부저 3회 완료 신호
        output [13:0] seg_data,
        output [2:0] mode,
        output beep_finish    // 타이머 종료 부저 트리거 (3회)
    );

    // MODE 정의
    parameter IDLE_MODE = 2'b00;
    parameter PAUSE_MODE = 2'b01;
    parameter START_MODE = 2'b10;
    parameter FINISH_MODE = 2'b11;

    // 시간 사이클 정의
    parameter MAIN_FREQUENCY = 100_000_000;             // 메인 클럭 주파수
    parameter CLOCK_CYCLE_10MS= MAIN_FREQUENCY/100;     // 10ms당 클럭 사이클 수
    parameter CLOCK_CYCLE_1SEC= MAIN_FREQUENCY;         // 1sec용 클럭 사이클 수
    parameter CLOCK_CYCLE_5SEC= MAIN_FREQUENCY*5;     // 5sec용 클럭 사이클 수
    parameter CLOCK_CYCLE_1MIN= 60;                     // 1min용 사이클 수
    parameter CLOCK_CYCLE_1HOUR= 60;                     // 1min용 사이클 수

    reg r_prev_btnL=0;
    reg r_prev_btnR=0;
    reg [7:0] r_prev_rotary_count=0;  // 이전 rotary count 값 저장

    // 상태 레지스터 (Moore FSM)
    reg [1:0] curr_state, next_state;

    // 분초시계용 카운터
    reg [$clog2(CLOCK_CYCLE_1SEC)-1:0] r_counter_10ns;      // 10ns마다 1증가
    reg [$clog2(CLOCK_CYCLE_1MIN)-1:0] r_counter_1sec = 59;      // 1s마다 1증가, 분초시계 표시용
    reg [$clog2(CLOCK_CYCLE_1HOUR)-1:0] r_counter_1min = 5;      // 1min마다 1증가, 분초시계 표시용

    // IDLE 자동 진입용 5초 타이머
    reg [$clog2(CLOCK_CYCLE_5SEC)-1:0] r_idle_timer = 0;        // 5초 타이머 카운터

    // 로터리 엔코더 변화량 계산용 변수
    reg signed [8:0] r_delta;         // 로터리 변화량 (-128 ~ +127)
    reg [15:0] r_total_seconds;       // 총 초 계산용 (0 ~ 5999)

    // 1. 상태 레지스터 업데이트 (Moore FSM - 순차 로직)
    always @(posedge clk, posedge reset) begin
        if (reset)
            curr_state <= IDLE_MODE;
        else
            curr_state <= next_state;
    end

    // 2. 다음 상태 로직 (Moore FSM - 조합 로직)
    wire btnL_edge = btnL && !r_prev_btnL;  // btnL의 rising edge 검출
    wire btnR_edge = btnR && !r_prev_btnR;  // btnR의 rising edge 검출
    wire rotary_changed = (rotary_count != r_prev_rotary_count);  // rotary count 변화 감지

    always @(*) begin
        case(curr_state)
            IDLE_MODE: begin
                if (rotary_changed)
                    next_state = PAUSE_MODE;  // rotary encoder 회전 시 PAUSE로
                else
                    next_state = IDLE_MODE;
            end

            PAUSE_MODE: begin
                if (btnL_edge)
                    next_state = START_MODE;  // btnL 누르면 START로
                else if (btnR_edge)
                    next_state = IDLE_MODE;   // btnR 누르면 IDLE로
                else
                    next_state = PAUSE_MODE;
            end

            START_MODE: begin
                if (sw)
                    next_state = PAUSE_MODE;  // SW0 ON(문 열림)이면 PAUSE로
                else if (btnR_edge)
                    next_state = PAUSE_MODE;  // btnR 누르면 PAUSE로
                else if (btnL_edge)
                    next_state = PAUSE_MODE;  // btnL 누르면 PAUSE로
                else if (r_counter_1min == 0 && r_counter_1sec == 0)
                    next_state = FINISH_MODE;  // 00:00 도달하면 FINISH로
                else
                    next_state = START_MODE;
            end

            FINISH_MODE: begin
                if (buzzer_done)
                    next_state = IDLE_MODE;   // 부저 3회 완료 후 IDLE로
                else
                    next_state = FINISH_MODE;
            end

            default: next_state = IDLE_MODE;
        endcase
    end

    // 3. 타이머 및 기타 레지스터 업데이트 (순차 로직)
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_prev_btnL <= 0;
            r_prev_btnR <= 0;
            r_prev_rotary_count <= 0;
            r_idle_timer <= 0;
        end else begin
            r_prev_btnL <= btnL;
            r_prev_btnR <= btnR;
            r_prev_rotary_count <= rotary_count;

            if (curr_state == PAUSE_MODE) begin
                if (r_idle_timer == (CLOCK_CYCLE_5SEC)-1)
                    r_idle_timer <= 0;
                else
                    r_idle_timer <= r_idle_timer + 1;
            end else begin
                r_idle_timer <= 0;
            end
        end
    end

    // 분초 시계: (00분 00초 ~ 59분 59초, 1sec 단위)
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter_10ns <= 0;
            r_counter_1sec <= 5;
            r_counter_1min <= 1;
        end else begin
            if (curr_state == IDLE_MODE) begin
                r_counter_10ns <= 0;
                r_counter_1sec <= 0;
                r_counter_1min <= 0;
            end else if(curr_state == PAUSE_MODE) begin
                // PAUSE 모드에서는 rotary encoder 변경 시에만 시간 설정 (2초 단위)
                r_counter_10ns <= 0;

                // rotary encoder가 변경되었을 때만 시간 업데이트 (상대적 변화량 사용)
                if (rotary_changed) begin
                    // rotary encoder의 변화량 계산 (블로킹 할당 사용)
                    r_delta = $signed({1'b0, rotary_count}) - $signed({1'b0, r_prev_rotary_count});

                    // 현재 시간을 총 초로 변환 (블로킹 할당 사용)
                    r_total_seconds = r_counter_1min * 60 + r_counter_1sec;

                    // delta * 2초 만큼 증가/감소 (블로킹 할당 사용)
                    if (r_delta > 0) begin
                        // 시계방향: 시간 증가
                        r_total_seconds = r_total_seconds + (r_delta * 2);
                        if (r_total_seconds > 5999)
                            r_total_seconds = 5999;  // 최대 99분 59초
                    end else if (r_delta < 0) begin
                        // 반시계방향: 시간 감소
                        if (r_total_seconds >= (-r_delta * 2))
                            r_total_seconds = r_total_seconds - (-r_delta * 2);
                        else
                            r_total_seconds = 0;  // 최소 00분 00초
                    end

                    // 총 초를 분:초로 변환 (non-blocking 할당 사용)
                    r_counter_1min <= r_total_seconds / 60;
                    r_counter_1sec <= r_total_seconds % 60;
                end
            end
            else if (curr_state == START_MODE) begin  // 추가: 일시정지 시 카운트 정지  -->  && !r_pause
                if (r_counter_10ns == MAIN_FREQUENCY-1) begin  // 100,000,000-1(1s)에 도달하면
                    if (r_counter_1sec == 0) begin // 초단위가 0에 도달하면
                        if (r_counter_1min == 0) begin // 분단위가 0에 도달하면
                            // r_counter_1min <= 59;
                            // stop 모드로 변경
                        end else begin
                            r_counter_1min <= r_counter_1min - 1;
                            r_counter_1sec <= 59;
                        end
                        r_counter_10ns <= 0;
                    end else begin
                        r_counter_10ns <= 0;
                        r_counter_1sec <= r_counter_1sec - 1;
                    end
                end else begin
                    r_counter_10ns <= r_counter_10ns + 1;
                end
            end
        end
    end

    // FND 출력
    reg [13:0] r_seg_data;
    always @(*) begin
        case(curr_state)
            IDLE_MODE: begin
                // IDLE 모드: 00:00 표시
                r_seg_data = 0;
            end
            PAUSE_MODE, START_MODE: begin
                // 분:초 형식 (예: 12:34 = 12분 34초)
                r_seg_data = r_counter_1min * 100 + r_counter_1sec;
            end
            FINISH_MODE: begin
                // FINISH 모드: 00:00 표시 (깜빡임은 FND 컨트롤러에서 처리)
                r_seg_data = 0;
            end
            default: begin
                r_seg_data = 0;
            end
        endcase
    end

    assign seg_data = r_seg_data;
    assign mode = {1'b0, curr_state};

    // FINISH_MODE에서 부저 3회 트리거 신호 생성
    assign beep_finish = (curr_state == FINISH_MODE);

endmodule
