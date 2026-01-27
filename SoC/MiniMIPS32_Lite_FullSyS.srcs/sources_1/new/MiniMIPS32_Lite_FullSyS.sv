module MiniMIPS32_Lite_FullSyS(
    input  wire         clk,            // 50MHz
    input  wire         locked,         // PLL锁定信号
    
    input  wire         rxd,            // 串口接收
    output wire         txd,            // 串口发送
    
    input  wire [31:0]  sw_1,           // 拨码开关1
    input  wire [31:0]  sw_2,           // 拨码开关2
    output wire [31:0]  led,            // LED
    output wire [3:0]   seg_cs,         // 数码管片选
    output wire [7:0]   seg_data,       // 数码管段选
    input  wire [7:0]   btn,            // 按键
    
    output wire [31:0]  debug_wb_pc,
    output wire         debug_wb_rf_wen,
    output wire [4:0]   debug_wb_rf_wnum,
    output wire [31:0]  debug_wb_rf_wdata
);

    logic rst_n;
    always_ff @(posedge clk or negedge locked) begin
        if(!locked) rst_n <= 1'b0;
        else        rst_n <= 1'b1;
    end

    //======================================================================
    // 信号定义
    //======================================================================
    logic [31:0] cpu_iaddr, cpu_inst, cpu_daddr, cpu_drdata, cpu_dwdata;
    logic        cpu_dwe;
    logic [3:0]  cpu_dce;
    logic        inst_rom_stall;

    logic [13:0] inst_rom_addr;
    logic [31:0] inst_rom_data;
    logic [13:0] data_ram_addr;
    logic [31:0] data_ram_wdata;
    logic [31:0] data_ram_rdata;
    logic        data_ram_we;

    logic inst_rom_access_mem, data_ram_access, uart_access, io_access;
    logic [7:0]  uart_data_reg, uart_status_reg;
    logic [31:0] led_reg, sw1_reg, sw2_reg;
    logic [3:0]  seg_reg[0:8];
    logic [7:0]  btn_reg;

    //======================================================================
    // 智能 Stall 状态机 (保持之前的修复)
    //======================================================================
    reg rom_wait_done;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rom_wait_done <= 1'b0;
        end else begin
            if (inst_rom_access_mem && !rom_wait_done) begin
                rom_wait_done <= 1'b1;
            end else if (rom_wait_done) begin
                rom_wait_done <= 1'b0;
            end
        end
    end

    assign inst_rom_stall = inst_rom_access_mem && !rom_wait_done;
    assign inst_rom_addr = inst_rom_access_mem ? cpu_daddr[15:2] : cpu_iaddr[15:2];
    assign cpu_inst = inst_rom_access_mem ? 32'h00000000 : inst_rom_data;

    inst_rom inst_rom_inst (
        .a  (inst_rom_addr),
        .spo(inst_rom_data)
    );

    //======================================================================
    // 地址译码
    //======================================================================
    always_comb begin
        inst_rom_access_mem = 1'b0;
        data_ram_access = 1'b0;
        uart_access = 1'b0;
        io_access = 1'b0;
        
        if ((cpu_daddr[31:16] == 16'h8000) && (|cpu_dce)) inst_rom_access_mem = 1'b1;
        else if ((cpu_daddr[31:16] == 16'h8001) && (|cpu_dce)) data_ram_access = 1'b1;
        else if ((cpu_daddr[31:16] == 16'hBFD0) && (|cpu_dce)) uart_access = 1'b1;
        else if ((cpu_daddr[31:16] == 16'hBFD1) && (|cpu_dce)) io_access = 1'b1;
    end

    // Data RAM
    assign data_ram_addr = cpu_daddr[15:2];
    assign data_ram_wdata = cpu_dwdata;
    assign data_ram_we = data_ram_access & cpu_dwe;

    logic [13:0] last_write_addr;
    logic [31:0] last_write_data;
    logic        last_write_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            last_write_valid <= 1'b0;
            last_write_addr  <= 14'b0;
            last_write_data  <= 32'b0;
        end else if (data_ram_we) begin
            last_write_valid <= 1'b1;
            last_write_addr  <= data_ram_addr;
            last_write_data  <= data_ram_wdata;
        end
    end

    logic [31:0] data_ram_rdata_raw;
    data_ram data_ram_inst (
        .clk(clk), .a(data_ram_addr), .d(data_ram_wdata), .we(data_ram_we), .spo(data_ram_rdata_raw)
    );
    assign data_ram_rdata = (data_ram_access && !cpu_dwe && last_write_valid && (data_ram_addr == last_write_addr)) ? 
                            last_write_data : data_ram_rdata_raw;

    //======================================================================
    // UART 逻辑 (增加调试)
    //======================================================================
    logic [7:0] ext_uart_rx, ext_uart_tx;
    logic ext_uart_ready, ext_uart_clear, ext_uart_busy, ext_uart_start, ext_uart_avai;

    async_receiver #(.ClkFrequency(50000000),.Baud(9600)) uart_rx (
        .clk(clk), .RxD(rxd), .RxD_data_ready(ext_uart_ready), .RxD_clear(ext_uart_clear), .RxD_data(ext_uart_rx)
    );
    assign ext_uart_clear = ext_uart_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) ext_uart_avai <= 1'b0;
        else if (ext_uart_ready) ext_uart_avai <= 1'b1;
        else if (uart_access && !cpu_dwe && cpu_daddr[11:0] == 12'h3F8) ext_uart_avai <= 1'b0;
    end

    async_transmitter #(.ClkFrequency(50000000),.Baud(9600)) uart_tx (
        .clk(clk), .TxD(txd), .TxD_busy(ext_uart_busy), .TxD_start(ext_uart_start), .TxD_data(ext_uart_tx)
    );

    // 产生发送请求
    logic uart_write_req;
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            uart_write_req <= 1'b0;
        end else begin
            // 只有当写使能有效，且地址匹配数据寄存器(0xBFD003F8)时才置1
            uart_write_req <= uart_access && cpu_dwe && (cpu_daddr[11:0] == 12'h3F8);
        end
    end
    
    // 触发 UART 模块
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) ext_uart_start <= 1'b0;
        else if (uart_write_req && ~ext_uart_busy) ext_uart_start <= 1'b1;
        else ext_uart_start <= 1'b0;
    end
    assign ext_uart_tx = uart_data_reg;

    // 寄存器读写
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            uart_data_reg <= 8'h00; uart_status_reg <= 8'h01;
            led_reg <= 32'h0; btn_reg <= 0; sw1_reg <= 0; sw2_reg <= 0;
            for(int k=0; k<9; k++) seg_reg[k] <= 0;
        end else begin
            // 写 UART Data 寄存器
            if (uart_access && cpu_dwe && (cpu_daddr[11:0] == 12'h3F8)) begin
                uart_data_reg <= cpu_dwdata[7:0];
            end
            else if (ext_uart_ready) begin
                uart_data_reg <= ext_uart_rx;
            end
            
            // 更新 Status 寄存器
            uart_status_reg[0] <= ~ext_uart_busy; // Bit 0: Tx Ready
            uart_status_reg[1] <= ext_uart_avai;  // Bit 1: Rx Ready

            if (io_access && cpu_dwe) begin
                if (cpu_daddr[15:0] == 16'h0000) led_reg <= cpu_dwdata;
                if (cpu_daddr[15:4] == 12'h001)  seg_reg[cpu_daddr[5:2]] <= cpu_dwdata[3:0];
            end
            btn_reg <= btn; sw1_reg <= sw_1; sw2_reg <= sw_2;
        end
    end
    assign led = led_reg;
    x7seg seg_ctrl (.clk(clk), .seg_wdata(seg_reg), .seg_cs(seg_cs), .seg_data(seg_data));

    // Data Mux
    always_comb begin
        cpu_drdata = 32'b0;
        if (inst_rom_access_mem) cpu_drdata = inst_rom_data;
        else if (data_ram_access) cpu_drdata = data_ram_rdata;
        else if (uart_access) begin
            if (cpu_daddr[11:0] == 12'h3F8) cpu_drdata = {24'h0, uart_data_reg};
            else                            cpu_drdata = {24'h0, uart_status_reg};
        end else if (io_access) begin
            case (cpu_daddr[15:0])
                16'h0000: cpu_drdata = led_reg;
                16'h0040: cpu_drdata = {24'h0, btn_reg};
                16'h0050: cpu_drdata = sw1_reg;
                16'h0054: cpu_drdata = sw2_reg;
                default:  cpu_drdata = 32'h0;
            endcase
        end
    end

    MiniMIPS32_Lite cpu_core (
        .cpu_clk_50M(clk), .cpu_rst_n(rst_n),
        .iaddr(cpu_iaddr), .inst(cpu_inst), .inst_rom_stall(inst_rom_stall),
        .daddr(cpu_daddr), .drdata(cpu_drdata), .dwdata(cpu_dwdata), .dwe(cpu_dwe), .dce(cpu_dce),
        .debug_wb_pc(debug_wb_pc), .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum), .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

    //======================================================================
    // SoC 调试日志 (输出到 soc_debug.log)
    //======================================================================
    integer log_file;
    initial begin
        log_file = $fopen("soc_debug.log", "w");
        $fwrite(log_file, "SoC Simulation Started.\n");
    end

    always @(posedge clk) begin
        // 监控 UART 访问
        if (uart_access) begin
            if (cpu_dwe) begin
                // 写操作
                $fwrite(log_file, "[%t] UART WRITE: Addr=0x%h, Data=0x%h ('%c')\n", $time, cpu_daddr, cpu_dwdata[7:0], cpu_dwdata[7:0]);
                if (cpu_daddr[11:0] == 12'h3F8) 
                    $fwrite(log_file, "    -> Triggering UART TX...\n");
            end else begin
                // 读操作
                if (cpu_daddr[11:0] == 12'h3F8)
                    $fwrite(log_file, "[%t] UART READ DATA: Val=0x%h\n", $time, uart_data_reg);
                else if (cpu_daddr[11:0] == 12'h3FC)
                    $fwrite(log_file, "[%t] UART READ STATUS: Val=0x%h (TxBusy=%b RxAvai=%b)\n", $time, uart_status_reg, ext_uart_busy, ext_uart_avai);
            end
            $fflush(log_file);
        end
        
        // 监控 ROM 冲突
        if (inst_rom_stall) begin
             $fwrite(log_file, "[%t] ROM STALL: PC=%h\n", $time, cpu_iaddr);
             $fflush(log_file);
        end
    end

endmodule