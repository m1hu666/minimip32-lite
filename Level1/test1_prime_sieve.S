#include <regdef.h>

/*
 * test1_prime_sieve.S - 埃拉托斯特尼筛法求素数
 * 
 * 功能：
 * 1. 使用筛法求2-100范围内的素数
 * 2. 将结果通过串口输出
 * 3. 使用LED显示素数个数
 * 4. 使用7段数码管显示当前处理的数字
 * 5. 测试所有必需指令：算术、逻辑、移位、分支、访存
 * 
 * I/O地址映射：
 * - UART数据：0xBFD003F8
 * - UART状态：0xBFD003FC
 * - LED：0xBFD10000
 * - 数码管：0xBFD10010-0xBFD10030
 */

    .org 0x0
    .set noreorder
    .set noat
    .text
    .global __start

__start:
    b       init
    nop

/* ========== 数据段（在.text段中）========== */
    .p2align 2
msg_start:
    .asciz "Prime Sieve Start\n"
    .p2align 2
msg_prime:
    .asciz "Prime: "
    .p2align 2
msg_newline:
    .asciz "\n"
    .p2align 2
msg_done:
    .asciz "Done! Count = "
    .p2align 2

/* ========== 主程序初始化 ========== */
    .p2align 2
init:
    # 初始化寄存器
    ori     s0, zero, 0x0           # s0 = 素数计数器
    lui     s1, 0x8001              # s1 = 数据段基址 0x80010000
    ori     s2, zero, 100           # s2 = 上限值 100
    
    # 输出启动消息
    lui     a0, %hi(msg_start)
    addiu   a0, a0, %lo(msg_start)
    jal     print_string
    nop
    
    # 初始化筛数组：标记所有数为未筛除(0)
    ori     t0, zero, 2             # t0 = 起始位置 2
init_array:
    sw      zero, 0(s1)             # sieve[t0] = 0
    addiu   s1, s1, 4               # s1 += 4
    addiu   t0, t0, 1               # t0++
    bne     t0, s2, init_array      # 循环到100
    nop
    
    # 重置数据段基址
    lui     s1, 0x8001
    
/* ========== 埃拉托斯特尼筛法主循环 ========== */
sieve_loop:
    ori     t0, zero, 2             # t0 = 当前数字i，从2开始
    
outer_loop:
    # 在7段数码管上显示当前处理的数字
    lui     t9, 0xBFD1
    ori     t8, zero, 0x10
    addu    t9, t9, t8              # t9 = 0xBFD10010 (数码管0)
    
    # 提取个位和十位
    ori     t7, zero, 10
    # 先计算十位: t0 / 10
    addu    t6, zero, zero          # t6 = 商(十位)
    addu    t5, zero, t0            # t5 = 被除数
div_loop:
    slt     t4, t5, t7              # t5 < 10?
    bne     t4, zero, div_done      # 如果t5 < 10，退出
    nop
    subu    t5, t5, t7              # t5 -= 10
    addiu   t6, t6, 1               # 商++
    b       div_loop
    nop
div_done:
    # t6 = 十位, t5 = 个位
    sw      t5, 0(t9)               # 数码管0显示个位
    sw      t6, 4(t9)               # 数码管1显示十位
    
    # 计算sieve[i]的地址 = s1 + (i-2)*4
    addiu   t1, t0, -2              # t1 = i - 2
    sll     t1, t1, 2               # t1 = (i-2) * 4
    addu    t1, s1, t1              # t1 = &sieve[i]
    lw      t2, 0(t1)               # t2 = sieve[i]
    
    # 如果sieve[i] == 1（已筛除），跳过
    ori     t3, zero, 1
    beq     t2, t3, skip_number
    nop
    
    # sieve[i] == 0，说明i是素数
    addiu   s0, s0, 1               # 素数计数++
    
    # 更新LED显示素数个数
    lui     t8, 0xBFD1
    sw      s0, 0(t8)               # LED = 素数个数
    
    # 输出 "Prime: "
    lui     a0, %hi(msg_prime)
    addiu   a0, a0, %lo(msg_prime)
    jal     print_string
    nop
    
    # 输出素数值
    addu    a0, zero, t0
    jal     print_number
    nop
    
    # 输出换行
    lui     a0, %hi(msg_newline)
    addiu   a0, a0, %lo(msg_newline)
    jal     print_string
    nop
    
    # 筛除i的所有倍数
    addu    t4, t0, t0              # t4 = 2*i (第一个倍数)
