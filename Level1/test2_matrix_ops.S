#include <regdef.h>

/*
 * test2_matrix_ops.S - 矩阵转置和运算测试
 * 
 * 功能：
 * 1. 创建4x4矩阵并初始化
 * 2. 计算矩阵转置
 * 3. 计算对角线元素之和
 * 4. 使用位运算检查特殊模式
 * 5. 通过串口输出结果
 * 6. 使用LED显示计算结果
 * 7. 使用按键控制程序执行
 * 
 * 测试指令：
 * - 算术：add, addu, addiu, subu, slt
 * - 逻辑：and, andi, or, ori, xor, lui
 * - 移位：sll, srav
 * - 分支：beq, bne, blez
 * - 访存：lw, sw, lb, sb
 * - 跳转：jal, jr
 * 
 * I/O地址映射：
 * - UART数据：0xBFD003F8
 * - UART状态：0xBFD003FC
 * - LED：0xBFD10000
 * - 数码管：0xBFD10010-0xBFD10030
 * - 按键：0xBFD10040
 */

    .org 0x0
    .set noreorder
    .set noat
    .text
    .global __start

__start:
    b       init
    nop

/* ========== 数据段 ========== */
    .p2align 2
msg_title:
    .asciz "Matrix Operations Test\n"
    .p2align 2
msg_original:
    .asciz "Original Matrix:\n"
    .p2align 2
msg_transposed:
    .asciz "\nTransposed Matrix:\n"
    .p2align 2
msg_diagonal_sum:
    .asciz "\nDiagonal Sum = "
    .p2align 2
msg_pattern:
    .asciz "\nBit Pattern Test = "
    .p2align 2
msg_done:
    .asciz "\nTest Complete!\n"
    .p2align 2
msg_press_btn:
    .asciz "Press Button to Start...\n"
    .p2align 2

/* ========== 主程序初始化 ========== */
    .p2align 2
init:
    # 输出标题
    lui     a0, %hi(msg_title)
    addiu   a0, a0, %lo(msg_title)
    jal     print_string
    nop
    
    # 等待按键
    lui     a0, %hi(msg_press_btn)
    addiu   a0, a0, %lo(msg_press_btn)
    jal     print_string
    nop
    
wait_button:
    lui     t0, 0xBFD1
    lw      t1, 0x40(t0)            # 读取按键状态
    andi    t1, t1, 0xFF
    beq     t1, zero, wait_button   # 等待任意按键按下
    nop
    
    # 初始化寄存器
    lui     s0, 0x8001              # s0 = 矩阵A基址 0x80010000
    lui     s1, 0x8001              # s1 = 矩阵B基址（转置后）
    ori     s1, s1, 0x100           # s1 = 0x80010100
    
    # 初始化4x4矩阵A (使用特定值便于验证)
    # A = [[1,2,3,4], [5,6,7,8], [9,10,11,12], [13,14,15,16]]
    ori     t0, zero, 1
    ori     t9, zero, 16            # 循环计数
    addu    t1, zero, s0            # 当前地址
    
init_matrix:
    sw      t0, 0(t1)               # 存储元素
    addiu   t0, t0, 1               # 值++
    addiu   t1, t1, 4               # 地址+=4
    addiu   t9, t9, -1              # 计数--
    bne     t9, zero, init_matrix
    nop
    
/* ========== 输出原始矩阵 ========== */
    lui     a0, %hi(msg_original)
    addiu   a0, a0, %lo(msg_original)
    jal     print_string
    nop
    
    addu    a0, zero, s0            # 矩阵地址
    ori     a1, zero, 4             # 4x4矩阵
    jal     print_matrix
    nop
    
/* ========== 矩阵转置 ========== */
    # B[j][i] = A[i][j]
    ori     t0, zero, 0             # i = 0
transpose_row:
    ori     t1, zero, 0             # j = 0
transpose_col:
    # 计算A[i][j]的地址 = s0 + (i*4 + j)*4
    sll     t2, t0, 2               # t2 = i*4
    addu    t2, t2, t1              # t2 = i*4 + j
    sll     t2, t2, 2               # t2 = (i*4+j)*4
    addu    t2, s0, t2              # t2 = &A[i][j]
    lw      t3, 0(t2)               # t3 = A[i][j]
    
    # 计算B[j][i]的地址 = s1 + (j*4 + i)*4
    sll     t4, t1, 2               # t4 = j*4
    addu    t4, t4, t0              # t4 = j*4 + i
    sll     t4, t4, 2               # t4 = (j*4+i)*4
    addu    t4, s1, t4              # t4 = &B[j][i]
    sw      t3, 0(t4)               # B[j][i] = A[i][j]
    
    # 在数码管上显示当前进度
    lui     t9, 0xBFD1
    sw      t0, 0x10(t9)            # 数码管0显示行
    sw      t1, 0x14(t9)            # 数码管1显示列
    
    addiu   t1, t1, 1               # j++
    ori     t5, zero, 4
    bne     t1, t5, transpose_col   # j < 4
    nop
    
    addiu   t0, t0, 1               # i++
    ori     t5, zero, 4
    bne     t0, t5, transpose_row   # i < 4
    nop
    
