`timescale 1ns / 1ps

module pwm_servo(
    input clk, 
    input reset,  
    input sw,
    output reg servo_motor_pwm  
    );

    parameter FREQ_HZ = 100_000_000;
    parameter PWM_FREQ = 50;
    localparam PERIOD_TICK = FREQ_HZ / PWM_FREQ; //20ms 주기설정

    localparam PW_1MS = FREQ_HZ / 1000;
    localparam PW_2MS = FREQ_HZ / 500;

    reg [31:0] period_cnt;
    reg [31:0] pulse_width; 
    reg running;
    reg state;
    reg sw_d;
    wire sw_edge = sw & ~sw_d; //입력 신호(start)의 상승엣지(즉, 0 → 1 변할 때) 감지
    wire sw_fall_edge = ~sw & sw_d; // 입력 신호 하강엣지 인데 일단 보류

    always @(posedge clk, posedge reset) begin
        if (reset)
            sw_d <= 0;
        else
            sw_d <= sw;
    end              //입력 신호 start를 한 클럭 늦춰서 저장함. 리셋이 아닐 때, start의 현재 값을 start_d에 저장 (한 클럭 늦춤)

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            period_cnt <= 0;
            servo_motor_pwm <= 0;
        end else begin
            if(period_cnt < PERIOD_TICK - 1)
                period_cnt <= period_cnt + 1;
            else begin
                period_cnt <= 0; 
            end
            servo_motor_pwm <= (period_cnt < pulse_width) ? 1'b1 : 1'b0;
        end
    end                    //PWM(Pulse Width Modulation, 펄스 폭 변조) 신호를 생성하는 부분 입력된 pulse_width
                          // 값에 따라 출력 신호(pwmout)의 듀티비(duty ratio) 를 조절하는 동작
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            running      <= 0;
            state        <= 0;
            pulse_width  <= PW_1MS;
        end else begin
            case (state)
                0: begin // Down
                    if (sw_edge) begin    // 0→1
                        state       <= 1;
                        running     <= 1;
                        pulse_width <= PW_2MS;
                    end
                end

                1: begin // Up
                    if (sw_fall_edge) begin  // 1→0
                        state       <= 0;
                        running     <= 0;
                        pulse_width <= PW_1MS;
                    end
                end
            endcase
        end
    end
                              //버튼(또는 트리거) 입력이 들어올 때마다 PWM 신호의 상태를 토글
endmodule

