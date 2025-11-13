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
        input btnR,         // stop
        input btnD,
        input s1,
        input s2,
        input key,
        input sw,         // SW0 스위치
        output [15:0] led,
        output [3:0] an,
        output [7:0] seg,
        output dc_motor_pwm,
        output [1:0] in1_in2,
        output servo_motor_pwm,
        output buzzer_pwm
    );

    // FND 제어용 변수
    wire [13:0] w_seg_data;
    wire [2:0] w_mode;

    // 부저 제어용 변수
    wire w_beep_finish;        // 타이머 종료 부저 트리거 (3회)
    wire w_buzzer_done;        // 부저 3회 완료 신호
    wire w_buzzer_door_open;   // 문 열림 부저 출력
    wire w_buzzer_door_close;  // 문 닫힘 부저 출력
    wire w_buzzer_finish;      // 타이머 종료 부저 출력

    // SW0 엣지 검출용 변수
    reg r_prev_sw = 0;
    wire sw_rising;
    wire sw_falling;

    // 디바운서 결과 저장용 변수
    wire [3:0] w_clean_btn;
	wire [2:0] w_clean_sig;
    wire w_clean_sw;  // SW0 디바운서 출력

    // 로터리 엔코더 관련 변수
	wire [7:0] w_count;

    // DC 모터 및 서보 모터 출력 관련 변수
    wire pwm_out_dc_motor;
    wire duty_cycle_dc_motor;
    wire pwm_out_servo_motor;
    wire duty_cycle_servo_motor;


    // SW0 엣지 검출
    always @(posedge clk, posedge reset) begin
        if (reset)
            r_prev_sw <= 0;
        else
            r_prev_sw <= w_clean_sw;
    end

    assign sw_rising = w_clean_sw && !r_prev_sw;   // SW0 올릴 때 (문 열림)
    assign sw_falling = !w_clean_sw && r_prev_sw;  // SW0 내릴 때 (문 닫힘)

    // btnL 디바운스 인스턴스 생성 (10ms용)
    multi_debouncer #(
        .NUM_SIGNALS(4),
        .DEBOUNCE_LIMIT(BTN_DEBOUNCE_LIMIT)
    ) u_multi_btn_debouncer(
        .clk(clk),
        .reset(reset),
        .noisy_sig({btnU, btnD, btnL, btnR}),
        .clean_sig(w_clean_btn)
    );
    
    // SW0 디바운스 인스턴스 생성 (10ms용)
    debouncer #(
        .DEBOUNCE_LIMIT(BTN_DEBOUNCE_LIMIT)
    ) u_sw_debouncer (
        .clk(clk),
        .reset(reset),
        .noisy_sig(sw),
        .clean_sig(w_clean_sw)
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
        .count(w_count)
    );

    // Controller
    btn_command_controller u_btn_command_controller(
        .clk(clk),
        .reset(reset),
        .btnL(w_clean_btn[1]),   // btnL (2채널 중 상위비트) <-- btnL 추가
        .btnR(w_clean_btn[0]),   // btnR (2채널 중 하위비트) <-- btnR 추가
        .rotary_count(w_count),  // rotary encoder count 입력
        .sw(w_clean_sw),         // SW0 스위치 입력 (디바운스 적용)
        .buzzer_done(w_buzzer_done),  // 부저 3회 완료 신호
        .seg_data(w_seg_data),
        .mode(w_mode),
        .beep_finish(w_beep_finish)   // 타이머 종료 부저 트리거 (3회)
    );

    // DC Motor
    pwm_duty_cycle_control u_dc_motor_pwm_duty_cycle_control (
        .clk(clk),
        .duty_inc(w_clean_btn[3]),
        .duty_dec(w_clean_btn[2]),
        .mode(w_mode),                // 모드 입력 (START_MODE일 때만 PWM 출력)
        .DUTY_CYCLE(duty_cycle_dc_motor),
        .PWM_OUT(dc_motor_pwm),       // 10MHz PWM output signal
        .in1_in2(in1_in2)
    );

    // Servo Motor
    pwm_servo u_pwm_servo_control(
        .clk(clk),   // 100MHz clock input
        .reset(reset),
        .sw(w_clean_sw),  // SW0 스위치 입력 (디바운스 적용)
        .servo_motor_pwm(servo_motor_pwm)       // 10MHz PWM output signal
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
    
    // Buzzer - Door Open (문 열림: 삡 1회)
    buzzer_door_open u_buzzer_door_open(
        .clk(clk),
        .reset(reset),
        .trigger(sw_rising),           // SW0 올릴 때 트리거
        .buzzer(w_buzzer_door_open)    // 문 열림 부저 출력
    );

    // Buzzer - Door Close (문 닫힘: 삡 2회)
    buzzer_door_close u_buzzer_door_close(
        .clk(clk),
        .reset(reset),
        .trigger(sw_falling),          // SW0 내릴 때 트리거
        .buzzer(w_buzzer_door_close)   // 문 닫힘 부저 출력
    );

    // Buzzer - Finish (타이머 종료: 삡 3회)
    buzzer_finish u_buzzer_finish(
        .clk(clk),
        .reset(reset),
        .beep_finish(w_beep_finish),   // 타이머 종료 트리거
        .buzzer(w_buzzer_finish),      // 타이머 종료 부저 출력
        .buzzer_done(w_buzzer_done)    // 3회 완료 신호
    );

    // 세 부저 출력을 OR로 합침
    assign buzzer_pwm = w_buzzer_door_open | w_buzzer_door_close | w_buzzer_finish;

endmodule