/* ========== 输出转置矩阵 ========== */
    lui     a0, %hi(msg_transposed)
    addiu   a0, a0, %lo(msg_transposed)
    jal     print_string
    nop
    
    addu    a0, zero, s1            # 转置矩阵地址
    ori     a1, zero, 4             # 4x4
    jal     print_matrix
    nop
    
/* ========== 计算对角线元素之和 ========== */
    ori     t0, zero, 0             # 和
    ori     t1, zero, 0             # i = 0
    ori     t7, zero, 4
    
diagonal_sum:
    # A[i][i]的地址 = s0 + (i*4 + i)*4 = s0 + i*5*4
    sll     t2, t1, 2               # t2 = i*4
    addu    t2, t2, t1              # t2 = i*5
    sll     t2, t2, 2               # t2 = i*5*4
    addu    t2, s0, t2              # t2 = &A[i][i]
    lw      t3, 0(t2)               # t3 = A[i][i]
    addu    t0, t0, t3              # 累加
    
    addiu   t1, t1, 1               # i++
    bne     t1, t7, diagonal_sum    # i < 4
    nop
    
    # 显示在LED上
    lui     t8, 0xBFD1
    sw      t0, 0(t8)               # LED = 对角线和
    
    # 输出结果
    lui     a0, %hi(msg_diagonal_sum)
    addiu   a0, a0, %lo(msg_diagonal_sum)
    jal     print_string
    nop
    
    addu    a0, zero, t0
    jal     print_number
    nop
    
/* ========== 位运算模式测试 ========== */
    # 测试XOR、AND、OR、移位等操作
    ori     t0, zero, 0xAA          # 模式1: 10101010
    ori     t1, zero, 0x55          # 模式2: 01010101
    
    xor     t2, t0, t1              # t2 = 0xFF (异或)
    and     t3, t0, t1              # t3 = 0x00 (与)
    or      t4, t0, t1              # t4 = 0xFF (或)
    
    # 移位测试
    sll     t5, t0, 8               # 左移8位
    ori     t6, zero, 8
    srav    t7, t5, t6              # 算术右移8位(应恢复)
    
    # 计算综合结果 = (t2 + t4) << 4
    addu    t8, t2, t4              # t8 = 0x1FE
    sll     t9, t8, 4               # t9 = 0x1FE0
    
    # 输出位模式测试结果
    lui     a0, %hi(msg_pattern)
    addiu   a0, a0, %lo(msg_pattern)
    jal     print_string
    nop
    
    addu    a0, zero, t9
    jal     print_hex               # 以十六进制输出
    nop
    
/* ========== 完成 ========== */
finish:
    lui     a0, %hi(msg_done)
    addiu   a0, a0, %lo(msg_done)
    jal     print_string
    nop
    
end_loop:
    b       end_loop
    nop

/* ========== 子程序：打印字符串 ========== */
print_string:
    addu    t0, zero, a0
    lui     t1, 0xBFD0
ps_loop:
    lb      a0, 0(t0)
    beq     a0, zero, ps_done
    nop
ps_wait:
    lb      t2, 0x3FC(t1)
    andi    t2, t2, 0x1
    beq     t2, zero, ps_wait
    nop
    sb      a0, 0x3F8(t1)
    addiu   t0, t0, 1
    b       ps_loop
    nop
ps_done:
    jr      ra
    nop

/* ========== 子程序：打印矩阵 ========== */
# 输入：a0 = 矩阵基址, a1 = 维度
print_matrix:
    addu    s2, zero, ra            # 保存返回地址
    addu    s3, zero, a0            # 矩阵地址
    addu    s4, zero, a1            # 维度
    ori     s5, zero, 0             # 行计数i
    
pm_row:
    ori     s6, zero, 0             # 列计数j
pm_col:
    # 计算地址 = base + (i*dim + j)*4
    # t0 = i * dim (通过循环实现)
    addu    t0, zero, zero
    addu    t1, zero, s5            # t1 = i
    beq     t1, zero, pm_mult_done
    nop
pm_mult_loop:
    addu    t0, t0, s4              # t0 += dim
    addiu   t1, t1, -1              # i--
    bne     t1, zero, pm_mult_loop
    nop
