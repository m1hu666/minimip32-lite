#include "trap.h"
   .set noat
   .globl main
   .text
main:
   # test7.S - 综合测试和边界条件
   # 综合测试所有指令类型
   
   # 边界条件1：零寄存器不可修改
   ori  $zero, $zero, 0xFFFF  # 尝试写$0（无效）
   addiu $zero, $zero, 1000   # 尝试写$0（无效）
   addu $t0, $zero, $zero     # $t0 = 0
   
   # 边界条件2：最大和最小立即数
   lui  $t1, 0xFFFF           # $t1 = 0xFFFF0000
   ori  $t1, $t1, 0xFFFF      # $t1 = 0xFFFFFFFF (测试前推)
   addiu $t2, $zero, -1       # $t2 = 0xFFFFFFFF
   addiu $t3, $zero, 32767    # 最大正16位立即数
   addiu $t4, $zero, -32768   # 最小负16位立即数
   
   # 边界条件3：算术溢出
   lui  $t5, 0x7FFF
   ori  $t5, $t5, 0xFFFF      # $t5 = 0x7FFFFFFF (测试前推)
   ori  $t6, $zero, 1
   addu $t7, $t5, $t6         # $t7 = 0x80000000 (测试前推，溢出)
   lui  $t8, 0x8000           # $t8 = 0x80000000 (最小负整数)
   
   # 边界条件4：移位边界
   ori  $t9, $zero, 1
   sll  $s0, $t9, 0           # 移位0位 (测试前推)
   sll  $s1, $t9, 31          # 移位31位 (测试前推)
   ori  $s2, $zero, 31
   srav $s3, $s1, $s2         # 算术右移31位 (测试前推)
   
   # 综合场景1：数组求和（测试前推和load-use）
   lui  $gp, 0x8001           # $gp = 0x80010000 (数据段)
   
   # 初始化数组（测试前推）
   ori  $s4, $zero, 10
   sw   $s4, 0($gp)           # array[0] = 10 (测试前推)
   ori  $s4, $zero, 20
   sw   $s4, 4($gp)           # array[1] = 20 (测试前推)
   ori  $s4, $zero, 30
   sw   $s4, 8($gp)           # array[2] = 30 (测试前推)
   
   # 求和循环（测试前推、load-use和分支）
   ori  $s5, $zero, 0         # sum = 0
   ori  $s6, $zero, 0         # i = 0
   ori  $s7, $zero, 3         # n = 3
   
SUM_LOOP:
   sll  $v0, $s6, 2           # offset = i * 4 (测试前推)
   addu $v1, $gp, $v0         # address = base + offset (测试前推)
   lw   $a0, 0($v1)           # load array[i] (测试前推)
   addu $s5, $s5, $a0         # sum += array[i] (测试load-use暂停)
   addiu $s6, $s6, 1          # i++ (测试前推)
   bne  $s6, $s7, SUM_LOOP    # 测试分支前推
   nop
   # $s5 = 10+20+30 = 60
   
   # 综合场景2：字操作（测试前推和小端模式）
   lui  $a1, 0x7856
   ori  $a1, $a1, 0x3412      # $a1 = 0x78563412 (测试前推)
   sw   $a1, 100($gp)         # 存储完整的字 (测试前推)
   lw   $t1, 100($gp)         # $t1 = 0x78563412 (测试load-use)
   
   # 综合场景3：位操作（测试前推）
   lui  $t2, 0xABCD
   ori  $t2, $t2, 0xEF12      # $t2 = 0xABCDEF12 (测试前推)
   andi $t3, $t2, 0x00FF      # $t3 = 0x12 (测试前推)
   ori  $t4, $zero, 24
   srav $t5, $t2, $t4         # 右移24位 (测试前推)
   andi $t5, $t5, 0x00FF      # $t5 = 0xAB (测试前推)
   
   # 结束标记
   lui  $at, 0xDEAD
   ori  $at, $at, 0xBEEF      # $at = 0xDEADBEEF (测试前推)
   
   HIT_GOOD_TRAP
