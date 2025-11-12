`timescale 1ns / 1ps

module buzzer_door #(
    parameter CLK_FREQ = 100_000_000,
    parameter BEEP_FREQ = 2000,           // 2kHz 부저 주파수
    parameter BEEP_DURATION = CLK_FREQ / 10  // 100ms
)(
    input clk,
    input reset,
    input sw,            // SW0 스위치 입력
    output buzzer        // 부저 출력
);

    // 주파수 생성용 카운터 (2kHz = 50us 주기)
    localparam FREQ_CNT_MAX = CLK_FREQ / (2 * BEEP_FREQ) - 1;
    reg [$clog2(FREQ_CNT_MAX+1)-1:0] r_freq_cnt = 0;
    reg r_beep_clk = 0;

    // 부저 타이머 관련 레지스터
    reg [27:0] r_beep_timer = 0;
    reg r_beeping = 0;
    reg r_beep_double = 0;  // 두 번 울림 플래그
    reg r_beep_phase = 0;   // 0: 첫 번째 삡, 1: 두 번째 삡

    // SW0 이전 값 저장 (엣지 검출용)
    reg r_prev_sw0 = 0;
    wire sw0_rising = sw && !r_prev_sw0;   // SW0 올릴 때
    wire sw0_falling = !sw && r_prev_sw0;  // SW0 내릴 때

    // SW 엣지 검출
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_prev_sw0 <= 0;
        end else begin
            r_prev_sw0 <= sw;
        end
    end

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
            r_beep_double <= 0;
            r_beep_phase <= 0;
        end else begin
            // SW0 올리면: 짧은 "삡" 소리
            if (sw0_rising && !r_beeping) begin
                r_beeping <= 1;
                r_beep_double <= 0;
                r_beep_timer <= 0;
                r_beep_phase <= 0;
            end
            // SW0 내리면: "삡삡" 소리 (복귀)
            else if (sw0_falling && !r_beeping) begin
                r_beeping <= 1;
                r_beep_double <= 1;
                r_beep_timer <= 0;
                r_beep_phase <= 0;
            end
            // 부저 타이머 동작
            else if (r_beeping) begin
                r_beep_timer <= r_beep_timer + 1;

                if (r_beep_double) begin
                    // "삡삡" 모드
                    if (r_beep_phase == 0) begin
                        // 첫 번째 "삡" (100ms)
                        if (r_beep_timer >= BEEP_DURATION) begin
                            r_beep_timer <= 0;
                            r_beep_phase <= 1;  // 두 번째 삡으로 전환
                        end
                    end else begin
                        // 휴지 100ms + 두 번째 "삡" 100ms = 200ms
                        if (r_beep_timer >= BEEP_DURATION * 2) begin
                            r_beeping <= 0;
                            r_beep_double <= 0;
                            r_beep_phase <= 0;
                            r_beep_timer <= 0;
                        end
                    end
                end else begin
                    // 단일 "삡" 모드 (100ms)
                    if (r_beep_timer >= BEEP_DURATION) begin
                        r_beeping <= 0;
                        r_beep_timer <= 0;
                    end
                end
            end
        end
    end

    // 부저 출력 생성
    reg r_buzzer_out = 0;
    always @(*) begin
        if (r_beep_double && r_beep_phase == 1) begin
            // "삡삡" 모드의 두 번째 삡
            if (r_beep_timer >= BEEP_DURATION) begin
                // 두 번째 "삡" (100ms ~ 200ms 구간)
                r_buzzer_out = r_beep_clk;
            end else begin
                // 휴지 구간 (0 ~ 100ms)
                r_buzzer_out = 0;
            end
        end else if (r_beeping) begin
            // 첫 번째 "삡" 또는 단일 "삡"
            r_buzzer_out = r_beep_clk;
        end else begin
            r_buzzer_out = 0;
        end
    end

    assign buzzer = r_buzzer_out;

endmodule
