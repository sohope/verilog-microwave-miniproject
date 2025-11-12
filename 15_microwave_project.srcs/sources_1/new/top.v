`timescale 1ns / 1ps

module top #(
        parameter BTN_DEBOUNCE_LIMIT = 100_000_000/100,  // 10ms (기본값)
        parameter SIG_DEBOUNCE_LIMIT = 100_000_000/500,  // 2ms (기본값)
        parameter FND_BLINK_LIMIT = 50_000_000           // 0.5초 (기본값)
    )(
    input clk,
    input reset,        // btnU
    input btnL,
    input btnR,
    input [7:0] sw,
    output [15:0] led,
    output [3:0] an,
    output [7:0] seg
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
        .NUM_SIGNALS(1),
        .DEBOUNCE_LIMIT(BTN_DEBOUNCE_LIMIT)
    ) u_multi_btn_debouncer(
        .clk(clk),
        .reset(reset),
        .noisy_sig({btnL}),
        .clean_sig(w_clean_btn)
    );

    // s1, s2, key 디바운스 인스턴스 생성 (2ms용)
    multi_debouncer #(
        .NUM_SIGNALS(3),
        .DEBOUNCE_LIMIT(SIG_DEBOUNCE_LIMIT)
    ) u_debouncer (
        .clk(clk),
        .reset(reset),
        .noisy_sig({s1, s2, key}),
        .clean_sig(w_clean_sig)
    );

    btn_command_controller u_btn_command_controller(
        .debounced_btn_sig(w_btn_debounce),
        .clk(clk),
        .reset(reset),
        .sw(sw),
        .led(led),
        .seg_data(w_seg_data),
        .mode(w_mode)
    );

    fnd_controller u_fnd_controller(
        .clk(clk),
        .in_data(w_seg_data),
        .reset(reset),
        .mode(w_mode),
        .an(an),
        .seg(seg)
    );

endmodule