pm_mult_done:
    addu    t0, t0, s6              # t0 = i*dim + j
    sll     t0, t0, 2               # t0 *= 4
    addu    t0, s3, t0              # t0 = &matrix[i][j]
    lw      a0, 0(t0)               # 读取元素
    
    jal     print_number
    nop
    
    # 打印空格
    ori     a0, zero, 0x20          # ' '
    lui     t1, 0xBFD0
pm_sp_wait:
    lb      t2, 0x3FC(t1)
    andi    t2, t2, 0x1
    beq     t2, zero, pm_sp_wait
    nop
    sb      a0, 0x3F8(t1)
    
    addiu   s6, s6, 1               # j++
    bne     s6, s4, pm_col          # j < dim
    nop
    
    # 打印换行
    ori     a0, zero, 0x0A          # '\n'
pm_nl_wait:
    lb      t2, 0x3FC(t1)
    andi    t2, t2, 0x1
    beq     t2, zero, pm_nl_wait
    nop
    sb      a0, 0x3F8(t1)
    
    addiu   s5, s5, 1               # i++
    bne     s5, s4, pm_row          # i < dim
    nop
    
    jr      s2                      # 返回
    nop

/* ========== 子程序：打印十进制数字 ========== */
print_number:
    addu    t0, zero, ra
    addu    t9, zero, a0
    lui     s7, 0x8001
    ori     s6, zero, 0x200
    addu    s7, s7, s6
    addu    t1, zero, s7
    
    bne     a0, zero, pn_convert
    nop
    ori     t2, zero, 0x30
    sb      t2, 0(t1)
    addiu   t1, t1, 1
    b       pn_print
    nop
    
pn_convert:
    ori     t3, zero, 10
pn_loop:
    beq     a0, zero, pn_reverse
    nop
    addu    t4, zero, zero
    addu    t5, zero, a0
pn_div:
    slt     t6, t5, t3
    bne     t6, zero, pn_div_done
    nop
    subu    t5, t5, t3
    addiu   t4, t4, 1
    b       pn_div
    nop
pn_div_done:
    ori     t6, zero, 0x30
    addu    t5, t5, t6
    sb      t5, 0(t1)
    addiu   t1, t1, 1
    addu    a0, zero, t4
    b       pn_loop
    nop
    
pn_reverse:
    sb      zero, 0(t1)
    addiu   t1, t1, -1
    lui     t2, 0xBFD0
pn_print:
    slt     t3, t1, s7
    bne     t3, zero, pn_done
    nop
    lb      a0, 0(t1)
pn_wait:
    lb      t4, 0x3FC(t2)
    andi    t4, t4, 0x1
    beq     t4, zero, pn_wait
    nop
    sb      a0, 0x3F8(t2)
    addiu   t1, t1, -1
    b       pn_print
    nop
pn_done:
    jr      t0
    nop

/* ========== 子程序：打印十六进制数字 ========== */
print_hex:
    addu    t0, zero, ra
    lui     t1, 0xBFD0
    
    # 输出"0x"前缀
    ori     a1, zero, 0x30          # '0'
ph_wait0:
    lb      t2, 0x3FC(t1)
    andi    t2, t2, 0x1
    beq     t2, zero, ph_wait0
    nop
    sb      a1, 0x3F8(t1)
    
    ori     a1, zero, 0x78          # 'x'
ph_wait1:
    lb      t2, 0x3FC(t1)
    andi    t2, t2, 0x1
    beq     t2, zero, ph_wait1
    nop
    sb      a1, 0x3F8(t1)
    
    # 输出8个十六进制数字
    ori     t3, zero, 8             # 计数器
    ori     t4, zero, 28            # 移位量(从高位开始)
    
ph_loop:
    srav    t5, a0, t4              # 右移取高4位
    andi    t5, t5, 0xF             # 只保留低4位
    ori     t6, zero, 10
    slt     t7, t5, t6              # < 10?
    bne     t7, zero, ph_digit
    nop
    # >= 10, 输出A-F
    addiu   t5, t5, -10
    ori     t6, zero, 0x41          # 'A'
    addu    a1, t5, t6
    b       ph_output
    nop
ph_digit:
    ori     t6, zero, 0x30          # '0'
    addu    a1, t5, t6
ph_output:
ph_wait2:
    lb      t2, 0x3FC(t1)
    andi    t2, t2, 0x1
    beq     t2, zero, ph_wait2
    nop
    sb      a1, 0x3F8(t1)
    
    addiu   t4, t4, -4              # 移位量-4
    addiu   t3, t3, -1              # 计数--
    bne     t3, zero, ph_loop
    nop
    
    jr      t0
    nop