mark_multiples:
    slt     t5, t4, s2              # t4 < 100?
    beq     t5, zero, skip_number   # 如果t4 >= 100，退出标记循环
    nop
    
    # 计算sieve[t4]的地址
    addiu   t5, t4, -2              # t5 = t4 - 2
    sll     t5, t5, 2               # t5 = (t4-2) * 4
    addu    t5, s1, t5              # t5 = &sieve[t4]
    ori     t6, zero, 1
    sw      t6, 0(t5)               # sieve[t4] = 1 (标记为合数)
    
    addu    t4, t4, t0              # t4 += i (下一个倍数)
    b       mark_multiples
    nop
    
skip_number:
    addiu   t0, t0, 1               # i++
    slt     t1, t0, s2              # i < 100?
    bne     t1, zero, outer_loop    # 继续外层循环
    nop
    
/* ========== 输出完成消息 ========== */
finish:
    lui     a0, %hi(msg_done)
    addiu   a0, a0, %lo(msg_done)
    jal     print_string
    nop
    
    # 输出素数个数
    addu    a0, zero, s0
    jal     print_number
    nop
    
    # 输出换行
    lui     a0, %hi(msg_newline)
    addiu   a0, a0, %lo(msg_newline)
    jal     print_string
    nop
    
end_loop:
    b       end_loop
    nop

/* ========== 子程序：打印字符串 ========== */
# 输入：a0 = 字符串地址
print_string:
    addu    t0, zero, a0            # t0 = 字符串指针
    lui     t1, 0xBFD0              # t1 = UART基址
    
ps_loop:
    lb      a0, 0(t0)               # 读取字符
    beq     a0, zero, ps_done       # 遇到'\0'结束
    nop
    
ps_wait:
    lb      t2, 0x3FC(t1)           # 读取UART状态
    andi    t2, t2, 0x1             # 检查bit0(发送ready)
    beq     t2, zero, ps_wait       # 等待ready
    nop
    
    sb      a0, 0x3F8(t1)           # 发送字符
    addiu   t0, t0, 1               # 指针++
    b       ps_loop
    nop
    
ps_done:
    jr      ra
    nop

/* ========== 子程序：打印数字（十进制）========== */
# 输入：a0 = 数字值
print_number:
    addu    t0, zero, ra            # 保存返回地址
    addu    t9, zero, a0            # t9 = 原始数字
    lui     s7, 0x8001              # s7 = 临时缓冲区基址
    ori     s6, zero, 0x200         # 偏移量
    addu    s7, s7, s6              # s7 = 0x80010200
    addu    t1, zero, s7            # t1 = 缓冲区指针
    
    # 特殊情况：数字为0
    bne     a0, zero, pn_convert
    nop
    ori     t2, zero, 0x30          # '0'
    sb      t2, 0(t1)
    addiu   t1, t1, 1
    b       pn_print
    nop
    
pn_convert:
    # 转换为ASCII字符（从个位开始）
    ori     t3, zero, 10            # 除数
pn_loop:
    beq     a0, zero, pn_reverse
    nop
    
    # a0 % 10
    addu    t4, zero, zero          # t4 = 商
    addu    t5, zero, a0            # t5 = 被除数
pn_div:
    slt     t6, t5, t3              # t5 < 10?
    bne     t6, zero, pn_div_done
    nop
    subu    t5, t5, t3              # t5 -= 10
    addiu   t4, t4, 1               # 商++
    b       pn_div
    nop
pn_div_done:
    # t4 = 商, t5 = 余数
    ori     t6, zero, 0x30
    addu    t5, t5, t6              # 余数转ASCII
    sb      t5, 0(t1)               # 存入缓冲区
    addiu   t1, t1, 1               # 指针++
    addu    a0, zero, t4            # a0 = 商
    b       pn_loop
    nop
    
pn_reverse:
    # 反转字符串并输出
    sb      zero, 0(t1)             # 字符串结束符
    addiu   t1, t1, -1              # 指向最后一个字符
    lui     t2, 0xBFD0              # UART基址
    
pn_print:
    slt     t3, t1, s7              # t1 < 缓冲区起始?
    bne     t3, zero, pn_done
    nop
    
    lb      a0, 0(t1)               # 读取字符
pn_wait:
    lb      t4, 0x3FC(t2)           # UART状态
    andi    t4, t4, 0x1
    beq     t4, zero, pn_wait
    nop
    
    sb      a0, 0x3F8(t2)           # 发送字符
    addiu   t1, t1, -1              # 指针--
    b       pn_print
    nop
    
pn_done:
    jr      t0                      # 返回
    nop
