`timescale 1ns / 1ps

// SoC 级 benchtest 仿真 testbench
// 作用：在仿真中跑 inst_rom / data_ram 中的 benchtest.S
// - 自动产生 50MHz 时钟和 locked 复位
// - 等待一段时间后，通过 UART RX 发送字符 'T'
// - 观察 TXD 波形中是否依次出现 "Fib Finish." 和 "All PASS!"

module MiniMIPS32_Lite_FullSyS_tb;

    // 基于 CPU tb 的简洁风格，同时保留 SoC 专用端口与 UART 监控

    // 时钟与复位
    reg clk = 1'b0;            // 50MHz
    reg locked = 1'b0;        // active-high reset/lock
    always #10 clk = ~clk;    // 20ns 周期 -> 50MHz

    // UART 外部引脚
    reg rxd = 1'b1;           // UART RX (idle high)
    wire txd;

    // 其他外设引脚（可以由测试驱动或保持默认）
    reg [31:0] sw_1 = 32'h0;
    reg [31:0] sw_2 = 32'h0;
    reg [7:0]  btn  = 8'h0;
    wire [31:0] led;
    wire [3:0]  seg_cs;
    wire [7:0]  seg_data;

    // SoC DUT（保持端口名与模块一致）
    MiniMIPS32_Lite_FullSyS dut (
        .clk    (clk),
        .locked (locked),
        .rxd    (rxd),
        .txd    (txd),
        .sw_1   (sw_1),
        .sw_2   (sw_2),
        .led    (led),
        .seg_cs (seg_cs),
        .seg_data(seg_data),
        .btn    (btn)
    );

    // debug hooks 从 DUT 导出（SoC 顶层已声明这些信号）
    wire [31:0] debug_wb_pc;
    wire        debug_wb_rf_wen;
    wire [4:0]  debug_wb_rf_wnum;
    wire [31:0] debug_wb_rf_wdata;

    assign debug_wb_pc       = dut.debug_wb_pc;
    assign debug_wb_rf_wen   = dut.debug_wb_rf_wen;
    assign debug_wb_rf_wnum  = dut.debug_wb_rf_wnum;
    assign debug_wb_rf_wdata = dut.debug_wb_rf_wdata;

    // 复位流程
    initial begin
        locked = 1'b0;
        #200;           // 200ns reset
        locked = 1'b1;
    end

    // UART timing parameters（仿真模式）
    localparam integer CLK_FREQ   = 50_000_000;
    localparam integer UART_BAUD  = 9_600;
    localparam integer BIT_CYCLES = CLK_FREQ / UART_BAUD;

    task automatic send_uart_byte(input [7:0] data);
        integer i;
        begin
            rxd = 1'b1; // idle
            repeat (BIT_CYCLES) @(posedge clk);
            rxd = 1'b0; // start
            repeat (BIT_CYCLES) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                rxd = data[i];
                repeat (BIT_CYCLES) @(posedge clk);
            end
            rxd = 1'b1; // stop
            repeat (BIT_CYCLES) @(posedge clk);
        end
    endtask

    // 主激励流程：等待复位结束，延时，然后发送 'T'，观察一段时间后结束
    initial begin
        @(posedge locked);
        // 等待 5 ms
        repeat (CLK_FREQ * 5 / 1_000) @(posedge clk);
        send_uart_byte(8'h54); // 'T'
        // 再等待 15 ms 观察输出
        repeat (CLK_FREQ * 15 / 1_000) @(posedge clk);
        $finish;
    end

    // UART 接收监控：将 DUT 的 txd 解码为字符并写入文件
    integer uart_log;
    initial uart_log = $fopen("uart_console.txt", "w");

    initial begin
        integer i;
        reg [7:0] rx_byte;
        forever begin
            @(negedge txd); // start
            @(posedge clk);
            rx_byte = 8'h00;
            for (i = 0; i < 8; i = i + 1) begin
                @(posedge clk);
                rx_byte[i] = txd;
            end
            @(posedge clk);
            $fwrite(uart_log, "%c", rx_byte);
            $fflush(uart_log);
            $display("[%t] UART RX: 0x%h ('%c')", $time, rx_byte, rx_byte);
        end
    end

    // debug: 打印所有写回事件（与 CPU tb 风格一致）
    always @(posedge clk) begin
        if (debug_wb_rf_wen && debug_wb_rf_wnum != 5'd0) begin
            $display("--------------------------------------------------------------");
            $display("[%t]ns", $time/1000);
            $display("reference: PC = 0x%8h, wb_rf_wnum = 0x%2h, wb_rf_wdata = 0x%8h", debug_wb_pc, debug_wb_rf_wnum, debug_wb_rf_wdata);
            $display("--------------------------------------------------------------");
        end
    end

 endmodule
