#include "trap.h"
   .set noat
   .globl main
   .text
main:
   # test3.S - 分支指令测试
   # 测试：BEQ, BNE, BLEZ
   
   # 初始化测试数据
   ori  $t0, $zero, 0         # $t0 = 0
   ori  $t1, $zero, 10        # $t1 = 10
   ori  $t2, $zero, 10        # $t2 = 10
   addiu $t3, $zero, -5       # $t3 = -5
   
   # BEQ测试：相等应跳转（测试分支前推）
   beq  $t1, $t2, BEQ_TAKEN   # 应该跳转 (10 == 10)
   nop
   ori  $t4, $zero, 0xBAD1    # 不应执行
   
BEQ_TAKEN:
   ori  $t4, $zero, 0x0001    # $t4 = 1，标记BEQ正确
   
   # BEQ测试：不等不应跳转
   beq  $t0, $t1, BEQ_WRONG   # 不应跳转 (0 != 10)
   nop
   ori  $t5, $zero, 0x0002    # $t5 = 2，应该执行
   beq  $zero, $zero, BNE_TEST
   nop
   
BEQ_WRONG:
   ori  $t5, $zero, 0xBAD2    # 不应执行
   
BNE_TEST:
   # BNE测试：不等应跳转（测试分支前推）
   bne  $t0, $t1, BNE_TAKEN   # 应该跳转 (0 != 10)
   nop
   ori  $t6, $zero, 0xBAD3    # 不应执行
   
BNE_TAKEN:
   ori  $t6, $zero, 0x0003    # $t6 = 3，标记BNE正确
   
   # BNE测试：相等不应跳转
   bne  $t1, $t2, BNE_WRONG   # 不应跳转 (10 == 10)
   nop
   ori  $t7, $zero, 0x0004    # $t7 = 4，应该执行
   beq  $zero, $zero, BLEZ_TEST
   nop
   
BNE_WRONG:
   ori  $t7, $zero, 0xBAD4    # 不应执行
   
BLEZ_TEST:
   # BLEZ测试：零应跳转（测试分支前推）
   blez $t0, BLEZ_ZERO        # 应该跳转 (0 <= 0)
   nop
   ori  $t8, $zero, 0xBAD5    # 不应执行
   
BLEZ_ZERO:
   ori  $t8, $zero, 0x0005    # $t8 = 5
   
   # BLEZ测试：负数应跳转
   blez $t3, BLEZ_NEG         # 应该跳转 (-5 <= 0)
   nop
   ori  $t9, $zero, 0xBAD6    # 不应执行
   
BLEZ_NEG:
   ori  $t9, $zero, 0x0006    # $t9 = 6
   
   # BLEZ测试：正数不应跳转
   blez $t1, BLEZ_WRONG       # 不应跳转 (10 > 0)
   nop
   ori  $s0, $zero, 0x0007    # $s0 = 7，应该执行
   beq  $zero, $zero, LOOP_TEST
   nop
   
BLEZ_WRONG:
   ori  $s0, $zero, 0xBAD7    # 不应执行
   
LOOP_TEST:
   # 后向跳转循环测试（测试分支和前推）
   ori  $s1, $zero, 5         # 计数器
   ori  $s2, $zero, 0         # 累加器
   
LOOP:
   addu $s2, $s2, $s1         # $s2 += $s1 (测试前推)
   addiu $s1, $s1, -1         # $s1-- (测试前推)
   bne  $s1, $zero, LOOP      # 测试分支前推
   nop
   # $s2 = 5+4+3+2+1 = 15
   
   HIT_GOOD_TRAP
