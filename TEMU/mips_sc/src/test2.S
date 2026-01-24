#include "trap.h"
   .set noat
   .globl main
   .text
main:
   # test2.S - 移位和移位算术指令测试
   # 测试：SLL, SRAV
   
   # 初始化测试数据
   lui  $t0, 0x8000           # $t0 = 0x80000000 (最小负数)
   ori  $t1, $zero, 0x0001    # $t1 = 0x00000001
   ori  $t2, $zero, 0x00FF    # $t2 = 0x000000FF
   ori  $t3, $zero, 0x1234    # $t3 = 0x00001234
   
   # 左移指令测试（SLL）
   sll  $t4, $t1, 0           # $t4 = 0x00000001 (移位0)
   sll  $t5, $t1, 1           # $t5 = 0x00000002 (移位1)
   sll  $t6, $t1, 4           # $t6 = 0x00000010 (移位4)
   sll  $t7, $t1, 8           # $t7 = 0x00000100 (移位8)
   sll  $t8, $t1, 16          # $t8 = 0x00010000 (移位16)
   sll  $t9, $t1, 31          # $t9 = 0x80000000 (最大移位)
   sll  $s0, $t2, 8           # $s0 = 0x0000FF00 (测试前推)
   sll  $s1, $t2, 16          # $s1 = 0x00FF0000 (测试前推)
   sll  $s2, $t2, 24          # $s2 = 0xFF000000 (测试前推)
   
   # 算术右移指令测试（SRAV）
   ori  $s3, $zero, 16        # $s3 = 16 (移位量)
   srav $s4, $t0, $s3         # $s4 = 0x80000000 >>> 16 (测试前推)
   ori  $s5, $zero, 31        # $s5 = 31
   srav $s6, $t0, $s5         # $s6 = 0x80000000 >>> 31 (测试前推)
   ori  $s7, $zero, 4         # $s7 = 4
   srav $at, $t3, $s7         # $at = 0x1234 >>> 4 (测试前推)
   
   # 正数的算术右移
   lui  $v0, 0x7FFF           # $v0 = 0x7FFF0000 (正数)
   ori  $v0, $v0, 0xFFFF      # $v0 = 0x7FFFFFFF (测试前推)
   ori  $v1, $zero, 8         # $v1 = 8
   srav $a0, $v0, $v1         # $a0 = 0x007FFFFF (测试前推)
   
   # 边界测试：移位量为0
   ori  $a1, $zero, 0         # $a1 = 0
   srav $a2, $t0, $a1         # $a2 = $t0 (测试前推)
   
   # 大移位量测试
   ori  $a3, $zero, 30        # $a3 = 30
   srav $t4, $t0, $a3         # $t4 = 0xFFFFFFFE (测试前推)
   
   # 连续移位依赖
   ori  $t5, $zero, 1
   sll  $t6, $t5, 2           # $t6 = 4 (测试前推)
   sll  $t7, $t6, 2           # $t7 = 16 (测试前推)
   sll  $t8, $t7, 2           # $t8 = 64 (测试前推)
   
   HIT_GOOD_TRAP
