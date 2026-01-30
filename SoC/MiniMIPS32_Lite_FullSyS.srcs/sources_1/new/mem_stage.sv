`include "defines.v"

module mem_stage (
    // 新增：引入 stall 信号
    input  wire [5:0]                   stall,

    input  wire [`ALUOP_BUS     ]       mem_aluop_i,
    input  wire [`REG_ADDR_BUS  ]       mem_wa_i,
    input  wire                         mem_wreg_i,
    input  wire [`REG_BUS       ]       mem_wd_i,       // 这里实际上是访存地址
    input  wire [`REG_BUS       ]       mem_mem_data_i, // 待写入的数据
    
    input  wire [`WORD_BUS      ]       drdata,         // 原始读入数据
    
    output wire [`REG_ADDR_BUS  ]       mem_wa_o,
    output wire                         mem_wreg_o,
    output wire [`REG_BUS       ]       mem_dreg_o,
    
    output wire [`INST_ADDR_BUS ]       daddr,
    output wire [`WORD_BUS      ]       dwdata,
    output wire                         dwe,
    output wire [3:0]                   dce
    );

    assign daddr = mem_wd_i;

    // =========================================================================
    // 0. 地址判断：是 UART/IO 还是 RAM ?
    // =========================================================================
    // RAM 地址通常是 0x8001xxxx，UART/IO 是 0xBFDxxxxx
    // 只要不是 RAM 段，我们都认为是外设，保持不翻转
    wire is_ram_access = (mem_wd_i[31:16] == 16'h8001);

    // =========================================================================
    // 1. 读逻辑：条件翻转
    // =========================================================================
    // 翻转后的数据 (用于 RAM)
    wire [31:0] drdata_swapped = {drdata[7:0], drdata[15:8], drdata[23:16], drdata[31:24]};
    
    // 如果是 RAM，读进来要翻转(适配小端CPU)；如果是 UART，直接用原始数据(保持低位状态)
    wire [31:0] final_drdata = is_ram_access ? drdata_swapped : drdata;

    wire is_load = (mem_aluop_i == `MINIMIPS32_LW) || (mem_aluop_i == `MINIMIPS32_LB);
    wire is_store = (mem_aluop_i == `MINIMIPS32_SW) || (mem_aluop_i == `MINIMIPS32_SB);
    
    // 写使能控制
    assign dwe = is_store && (stall[4] == `FALSE_V);

    wire [1:0] addr_offset = mem_wd_i[1:0];
    
    // 片选信号
    assign dce = ((mem_aluop_i == `MINIMIPS32_SW) || (mem_aluop_i == `MINIMIPS32_LW)) ? 4'b1111 :
                 ((mem_aluop_i == `MINIMIPS32_SB) || (mem_aluop_i == `MINIMIPS32_LB)) ?
                 (addr_offset == 2'b00 ? 4'b0001 :
                  addr_offset == 2'b01 ? 4'b0010 :
                  addr_offset == 2'b10 ? 4'b0100 : 4'b1000) : 4'b0000;

    // =========================================================================
    // 2. 写逻辑：条件翻转
    // =========================================================================
    
    // SB 指令处理：注意这里 Read-Modify-Write 必须基于 final_drdata
    wire [31:0] sb_new_word;
    wire [31:0] byte_mask = 32'hFF << (addr_offset * 8);
    wire [31:0] byte_value = ({{24{1'b0}}, mem_mem_data_i[7:0]}) << (addr_offset * 8);
    
    assign sb_new_word = (final_drdata & ~byte_mask) | (byte_value & byte_mask);
    
    // 原始写数据 (CPU 视角)
    wire [31:0] wdata_raw = (mem_aluop_i == `MINIMIPS32_SW) ? mem_mem_data_i :
                            (mem_aluop_i == `MINIMIPS32_SB) ? sb_new_word : 32'h0;

    // 翻转后的写数据 (用于 RAM 存储)
    wire [31:0] wdata_swapped = {wdata_raw[7:0], wdata_raw[15:8], wdata_raw[23:16], wdata_raw[31:24]};

    // 如果是 RAM，写入前翻转(匹配读逻辑)；如果是 UART，直接写(保持低位数据)
    assign dwdata = is_ram_access ? wdata_swapped : wdata_raw;
    
    // =========================================================================
    // 3. 读数据选择 (Load 指令)
    // =========================================================================
    wire [31:0] lb_data;
    // 从 final_drdata 中提取字节
    wire [7:0] byte_data = (addr_offset == 2'b00) ? final_drdata[7:0] :
                           (addr_offset == 2'b01) ? final_drdata[15:8] :
                           (addr_offset == 2'b10) ? final_drdata[23:16] : 
                                                    final_drdata[31:24];
    
    assign lb_data = {{24{byte_data[7]}}, byte_data};
    
    wire [31:0] load_data = (mem_aluop_i == `MINIMIPS32_LW) ? final_drdata :
                            (mem_aluop_i == `MINIMIPS32_LB) ? lb_data : 32'h0;
    
    assign mem_wa_o     = mem_wa_i;
    assign mem_wreg_o   = mem_wreg_i;
    assign mem_dreg_o   = is_load ? load_data : mem_wd_i;

endmodule