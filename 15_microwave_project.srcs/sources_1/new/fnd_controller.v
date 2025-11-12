`timescale 1ns / 1ps

module fnd_controller(
    input clk,
    input reset,            // btnU
    input [13:0] in_data,
    input [2:0] mode,
    output [3:0] an,
    output [7:0] seg
    );

    parameter IDLE_MODE = 3'b100;

    wire [1:0] w_sel;
    wire [3:0] w_d1, w_d10, w_d100, w_d1000;
    wire [3:0] w_an_num, w_an_idle;
    wire [7:0] w_seg_num, w_seg_idle;

    // 1ms마다 FND 자릿수 선택
    fnd_digit_select u_fnd_digit_select (
        .clk(clk),
        .reset(reset),
        .sel(w_sel)
    );

    // 이진수 -> BCD 변환
    bin2bcd4digit u_bin2bcd4digit(
        .in_data(in_data),
        .d1(w_d1),
        .d10(w_d10),
        .d100(w_d100),
        .d1000(w_d1000)
    );

    // 숫자 표시 전용 모듈
    fnd_digit_display u_fnd_digit_display(
        .clk(clk),
        .reset(reset),
        .digit_sel(w_sel),
        .d1(w_d1),
        .d10(w_d10),
        .d100(w_d100),
        .d1000(w_d1000),
        .mode(mode),
        .an(w_an_num),
        .seg(w_seg_num)
    );

    // IDLE 애니메이션 전용 모듈
    idle_animation_display u_idle_animation_display(
        .clk(clk),
        .reset(reset),
        .digit_sel(w_sel),
        .an(w_an_idle),
        .seg(w_seg_idle)
    );

    // 모드에 따라 출력 선택
    assign an = (mode == IDLE_MODE) ? w_an_idle : w_an_num;
    assign seg = (mode == IDLE_MODE) ? w_seg_idle : w_seg_num;

endmodule

// 1ms마다 fnd를 display하기 위해서 d 1자리씩 선택
module fnd_digit_select (
    input clk,
    input reset,
    output reg [1:0] sel    // 0, 01, 10, 11: 1ms마다 바뀜
);

    reg [$clog2(100_000)-1:0] r_1ms_counter = 0; // 1ms 카운터

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_1ms_counter <= 0;
            sel <= 0;
        end else begin
            if(r_1ms_counter == 100_000-1) begin
                r_1ms_counter <= 0;
                sel <= sel + 1;
            end else begin
                r_1ms_counter <= r_1ms_counter + 1;
            end
        end
    end
endmodule


// input [13:0] in_data: 14bit, fnd에 최대 9999까지 표현하기 위한 bin size
// 0~9999 천/백/십/일의 자리 숫자 0~9까지 BCD로 4bit 표현
module bin2bcd4digit (
    input [13:0] in_data,
    output [3:0] d1,
    output [3:0] d10,
    output [3:0] d100,
    output [3:0] d1000
);
   assign d1 = in_data % 10;
   assign d10 = (in_data / 10) % 10;
   assign d100 = (in_data / 100) % 10;
   assign d1000 = (in_data / 1000) % 10;
endmodule

// 숫자 표시 전용 모듈 (1ms 잔상 효과 이용)
module fnd_digit_display (
    input clk,
    input reset,
    input [1:0] digit_sel,
    input [3:0] d1,
    input [3:0] d10,
    input [3:0] d100,
    input [3:0] d1000,
    input [2:0] mode,
    output reg [3:0] an,
    output reg [7:0] seg
);

    parameter MAIN_FREQUENCY = 100_000_000;
    parameter MIN_SEC_CLOCK_MODE = 3'b001;
    parameter STOPWATCH_PAUSE_MODE = 3'b010;
    parameter STOPWATCH_START_MODE = 3'b011;

    reg [3:0] bcd_data;

    // d100 dot LED 깜빡임용 카운터 (0.5초 간격, 분초시계 모드용)
    reg [$clog2(MAIN_FREQUENCY/2)-1:0] r_counter_dot = 0;
    reg r_dot_blink = 0;

    // 0.5초마다 dot LED 토글 (분초시계 모드에서만 사용)
    always @(posedge clk, posedge reset) begin
        if(reset) begin
            r_counter_dot <= 0;
            r_dot_blink <= 0;
        end else begin
            if (r_counter_dot == (MAIN_FREQUENCY/2)-1) begin
                r_counter_dot <= 0;
                r_dot_blink <= ~r_dot_blink;
            end else begin
                r_counter_dot <= r_counter_dot + 1;
            end
        end
    end

    // 자릿수 선택에 따라 BCD 데이터 및 an 신호 결정
    always @(digit_sel) begin
        case(digit_sel)
            2'b00: begin bcd_data = d1; an = 4'b1110; end
            2'b01: begin bcd_data = d10; an = 4'b1101; end
            2'b10: begin bcd_data = d100; an = 4'b1011; end
            2'b11: begin bcd_data = d1000; an = 4'b0111; end
            default: begin bcd_data = 4'b0000; an = 4'b1111; end
        endcase
    end

    // BCD -> 7-segment 변환
    always @(bcd_data) begin
        case(bcd_data)
            4'd0: seg = 8'b11000000;
            4'd1: seg = 8'b11111001;
            4'd2: seg = 8'b10100100;
            4'd3: seg = 8'b10110000;
            4'd4: seg = 8'b10011001;
            4'd5: seg = 8'b10010010;
            4'd6: seg = 8'b10000010;
            4'd7: seg = 8'b11111000;
            4'd8: seg = 8'b10000000;
            4'd9: seg = 8'b10010000;
            default: seg = 8'b11111111;
        endcase

        // d100 자리(백의 자리)에 dot LED 적용
        // seg[7]=DP: 0=켜짐, 1=꺼짐
        if (digit_sel == 2'b10) begin
            if (mode == MIN_SEC_CLOCK_MODE) begin
                // 분초시계 모드: 0.5초마다 깜빡임 (분:초 구분용)
                seg[7] = r_dot_blink;
            end else if (mode == STOPWATCH_PAUSE_MODE || mode == STOPWATCH_START_MODE) begin
                // 스톱워치 모드: 항상 켜짐 (초.1/100초 구분용)
                seg[7] = 1'b0;
            end
        end
    end

endmodule

// IDLE 애니메이션 전용 모듈
// 4개 FND 외곽 테두리를 시계방향으로 순환
module idle_animation_display (
    input clk,
    input reset,
    input [1:0] digit_sel, 
    output reg [3:0] an,
    output reg [7:0] seg
);

    parameter MAIN_FREQUENCY = 100_000_000;

    // 100ms마다 애니메이션 단계 변경
    reg [$clog2(MAIN_FREQUENCY/10)-1:0] r_counter_idle = 0;
    reg [3:0] r_idle_anim_step = 0;

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            r_counter_idle <= 0;
            r_idle_anim_step <= 0;
        end else begin
            if (r_counter_idle == (MAIN_FREQUENCY/10)-1) begin
                r_counter_idle <= 0;
                if (r_idle_anim_step == 11) begin
                    r_idle_anim_step <= 0;
                end else begin
                    r_idle_anim_step <= r_idle_anim_step + 1;
                end
            end else begin
                r_counter_idle <= r_counter_idle + 1;
            end
        end
    end

    // digit_sel에 따라 an 신호 생성
    always @(digit_sel) begin
        case(digit_sel)
            2'b00: an = 4'b1110;  // d1
            2'b01: an = 4'b1101;  // d10
            2'b10: an = 4'b1011;  // d100
            2'b11: an = 4'b0111;  // d1000
            default: an = 4'b1111;
        endcase
    end

    // 애니메이션 단계 + digit_sel에 따라 seg 생성
    // 7-segment 실제 매핑: seg[7]=DP, seg[6]=G, seg[5]=F, seg[4]=E, seg[3]=D, seg[2]=C, seg[1]=B, seg[0]=A
    always @(r_idle_anim_step) begin
        case(r_idle_anim_step)
            4'd0: seg = (digit_sel == 2'b11) ? 8'b11111110 : 8'b11111111;   // d1000의 A 켜기, 나머지 자리수는 끄기
            4'd1: seg = (digit_sel == 2'b10) ? 8'b11111110 : 8'b11111111;   // d100의 A 켜기, 나머지 자리수는 끄기
            4'd2: seg = (digit_sel == 2'b01) ? 8'b11111110 : 8'b11111111;   // d10의 A 켜기, 나머지 자리수는 끄기
            4'd3: seg = (digit_sel == 2'b00) ? 8'b11111110 : 8'b11111111;   // d1의 A 켜기, 나머지 자리수는 끄기
            4'd4: seg = (digit_sel == 2'b00) ? 8'b11111101 : 8'b11111111;   // d1의 B 켜기, 나머지 자리수는 끄기
            4'd5: seg = (digit_sel == 2'b00) ? 8'b11111011 : 8'b11111111;   // d1의 C 켜기, 나머지 자리수는 끄기
            4'd6: seg = (digit_sel == 2'b00) ? 8'b11110111 : 8'b11111111;   // d1의 D 켜기, 나머지 자리수는 끄기
            4'd7: seg = (digit_sel == 2'b01) ? 8'b11110111 : 8'b11111111;   // d10의 D 켜기, 나머지 자리수는 끄기
            4'd8: seg = (digit_sel == 2'b10) ? 8'b11110111 : 8'b11111111;   // d100의 D 켜기, 나머지 자리수는 끄기
            4'd9: seg = (digit_sel == 2'b11) ? 8'b11110111 : 8'b11111111;   // d1000의 D 켜기, 나머지 자리수는 끄기
            4'd10: seg = (digit_sel == 2'b11) ? 8'b11101111 : 8'b11111111;  // d1000의 E 켜기, 나머지 자리수는 끄기
            4'd11: seg = (digit_sel == 2'b11) ? 8'b11011111 : 8'b11111111;  // d1000의 F 켜기, 나머지 자리수는 끄기
            default: seg = 8'b11111111;
        endcase
    end

endmodule
