`timescale 1ns / 1ps

// 문 열림: 짧은 "삡" 1회
module buzzer_door_open #(
    parameter CLK_FREQ = 100_000_000,
    parameter BEEP_FREQ = 2000,           // 2kHz 부저 주파수
    parameter BEEP_DURATION = CLK_FREQ / 10  // 100ms
)(
    input clk,
    input reset,
    input trigger,       // 문 열림 트리거
    output buzzer        // 부저 출력
);

    // 주파수 생성용 카운터 (2kHz = 50us 주기)
    localparam FREQ_CNT_MAX = CLK_FREQ / (2 * BEEP_FREQ) - 1;
    reg [$clog2(FREQ_CNT_MAX+1)-1:0] r_freq_cnt = 0;
    reg r_beep_clk = 0;

    // 부저 타이머 관련 레지스터
    reg [27:0] r_beep_timer = 0;
    reg r_beeping = 0;
    reg r_triggered = 0;

    // 2kHz 주파수 생성
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_freq_cnt <= 0;
            r_beep_clk <= 0;
        end else begin
            if (r_freq_cnt >= FREQ_CNT_MAX) begin
                r_freq_cnt <= 0;
                r_beep_clk <= ~r_beep_clk;
            end else begin
                r_freq_cnt <= r_freq_cnt + 1;
            end
        end
    end

    // 부저 타이머 및 제어
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_beep_timer <= 0;
            r_beeping <= 0;
            r_triggered <= 0;
        end else begin
            // 트리거 신호: "삡" 1회
            if (trigger && !r_triggered && !r_beeping) begin
                r_beeping <= 1;
                r_beep_timer <= 0;
                r_triggered <= 1;
            end
            // 부저 타이머 동작
            else if (r_beeping) begin
                r_beep_timer <= r_beep_timer + 1;
                // 단일 "삡" (100ms)
                if (r_beep_timer >= BEEP_DURATION) begin
                    r_beeping <= 0;
                    r_beep_timer <= 0;
                end
            end else begin
                // beeping이 끝난 후 trigger 해제 시 초기화
                if (!trigger) begin
                    r_triggered <= 0;
                end
            end
        end
    end

    // 부저 출력 생성
    assign buzzer = (r_beeping) ? r_beep_clk : 0;

endmodule

// 문 닫힘: "삡삡" 2회
module buzzer_door_close #(
    parameter CLK_FREQ = 100_000_000,
    parameter BEEP_FREQ = 2000,           // 2kHz 부저 주파수
    parameter BEEP_DURATION = CLK_FREQ / 10  // 100ms
)(
    input clk,
    input reset,
    input trigger,       // 문 닫힘 트리거
    output buzzer        // 부저 출력
);

    // 주파수 생성용 카운터 (2kHz = 50us 주기)
    localparam FREQ_CNT_MAX = CLK_FREQ / (2 * BEEP_FREQ) - 1;
    reg [$clog2(FREQ_CNT_MAX+1)-1:0] r_freq_cnt = 0;
    reg r_beep_clk = 0;

    // 부저 타이머 관련 레지스터
    reg [27:0] r_beep_timer = 0;
    reg r_beeping = 0;
    reg r_beep_phase = 0;   // 0: 삡 소리, 1: 휴지
    reg r_beep_count = 0;   // 0: 첫 번째, 1: 두 번째
    reg r_triggered = 0;

    // 2kHz 주파수 생성
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_freq_cnt <= 0;
            r_beep_clk <= 0;
        end else begin
            if (r_freq_cnt >= FREQ_CNT_MAX) begin
                r_freq_cnt <= 0;
                r_beep_clk <= ~r_beep_clk;
            end else begin
                r_freq_cnt <= r_freq_cnt + 1;
            end
        end
    end

    // 부저 타이머 및 제어
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_beep_timer <= 0;
            r_beeping <= 0;
            r_beep_phase <= 0;
            r_beep_count <= 0;
            r_triggered <= 0;
        end else begin
            // 문닫힘 트리거 발생 시
            if (trigger && !r_triggered && !r_beeping) begin
                r_beeping <= 1;
                r_beep_timer <= 0;
                r_beep_phase <= 0;
                r_beep_count <= 0;
                r_triggered <= 1;
            end
            // 부저 타이머 동작
            else if (r_beeping) begin
                r_beep_timer <= r_beep_timer + 1;

                if (r_beep_phase == 0) begin
                    // "삡" 소리 (100ms)
                    if (r_beep_timer >= BEEP_DURATION) begin
                        r_beep_timer <= 0;
                        r_beep_phase <= 1;
                    end
                end else begin
                    // 휴지 구간 (100ms)
                    if (r_beep_timer >= BEEP_DURATION) begin
                        r_beep_timer <= 0;
                        r_beep_count <= r_beep_count + 1;

                        if (r_beep_count >= 1) begin
                            // 2회 완료
                            r_beeping <= 0;
                            r_beep_phase <= 0;
                            r_beep_count <= 0;
                        end else begin
                            // 다음 삡으로
                            r_beep_phase <= 0;
                        end
                    end
                end
            end else begin
                // beeping이 끝난 후 trigger 해제 시 초기화
                if (!trigger) begin
                    r_triggered <= 0;
                end
            end
        end
    end

    // 부저 출력 생성
    assign buzzer = (r_beeping && r_beep_phase == 0) ? r_beep_clk : 0;

endmodule

module buzzer_finish #(
    parameter CLK_FREQ = 100_000_000,
    parameter BEEP_FREQ = 2000,           // 2kHz 부저 주파수
    parameter BEEP_DURATION = CLK_FREQ / 10  // 100ms
)(
    input clk,
    input reset,
    input beep_finish,   // 타이머 종료 부저 트리거 (3회)
    output buzzer,       // 부저 출력
    output buzzer_done   // 3회 울림 완료 신호
);

    // 주파수 생성용 카운터 (2kHz = 50us 주기)
    localparam FREQ_CNT_MAX = CLK_FREQ / (2 * BEEP_FREQ) - 1;
    reg [$clog2(FREQ_CNT_MAX+1)-1:0] r_freq_cnt = 0;
    reg r_beep_clk = 0;

    // 부저 타이머 관련 레지스터
    reg [27:0] r_beep_timer = 0;
    reg r_beeping = 0;
    reg r_beep_phase = 0;   // 0: 삡 소리, 1: 휴지
    reg [1:0] r_beep_count = 0;  // 0~2: 첫/두/세 번째 삡
    reg r_finish_done = 0;  // 3회 울림 완료 플래그
    reg r_finish_triggered = 0;  // finish 한 번만 트리거되도록

    // 2kHz 주파수 생성
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_freq_cnt <= 0;
            r_beep_clk <= 0;
        end else begin
            if (r_freq_cnt >= FREQ_CNT_MAX) begin
                r_freq_cnt <= 0;
                r_beep_clk <= ~r_beep_clk;
            end else begin
                r_freq_cnt <= r_freq_cnt + 1;
            end
        end
    end

    // 부저 타이머 및 제어
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_beep_timer <= 0;
            r_beeping <= 0;
            r_beep_phase <= 0;
            r_beep_count <= 0;
            r_finish_done <= 0;
            r_finish_triggered <= 0;
        end else begin
            // 타이머 종료: "삡삡삡" 3회 소리
            if (beep_finish && !r_finish_triggered && !r_beeping) begin
                r_beeping <= 1;
                r_beep_timer <= 0;
                r_beep_phase <= 0;
                r_beep_count <= 0;
                r_finish_done <= 0;
                r_finish_triggered <= 1;
            end
            // 부저 타이머 동작
            else if (r_beeping) begin
                r_beep_timer <= r_beep_timer + 1;

                if (r_beep_phase == 0) begin
                    // "삡" 소리 (100ms)
                    if (r_beep_timer >= BEEP_DURATION) begin
                        r_beep_timer <= 0;
                        r_beep_phase <= 1;  // 휴지로 전환
                    end
                end else begin
                    // 휴지 구간 (100ms)
                    if (r_beep_timer >= BEEP_DURATION) begin
                        r_beep_timer <= 0;
                        r_beep_count <= r_beep_count + 1;

                        if (r_beep_count >= 2) begin
                            // 3회 완료
                            r_beeping <= 0;
                            r_beep_phase <= 0;
                            r_beep_count <= 0;
                            r_finish_done <= 1;
                        end else begin
                            // 다음 삡으로
                            r_beep_phase <= 0;
                        end
                    end
                end
            end else begin
                // beeping이 끝난 후 finish_done 유지
                if (!beep_finish) begin
                    r_finish_done <= 0;
                    r_finish_triggered <= 0;
                end
            end
        end
    end

    // 부저 출력 생성
    reg r_buzzer_out = 0;
    always @(*) begin
        if (r_beeping && r_beep_phase == 0) begin
            // "삡" 소리 구간
            r_buzzer_out = r_beep_clk;
        end else begin
            // 휴지 구간 또는 울리지 않음
            r_buzzer_out = 0;
        end
    end

    assign buzzer = r_buzzer_out;
    assign buzzer_done = r_finish_done;

endmodule
