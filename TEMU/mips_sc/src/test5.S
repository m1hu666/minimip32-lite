#include "trap.h"
   .set noat
   .globl main
   .text
main:
   # test5.S - 数据前推（Forwarding）测试
   # 测试RAW冒险和前推机制
   
   # EXE->ID 前推测试（相邻指令依赖）
   ori  $t0, $zero, 100       # $t0 = 100
   addu $t1, $t0, $t0         # $t1 = 200 (需要前推$t0)
   addu $t2, $t1, $t1         # $t2 = 400 (需要前推$t1)
   addu $t3, $t2, $t2         # $t3 = 800 (需要前推$t2)
   
   # 连续数据依赖链
   ori  $t4, $zero, 10        # $t4 = 10
   addiu $t5, $t4, 5          # $t5 = 15
   addiu $t6, $t5, 5          # $t6 = 20
   addiu $t7, $t6, 5          # $t7 = 25
   addiu $t8, $t7, 5          # $t8 = 30
   
   # 多个源操作数依赖
   ori  $t9, $zero, 8         # $t9 = 8
   ori  $s0, $zero, 7         # $s0 = 7
   addu $s1, $t9, $s0         # $s1 = 15
   addu $s2, $s1, $t9         # $s2 = 23 (两个源都需要前推)
   
   # 逻辑指令前推
   lui  $s3, 0xFF00
   nop
   nop
   nop
   ori  $s3, $s3, 0x00FF      # $s3 = 0xFF0000FF
   and  $s4, $s3, $s3         # $s4 = $s3
   or   $s5, $s3, $s4         # $s5 = $s3 (前推$s4)
   xor  $s6, $s4, $s5         # $s6 = 0 (前推两个)
   
   # 移位指令前推
   ori  $s7, $zero, 0xFF      # $s7 = 0xFF
   sll  $v0, $s7, 8           # $v0 = 0xFF00
   sll  $v1, $v0, 8           # $v1 = 0xFF0000 (前推$v0)
   ori  $a0, $zero, 8
   srav $a1, $v1, $a0         # $a1 = 0x00FF00 (前推$v1和$a0)
   
   # 分支指令前推测试（刚写入就比较）
   ori  $a2, $zero, 10
   ori  $a3, $zero, 10
   beq  $a2, $a3, BRANCH_OK   # 比较刚写入的寄存器，测试分支前推
   nop
   ori  $t0, $zero, 0xBAD1    # 不应执行
   beq  $zero, $zero, STORE_TEST
   nop
   
BRANCH_OK:
   ori  $t0, $zero, 0x0001    # $t0 = 1
   
STORE_TEST:
   # Store指令前推测试（刚计算就存储）
   lui  $gp, 0x8001
   ori  $t1, $zero, 0xABCD
   sw   $t1, 0($gp)           # 存储刚计算的值，测试前推
   
   # 复杂前推场景：连续移位（每次都依赖上一次）
   ori  $t2, $zero, 1
   sll  $t3, $t2, 1           # $t3 = 2 (前推$t2)
   sll  $t4, $t3, 1           # $t4 = 4 (前推$t3)
   sll  $t5, $t4, 1           # $t5 = 8 (前推$t4)
   sll  $t6, $t5, 1           # $t6 = 16 (前推$t5)
   
   # 前推优先级测试（EXE优先于MEM）
   ori  $t7, $zero, 0x1111    # $t7 = 0x1111
   ori  $t7, $zero, 0x2222    # $t7 = 0x2222 (新值)
   ori  $t8, $zero, 1
   addu $t9, $t7, $t8         # 应该使用EXE中的0x2222，测试前推优先级
   
   # 多路径前推（两个源都依赖）
   ori  $s0, $zero, 5
   ori  $s1, $zero, 3
   addu $s2, $s0, $s1         # $s2 = 8
   and  $s3, $s2, $s0         # $s3 = 0 (前推$s2，同时前推两个源)
   or   $s4, $s2, $s3         # 前推$s2和$s3
   xor  $s5, $s4, $s2         # 前推$s4和$s2
   
   HIT_GOOD_TRAP
