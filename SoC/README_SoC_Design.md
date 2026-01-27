# MiniMIPS32 Lite SoC 设计文档

## 一、系统架构

### 1.1 整体功能
本SoC集成了MiniMIPS32 Lite五级流水线CPU核心、存储子系统和I/O外设接口，构成一个完整的可编程片上系统。系统支持：
- MIPS32指令集的精简子集（17条核心指令）
- 双端口指令存储器访问（支持.text段的全局数据读取）
- 统一编址的数据存储器和I/O外设
- 串口通信、LED、7段数码管、按键和拨码开关等外设

### 1.2 存储映射
| 地址范围 | 功能 | 容量/说明 |
|---------|------|----------|
| 0x8000_0000 ~ 0x8000_FFFF | inst_rom (.text段) | 64KB, 双端口访问 |
| 0x8001_0000 ~ 0x8001_FFFF | data_ram (.data段) | 64KB, 单端口访问 |
| 0xBFD0_03F8 | UART数据寄存器 | 读：接收数据；写：发送数据 |
| 0xBFD0_03FC | UART状态寄存器 | bit0: 发送ready; bit1: 接收有效 |
| 0xBFD1_0000 | LED寄存器 | 32位输出 |
| 0xBFD1_0010 ~ 0xBFD1_0030 | 7段数码管寄存器 | 9个4位寄存器 |
| 0xBFD1_0040 | 按键寄存器 | 8位输入（只读）|
| 0xBFD1_0050 | 拨码开关1寄存器 | 32位输入（只读）|
| 0xBFD1_0054 | 拨码开关2寄存器 | 32位输入（只读）|

## 二、模块划分

### 2.1 处理器核心（MiniMIPS32_Lite）
- **功能**：执行MIPS指令流，维护流水线状态
- **接口**：
  - 取指接口：iaddr(输出), inst(输入)
  - 访存接口：daddr(输出), drdata(输入), dwdata(输出), dwe(输出), dce(输出)
  - 调试接口：debug_wb_pc, debug_wb_rf_wen, debug_wb_rf_wnum, debug_wb_rf_wdata
- **内部结构**：IF/ID/EX/MEM/WB五级流水线，包含数据前递和暂停控制

### 2.2 指令存储器（inst_rom）
- **功能**：存储程序代码和.text段的只读数据（如字符串常量）
- **特性**：
  - **双端口配置**：端口A供取指阶段使用，端口B供访存阶段使用
  - **冲突仲裁**：当访存阶段访问.text段时，端口B优先，端口A返回nop
  - **容量**：16K字（64KB）
- **实现细节**：使用Xilinx Block Memory Generator IP核，配置为True Dual Port ROM

### 2.3 数据存储器（data_ram）
- **功能**：存储程序运行时的.data段和堆栈
- **特性**：
  - 单端口读写
  - 字对齐访问（32位）
  - 容量：16K字（64KB）
- **实现细节**：使用Xilinx Distributed Memory Generator IP核

### 2.4 总线和地址译码模块
- **功能**：解析CPU访存地址，路由到对应的存储器或I/O设备
- **地址译码逻辑**：
  ```systemverilog
  if (addr[31:16] == 0x8000)      -> inst_rom (访存阶段)
  if (addr[31:16] == 0x8001)      -> data_ram
  if (addr[31:16] == 0xBFD0)      -> UART
  if (addr[31:16] == 0xBFD1)      -> 其他I/O设备
  ```
- **数据多路选择**：根据译码结果将读数据从相应源头返回CPU

### 2.5 I/O接口寄存器模块
- **UART接口**：
  - 数据寄存器(0xBFD003F8)：写时触发发送，读时返回接收数据
  - 状态寄存器(0xBFD003FC)：bit0指示发送器ready，bit1指示接收缓冲有效
  - 与async_receiver/transmitter模块交互
  
- **LED接口**：
  - 地址：0xBFD10000
  - 32位可写寄存器，直接驱动LED输出
  
- **7段数码管接口**：
  - 地址：0xBFD10010-0xBFD10030（每4字节一个寄存器）
  - 9个4位寄存器，通过x7seg模块驱动数码管扫描显示
  
