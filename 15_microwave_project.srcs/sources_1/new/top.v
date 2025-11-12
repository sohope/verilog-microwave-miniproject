`timescale 1ns / 1ps

module top(
    input clk,
    input reset,        // btnU
    input [3:0] btn,    // btn[0]: btnL, btn[1]: btnC, btn[2]: btnR, btn[3]: btnD
    input [7:0] sw,
    output [15:0] led,
    output [3:0] an,
    output [7:0] seg
    );

    wire [4:0] w_btn_debounce;
    wire [13:0] w_seg_data;
    wire [2:0] w_mode;

    btn_debouncer u_button_debouncer(
        .clk(clk),
        .reset(reset),
        .btn(btn),
        .debounced_btn(w_btn_debounce)
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
