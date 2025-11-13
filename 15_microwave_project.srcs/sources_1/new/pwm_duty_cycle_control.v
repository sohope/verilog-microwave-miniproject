`timescale 1ns / 1ps

//----------------- pwm_duty_cycle_control ---------------------
module pwm_duty_cycle_control (
      input clk,
      input duty_inc,
      input duty_dec,
      input [2:0] mode,     // 모드 입력 (START_MODE일 때만 PWM 출력)
      output [3:0] DUTY_CYCLE,
      output PWM_OUT,       // 10MHz PWM output signal
      output [1:0] in1_in2
      // output PWM_OUT_LED
   ); 

   reg[3:0] r_DUTY_CYCLE=6;     // initial duty cycle is 60%
   reg[3:0] r_counter_PWM=0;    // counter for creating 10Mhz PWM signal

   reg prev_duty_inc_state = 0;
   reg prev_duty_dec_state = 0;

   always @(posedge clk) begin
      if (duty_inc==1 && !prev_duty_inc_state && r_DUTY_CYCLE <= 9) 
         r_DUTY_CYCLE <= r_DUTY_CYCLE + 1; // increase duty cycle by 10%
      else if(duty_dec==1 && !prev_duty_dec_state && r_DUTY_CYCLE >= 1) 
         r_DUTY_CYCLE <= r_DUTY_CYCLE - 1; //decrease duty cycle by 10%
      prev_duty_inc_state <= duty_inc;
      prev_duty_dec_state <= duty_dec;
   end

   // Create 10MHz PWM signal with variable duty cycle controlled by 2 buttons 
   // DC로 10MHz PWM 신호를 보내도록 한다.
   // default r_DUTY_CYCLE은 50%로 설정 r_counter_PWM는 10ns(1/100MHz) 마다 10%씩 증가
   always @(posedge clk) begin
      r_counter_PWM <= r_counter_PWM + 1;
      if (r_counter_PWM >= 9)
         r_counter_PWM <= 0;
   end

   // START_MODE(3'b010)일 때만 PWM 출력
   parameter START_MODE = 3'b010;
   assign PWM_OUT = (mode == START_MODE) ? (r_counter_PWM < r_DUTY_CYCLE ? 1:0) : 1'b0;
   assign DUTY_CYCLE = r_DUTY_CYCLE;
   assign in1_in2 = 2'b10;

endmodule