- **按键接口**：
  - 地址：0xBFD10040
  - 8位只读寄存器，实时采样按键状态
  
- **拨码开关接口**：
  - 地址：0xBFD10050, 0xBFD10054
  - 两组32位只读寄存器，采样拨码开关状态

## 三、设计特色

### 3.1 双端口指令存储器设计
**背景**：某些程序将只读全局数据（如字符串常量）存放在.text段，需要在运行时通过load指令访问。传统单端口inst_rom只能在取指阶段访问，无法满足此需求。

**解决方案**：
1. 将inst_rom配置为双端口模式
2. 端口A连接取指阶段（IF stage），持续提供指令流
3. 端口B连接访存阶段（MEM stage），用于load .text段数据
4. **冲突处理**：当访存阶段需要访问inst_rom时，取指阶段插入nop，避免流水线错误

**代码实现**：
```systemverilog
assign inst_rom_addr_a = inst_rom_access_mem ? 14'h3FFF : cpu_iaddr[15:2];
assign inst_rom_addr_b = inst_rom_access_mem ? cpu_daddr[15:2] : 14'h0;
assign cpu_inst = inst_rom_access_mem ? 32'h00000000 : inst_rom_data_a;
```

### 3.2 组合逻辑总线设计
- 采用纯组合逻辑实现地址译码和数据路由，零延迟
- 地址高16位作为段选择，低位作为段内偏移
- 读数据通过always_comb实现多路选择器，避免锁存器推断

### 3.3 I/O寄存器与外设解耦
- CPU通过统一的内存映射接口访问所有I/O
- 接口寄存器与物理外设分离，提高可移植性
- UART、LED、数码管等外设逻辑独立封装

### 3.4 流水线友好的访存设计
- 访存操作在MEM阶段完成，与流水线节拍对齐
- 数据前递机制处理load-use冒险
- 双端口inst_rom设计避免取指/访存冲突导致的流水线停顿

## 四、设计过程中的困难与解决

### 4.1 指令存储器双端口访问冲突
**问题**：test程序需要从.text段读取字符串，但单端口inst_rom只能供取指使用，访存阶段无法读取。

**解决方法**：
1. 将inst_rom IP核重新配置为True Dual Port模式
2. 添加访存优先级仲裁逻辑：当MEM stage访问inst_rom时，IF stage获取nop
3. 通过`inst_rom_access_mem`信号控制端口分配和数据选择

**设计权衡**：访存inst_rom会导致流水线插入气泡，但频率较低且程序通常只在初始化时读取.text段数据，对性能影响可接受。

### 4.2 I/O地址空间规划
**问题**：benchtest.S使用0xBFD003F8/FC作为UART地址，需要兼容；同时需要为LED、数码管等外设分配地址。

**解决方法**：
1. 保留0xBFD0_xxxx段给UART（兼容测试代码）
2. 分配0xBFD1_xxxx段给其他I/O设备
3. 使用地址低位细分I/O寄存器：
   - 0xBFD10000: LED
   - 0xBFD10010-30: 数码管
   - 0xBFD10040: 按键
   - 0xBFD10050/54: 拨码开关

### 4.3 UART发送时序控制
**问题**：写UART数据寄存器后需要触发发送，但ext_uart_start信号只能持续一个周期。

**解决方法**：
```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        ext_uart_start <= 1'b0;
    end else if (uart_access && cpu_dwe && cpu_daddr[11:0] == 12'h3F8 && ~ext_uart_busy) begin
        ext_uart_start <= 1'b1;  // 检测到写操作时拉高
    end else begin
        ext_uart_start <= 1'b0;  // 自动清零
    end
end
```

### 4.4 数据存储器字节使能限制
**问题**：Distributed RAM配置不支持字节写使能，SB指令无法实现真正的字节写入。

**解决方法**：
- 在测试程序中避免使用SB指令，或改用SW写入完整字
- 在mem_stage中保留SB的处理逻辑（为将来升级到Block RAM预留）
- 在代码注释中明确标注此限制

## 五、测试程序设计

