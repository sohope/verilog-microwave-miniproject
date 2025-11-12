`timescale 1ns / 1ps

module multi_debouncer #(
        parameter NUM_SIGNALS = 5,  // 버튼 개수를 파라미터로 설정
        parameter DEBOUNCE_LIMIT = 100_000_000/100  // 10ms 주기 (기본값)
    )(
        input clk,
        input reset,
        input [NUM_SIGNALS-1:0] noisy_sig,
        output [NUM_SIGNALS-1:0] clean_sig
    );
    
    // generate 블록을 사용하여 NUM_SIGNALS 개수만큼 인스턴스 생성
    genvar i;
    generate
        for (i = 0; i < NUM_SIGNALS; i = i + 1) begin : sig_deb_gen
            debouncer #(
                .DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)
            ) u_debouncer (
                .clk(clk),
                .reset(reset),
                .noisy_sig(noisy_sig[i]),
                .clean_sig(clean_sig[i])
            );
        end
    endgenerate
endmodule

module debouncer #(
        parameter DEBOUNCE_LIMIT = 100_000_000/100  // 10ms 주기 클럭 사이클 수
    )(
        input clk,
        input reset,
        input noisy_sig,
        output reg clean_sig
    );

    reg [$clog2(DEBOUNCE_LIMIT)-1:0] counter = 0;
    reg prev_sig_state = 0;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter <= 0;
            prev_sig_state <= 0;
            clean_sig <= 0;
        end else begin
            if(noisy_sig == prev_sig_state) begin  // 바운싱 중이면
                counter <= 0;   // 카운터 0으로 초기화
            end else begin
                if (counter >= DEBOUNCE_LIMIT) begin    // 안정된지 10ms 지났으면
                    prev_sig_state <= noisy_sig;    // 현재 상태 저장
                    clean_sig <= noisy_sig;
                    counter <= 0;
                end else begin  // 안정된지 10ms가 지나지 않았으면 카운터 증가
                    counter <= counter + 1;
                end
            end
        end
    end
endmodule