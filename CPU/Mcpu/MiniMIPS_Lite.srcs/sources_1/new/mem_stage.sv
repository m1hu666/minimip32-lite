`include "defines.v"

module mem_stage (
    input  wire [`ALUOP_BUS     ]       mem_aluop_i,
    input  wire [`REG_ADDR_BUS  ]       mem_wa_i,
    input  wire                         mem_wreg_i,
    input  wire [`REG_BUS       ]       mem_wd_i,
    input  wire [`REG_BUS       ]       mem_mem_data_i,
    input  wire [`INST_ADDR_BUS]        mem_debug_wb_pc,
    
    input  wire [`WORD_BUS      ]       drdata,
    
    output wire [`REG_ADDR_BUS  ]       mem_wa_o,
    output wire                         mem_wreg_o,
    output wire [`REG_BUS       ]       mem_dreg_o,
    
    output wire [`INST_ADDR_BUS ]       daddr,
    output wire [`WORD_BUS      ]       dwdata,
    output wire                         dwe,
    output wire [3:0]                   dce,  // 关键修改：用于指示访存有效性
    
    output wire [`INST_ADDR_BUS] 	    debug_wb_pc
    );

    assign daddr = mem_wd_i;
    
    wire is_load = (mem_aluop_i == `MINIMIPS32_LW) || (mem_aluop_i == `MINIMIPS32_LB);
    wire is_store = (mem_aluop_i == `MINIMIPS32_SW) || (mem_aluop_i == `MINIMIPS32_SB);
    
    assign dwe = is_store;

    // 关键修改：不仅 Store 输出 dce，Load 也输出 dce。
    // 这样 SoC 就可以通过检测 |dce 是否为 0 来判断是否真正需要访问内存。
    wire [1:0] addr_offset = mem_wd_i[1:0];
    
    assign dce = ((mem_aluop_i == `MINIMIPS32_SW) || (mem_aluop_i == `MINIMIPS32_LW)) ? 4'b1111 :
                 ((mem_aluop_i == `MINIMIPS32_SB) || (mem_aluop_i == `MINIMIPS32_LB)) ? 
                 (addr_offset == 2'b00 ? 4'b0001 :
                  addr_offset == 2'b01 ? 4'b0010 :
                  addr_offset == 2'b10 ? 4'b0100 : 4'b1000) : 4'b0000;

    // 写数据逻辑
    wire [31:0] sb_new_word;
    wire [31:0] byte_mask = 32'hFF << (addr_offset * 8);
    wire [31:0] byte_value = ({{24{1'b0}}, mem_mem_data_i[7:0]}) << (addr_offset * 8);
    assign sb_new_word = (drdata & ~byte_mask) | (byte_value & byte_mask);

    assign dwdata = (mem_aluop_i == `MINIMIPS32_SW) ? mem_mem_data_i :
                    (mem_aluop_i == `MINIMIPS32_SB) ? sb_new_word : 32'h0;
    
    // 读数据逻辑
    wire [31:0] lb_data;
    wire [7:0] byte_data = (addr_offset == 2'b00) ? drdata[7:0] :
                           (addr_offset == 2'b01) ? drdata[15:8] :
                           (addr_offset == 2'b10) ? drdata[23:16] : drdata[31:24];
    
    assign lb_data = {{24{byte_data[7]}}, byte_data};
    
    wire [31:0] load_data = (mem_aluop_i == `MINIMIPS32_LW) ? drdata :
                            (mem_aluop_i == `MINIMIPS32_LB) ? lb_data : 32'h0;
    
    assign mem_wa_o     = mem_wa_i;
    assign mem_wreg_o   = mem_wreg_i;
    // 非 Load 指令直接传递 EXE 计算结果 (例如 LUI 的立即数)
    assign mem_dreg_o   = is_load ? load_data : mem_wd_i;
    
    assign debug_wb_pc = mem_debug_wb_pc;

endmodule