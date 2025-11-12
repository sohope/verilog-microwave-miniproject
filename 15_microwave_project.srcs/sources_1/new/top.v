`timescale 1ns / 1ps

module top #(
        parameter BTN_DEBOUNCE_LIMIT = 100_000_000/100,  // 10ms (기본값)
        parameter SIG_DEBOUNCE_LIMIT = 100_000_000/500,  // 2ms (기본값)
        parameter FND_BLINK_LIMIT = 50_000_000           // 0.5초 (기본값)
    )(
    input clk,
    input reset,        // btnU
    input btnU,
    input btnL,         // start/pause
    input btnR,         // Cancel
    input btnD,
    input [7:0] sw,
    input s1,
    input s2,
    input key,
    output [15:0] led,
    output [3:0] an,
    output [7:0] seg,
    output dc_motor_pwm,
    output servo_motor_pwm,
    output buzzer_pwm
    );

    wire [4:0] w_btn_debounce;
    wire [13:0] w_seg_data;
    wire [2:0] w_mode;

    wire [1:0] w_clean_btn;
	wire [2:0] w_clean_sig;
	wire [7:0] w_count;
	wire [1:0] w_direction;

    // btnL 디바운스 인스턴스 생성 (10ms용)
    multi_debouncer #(
        .NUM_SIGNALS(2),
        .DEBOUNCE_LIMIT(BTN_DEBOUNCE_LIMIT)
    ) u_multi_btn_debouncer(
        .clk(clk),
        .reset(reset),
        .noisy_sig({btnL, btnR}),
        .clean_sig(w_clean_btn)
    );

    // s1, s2, key 디바운스 인스턴스 생성 (2ms용)
    multi_debouncer #(
        .NUM_SIGNALS(3),
        .DEBOUNCE_LIMIT(SIG_DEBOUNCE_LIMIT)
    ) u_multi_sig_debouncer (
        .clk(clk),
        .reset(reset),
        .noisy_sig({s1, s2, key}),
        .clean_sig(w_clean_sig)
    );

    // rotary encoder 모듈 인스턴스화
    rotary u_rotary(
        .clk(clk),
        .reset(reset),
        .clean_s1(w_clean_sig[2]),
        .clean_s2(w_clean_sig[1]),
        .clean_key(w_clean_sig[0]),
        .led(led),
        .count(w_count),
        .direction(w_direction)
    );

    // Controller 
    btn_command_controller u_btn_command_controller(
        .clk(clk),
        .reset(reset),
        .btnL(w_clean_btn[1]),   // btnL (2채널 중 상위비트) <-- btnL 추가 
        .btnR(w_clean_btn[0]),   // btnR (2채널 중 하위비트) <-- btnR 추가 
        .sw(sw),
        .led(led),
        .seg_data(w_seg_data),
        .mode(w_mode)
    );

    // DC Motor
    pwm_duty_cycle_control u_dc_motor_pwm_duty_cycle_control (
        .clk(clk),
        .duty_inc(w_debounced_inc_btn),
        .duty_dec(w_debounced_dec_btn),
        .DUTY_CYCLE(w_DUTY_CYCLE),
        .PWM_OUT(PWM_OUT),       // 10MHz PWM output signal 
        .PWM_OUT_LED(PWM_OUT_LED)
    );

    // Servo Motor
    pwm_duty_cycle_control u_servo_motor_pwm_duty_cycle_control (
        .clk(clk),
        .duty_inc(w_debounced_inc_btn),
        .duty_dec(w_debounced_dec_btn),
        .DUTY_CYCLE(w_DUTY_CYCLE),
        .PWM_OUT(PWM_OUT),       // 10MHz PWM output signal 
        .PWM_OUT_LED(PWM_OUT_LED)
    );

    // FND
    fnd_controller u_fnd_controller(
        .clk(clk),
        .in_data(w_seg_data),
        .reset(reset),
        .mode(w_mode),
        .an(an),
        .seg(seg)
    );
    
    // Buzzer
    power_on_melody u_power_on_melody(
        .clk(clk),
        .reset(reset),
        .btnL(w_btnL),     
        .btnR(w_btnR),     
        .buzzer(buzzer)
    );

endmodule
