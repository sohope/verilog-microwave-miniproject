`timescale 1ns / 1ps

module power_on_melody #(
        parameter CLK_FREQ = 100_000_000,    // 클럭 주파수 (Hz)
        parameter TIME_SCALE = 1             // 시간 스케일 (시뮬레이션 시 작게 설정)
    )(
        input clk,
        input reset,
        input btnL,
        input btnR,
        output buzzer
    );

    // 시간 관련 파라미터 (TIME_SCALE로 나눠서 시뮬레이션 시간 단축)
    localparam NOTE_DURATION = (CLK_FREQ * 70 / 1000) / TIME_SCALE;  // 70ms
    localparam ROUTINE_DURATION = (CLK_FREQ * 3280 / 1000) / TIME_SCALE;  // 3.28초
    
    localparam [28:0] ROUTINE1_TOTAL_TIME = ROUTINE_DURATION - 1;
    localparam [28:0] ROUTINE2_TOTAL_TIME = ROUTINE_DURATION - 1;
    
    localparam [28:0] TIME_70MS  = NOTE_DURATION - 1;
    localparam [28:0] TIME_140MS = NOTE_DURATION * 2 - 1;
    localparam [28:0] TIME_210MS = NOTE_DURATION * 3 - 1;
    localparam [28:0] TIME_280MS = NOTE_DURATION * 4 - 1;

    // 주파수 카운터 값도 TIME_SCALE로 조정
    localparam [21:0] FREQ_1KHZ   = 22'd49_999 / TIME_SCALE;   // 1kHz
    localparam [21:0] FREQ_2KHZ   = 22'd24_999 / TIME_SCALE;   // 2kHz
    localparam [21:0] FREQ_3KHZ   = 22'd16_666 / TIME_SCALE;   // 3kHz
    localparam [21:0] FREQ_4KHZ   = 22'd12_499 / TIME_SCALE;   // 4kHz
    localparam [21:0] FREQ_261HZ  = 22'd191_570 / TIME_SCALE;  // 261Hz
    localparam [21:0] FREQ_329HZ  = 22'd151_975 / TIME_SCALE;  // 329Hz
    localparam [21:0] FREQ_392HZ  = 22'd127_551 / TIME_SCALE;  // 392Hz
    localparam [21:0] FREQ_554HZ  = 22'd90_252 / TIME_SCALE;   // 554Hz

    reg btnL_prev, btnR_prev;
    wire btnL_edge, btnR_edge;
    reg playing_routine1;
    reg playing_routine2;

    reg [28:0] routine1_total_cnt;
    reg [28:0] routine2_total_cnt;

    reg [21:0] freq_routine1_cnt;
    reg [21:0] freq_routine2_cnt;
    reg [21:0] freq_routine1;
    reg [21:0] freq_routine2;
    
    reg r_buzzer_routine1;
    reg r_buzzer_routine2;

    assign btnL_edge = btnL && !btnL_prev;
    assign btnR_edge = btnR && !btnR_prev;
    
    // btnL, btnR 토글 처리
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            btnL_prev <= 0;
            btnR_prev <= 0;
            playing_routine1 <= 0;
            playing_routine2 <= 0;
        end else begin
            btnL_prev <= btnL;
            btnR_prev <= btnR;
            if (btnL_edge) begin
                playing_routine1 <= ~playing_routine1;
            end
            if (btnR_edge) begin
                playing_routine2 <= ~playing_routine2;
            end
        end
    end
    
    // Routine1(btnL 입력) 전체 타이머
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            routine1_total_cnt <= 0;
        end else begin
            if (playing_routine1) begin
                if (routine1_total_cnt >= ROUTINE1_TOTAL_TIME) begin
                    routine1_total_cnt <= 0;
                end else begin
                    routine1_total_cnt <= routine1_total_cnt + 1;
                end
            end else begin
                routine1_total_cnt <= 0;
            end
        end
    end

    // Routine2(btnR 입력) 전체 타이머
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            routine2_total_cnt <= 0;
        end else begin
            if (playing_routine2) begin
                if (routine2_total_cnt >= ROUTINE2_TOTAL_TIME) begin
                    routine2_total_cnt <= 0;
                end else begin
                    routine2_total_cnt <= routine2_total_cnt + 1;
                end
            end else begin
                routine2_total_cnt <= 0;
            end
        end
    end
    
    // Routine1 시간대별 주파수 설정
    always @(*) begin
        if (routine1_total_cnt <= TIME_70MS) begin
            freq_routine1 = FREQ_1KHZ;
        end else if (routine1_total_cnt <= TIME_140MS) begin
            freq_routine1 = FREQ_2KHZ;
        end else if (routine1_total_cnt <= TIME_210MS) begin
            freq_routine1 = FREQ_3KHZ;
        end else if (routine1_total_cnt <= TIME_280MS) begin
            freq_routine1 = FREQ_4KHZ;
        end else begin
            freq_routine1 = 22'd0;  // 무음
        end
    end

    // Routine2 시간대별 주파수 설정
    always @(*) begin
        if (routine2_total_cnt <= TIME_70MS) begin
            freq_routine2 = FREQ_261HZ;
        end else if (routine2_total_cnt <= TIME_140MS) begin
            freq_routine2 = FREQ_329HZ;
        end else if (routine2_total_cnt <= TIME_210MS) begin
            freq_routine2 = FREQ_392HZ;
        end else if (routine2_total_cnt <= TIME_280MS) begin
            freq_routine2 = FREQ_554HZ;
        end else begin
            freq_routine2 = 22'd0;  // 무음
        end
    end
    
    // Routine1 buzzer 출력
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            freq_routine1_cnt <= 0;
            r_buzzer_routine1 <= 0;
        end else begin
            if (playing_routine1 && freq_routine1 != 0) begin
                if (freq_routine1_cnt >= freq_routine1) begin
                    freq_routine1_cnt <= 0;
                    r_buzzer_routine1 <= ~r_buzzer_routine1;
                end else begin
                    freq_routine1_cnt <= freq_routine1_cnt + 1;
                end
            end else begin
                freq_routine1_cnt <= 0;
                r_buzzer_routine1 <= 0;
            end
        end
    end
    
    // Routine2 buzzer 출력
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            freq_routine2_cnt <= 0;
            r_buzzer_routine2 <= 0;
        end else begin
            if (playing_routine2 && freq_routine2 != 0) begin
                if (freq_routine2_cnt >= freq_routine2) begin
                    freq_routine2_cnt <= 0;
                    r_buzzer_routine2 <= ~r_buzzer_routine2;
                end else begin
                    freq_routine2_cnt <= freq_routine2_cnt + 1;
                end
            end else begin
                freq_routine2_cnt <= 0;
                r_buzzer_routine2 <= 0;
            end
        end
    end
    
    assign buzzer = r_buzzer_routine1 | r_buzzer_routine2;
    
endmodule