### 5.1 test1_prime_sieve.S（素数筛选）
**功能复杂度**：
- 实现埃拉托斯特尼筛法算法
- 使用数组存储筛选状态（测试访存）
- 多层嵌套循环（测试分支）
- 除法运算（通过减法循环实现）
- 字符串输出和数字格式化（测试子程序调用）

**外设使用**：
- 串口：输出素数列表和统计信息
- LED：显示素数个数
- 数码管：显示当前处理的数字

**指令覆盖**：算术(add/addu/addiu/subu/slt)、逻辑(ori/andi)、移位(sll)、分支(beq/bne)、访存(lw/sw/lb/sb)、跳转(jal/jr)

### 5.2 test2_matrix_ops.S（矩阵运算）
**功能复杂度**：
- 4x4矩阵初始化和转置
- 二维数组地址计算（测试复杂寻址）
- 对角线元素求和
- 位运算模式测试（xor/and/or/srav）
- 十六进制格式化输出

**外设使用**：
- 按键：等待用户启动程序
- 串口：输出矩阵内容和计算结果
- LED：显示对角线和
- 数码管：显示当前处理的行列位置

**指令覆盖**：完整覆盖所有17条必需指令，包括blez、xor、lui等

## 六、待改进的地方

### 6.1 存储器接口优化
- **当前**：data_ram不支持字节写使能，SB指令功能受限
- **改进方向**：将data_ram从Distributed RAM升级到Block RAM，配置字节写使能端口

### 6.2 总线性能优化
- **当前**：访存inst_rom时强制取指阶段插入nop
- **改进方向**：
  - 添加inst_rom cache，缓存近期访问的.text数据
  - 或使用预取缓冲，在分支/跳转后的空闲周期提前读取.text数据

### 6.3 I/O功能扩展
- **当前**：仅实现基本的轮询式I/O
- **改进方向**：
  - 添加中断控制器，支持UART接收中断
  - 实现DMA控制器，提高批量数据传输效率
  - 添加定时器外设

### 6.4 调试支持增强
- **当前**：只有基本的写回跟踪信号
- **改进方向**：
  - 添加性能计数器（周期数、指令数、cache命中率等）
  - 实现JTAG调试接口
  - 添加断点和单步执行支持

### 6.5 指令集扩展
- **当前**：仅支持17条核心指令
- **改进方向**：
  - 添加乘除法指令（mult/div/mfhi/mflo已部分实现）
  - 支持异常和中断处理（实现CP0）
  - 添加更多分支指令（bgtz/bltzal等）

## 七、使用说明

### 7.1 编译测试程序
```bash
cd /home/m1hu/minimip32-lite/Level1
# 需要配置mips-sde-elf工具链
mips-sde-elf-as -mips32 test1_prime_sieve.S -o test1.o
mips-sde-elf-ld -T script.ld test1.o -o test1.elf
mips-sde-elf-objcopy -O binary test1.elf test1.bin
# 生成.coe文件供Vivado使用
```

### 7.2 Vivado综合与实现
1. 打开SoC/MiniMIPS32_Lite_FullSyS.xpr项目
2. 更新inst_rom和data_ram的.coe初始化文件
3. 运行综合、实现和生成比特流
4. 下载到FPGA板卡

### 7.3 硬件连接
- 连接USB串口，波特率9600, 8N1
- 连接LED、7段数码管和按键模块
- 复位后程序自动运行

## 八、总结

本SoC设计在MiniMIPS32 Lite CPU核心的基础上，成功集成了双端口存储器、统一编址总线和丰富的I/O外设接口。通过创新的双端口inst_rom设计，解决了.text段数据访问的难题；通过清晰的地址空间划分和组合逻辑总线，实现了高效的存储器和I/O访问。两个测试程序充分验证了系统的功能完整性和外设交互能力。

虽然当前版本在字节写使能、中断支持等方面还有改进空间，但已经构建了一个功能完备、结构清晰、易于扩展的片上系统原型。整个设计过程加深了对处理器-存储器-I/O协同工作机制的理解，为后续的系统级优化和功能扩展奠定了坚实基础。
