`timescale 1ns / 1ps

`define DIVISIONS   (100)                       // 10ms 주기의 클럭을 만들기 위한 분주비 (1초에 100MHz, 10ms: 1MHz
`define CYCLES      (1_000_000_000/`DIVISIONS)  // 10ms 주기의 클럭을 만들기 위한 메인 클럭(100MHz) 싸이클의 수(주기=1,000,000cycles/100MHz=10ms))
`define HALF_CYCLES (`CYCLES/2) // 반주기 계산을 위한 클럭 사이클의 수

/**
* 100분주의 클럭 신호 생성
*/
module clock(
    input i_clk,        // 회로 주파수(100MHz)
    input i_reset,      // 비동기 리셋 입력
    output reg o_clk    // always 구문을 통해 생성된 클럭 신호가 reg 변수에 담기게 됨
    );

    reg [$clog2(`CYCLES)-1:0] r_count=0;   // 1,000,000 숫자를 저장할 수 있는 최소 비트 수 계산 (Ceiling of log2)

    always @(posedge i_clk, posedge i_reset) begin  // i_clk 100MHz이므로 10ns마다 트리거(1초에 1억번 트리거)
        if (i_reset) begin  // 비동기 리셋 (0->1 트리거 될 경우)
            r_count <= 0;
            o_clk <= 0;
        end else begin      // 리셋 상황이 아니면 r_count 값을 이용하여 클럭 시그널 생성
            if(r_count == (`HALF_CYCLES)-1) begin   // r_count 값이 499,999만큼 도달하면(500,000번째 트리거되면) 이전 상태 값을 반전(H->L, L->H)
                r_count <= 0;
                o_clk <= ~o_clk;
            end else begin   // r_count 값이 499,999(500,000번째 트리거)에 도달하지 못하면 1증가
                r_count <= r_count + 1;
            end
        end
    end
endmodule
