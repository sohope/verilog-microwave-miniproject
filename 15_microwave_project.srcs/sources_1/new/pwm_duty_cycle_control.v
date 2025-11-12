`timescale 1ns / 1ps

//----------------- pwm_duty_cycle_control ---------------------
module pwm_duty_cycle_control (
    input clk,
    input duty_inc,
    input duty_dec,
    output [3:0] DUTY_CYCLE,
    output PWM_OUT,       // 10MHz PWM output signal 
    output PWM_OUT_LED
 ); 

  reg[3:0] r_DUTY_CYCLE=5;     // initial duty cycle is 50%
  reg[3:0] r_counter_PWM=0;    // counter for creating 10Mhz PWM signal

 always @(posedge clk)
 begin
   if (duty_inc==1 && r_DUTY_CYCLE <= 9) 
      r_DUTY_CYCLE <= r_DUTY_CYCLE + 1; // increase duty cycle by 10%
   else if(duty_dec==1 && r_DUTY_CYCLE >= 1) 
      r_DUTY_CYCLE <= r_DUTY_CYCLE - 1; //decrease duty cycle by 10%
 end 

// Create 10MHz PWM signal with variable duty cycle controlled by 2 buttons 
// DC로 10MHz PWM 신호를 보내도록 한다.
// default r_DUTY_CYCLE은 50%로 설정 r_counter_PWM는 10ns(1/100MHz) 마다 10%씩 증가
 always @(posedge clk)
 begin
   r_counter_PWM <= r_counter_PWM + 1;
   if (r_counter_PWM >= 9) 
    r_counter_PWM <= 0;
 end

 assign PWM_OUT = r_counter_PWM < r_DUTY_CYCLE ? 1:0;
 assign PWM_OUT_LED = PWM_OUT;
 assign DUTY_CYCLE = r_DUTY_CYCLE;
endmodule