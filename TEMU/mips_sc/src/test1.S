#include "trap.h"
   .set noat
   .globl main
   .text
main:
   # test1.S - 基本算术和逻辑指令测试
   # 测试：ADD, ADDU, ADDIU, AND, OR, XOR, ORI, ANDI, LUI
   
   # 初始化寄存器
   lui  $t0, 0x1234           # $t0 = 0x12340000
   ori  $t0, $t0, 0x5678      # $t0 = 0x12345678 (测试前推)
   lui  $t1, 0xABCD           # $t1 = 0xABCD0000
   ori  $t1, $t1, 0xEF00      # $t1 = 0xABCDEF00 (测试前推)
   
   # 算术指令测试
   add  $t2, $t0, $t1         # $t2 = $t0 + $t1 = 0xBE024578 (测试前推)
   addu $t3, $t0, $t1         # $t3 = $t0 + $t1 = 0xBE024578
   addiu $t4, $t0, 0x1000     # $t4 = 0x12346678 (测试前推)
   addiu $t5, $t4, -100       # $t5 = $t4 - 100 (测试前推)
   
   # 逻辑指令测试
   and  $t6, $t0, $t1         # $t6 = 0x02004600
   or   $t7, $t0, $t1         # $t7 = 0xBBEFEF78
   xor  $t8, $t0, $t1         # $t8 = 0xB9EFA978
   andi $t9, $t0, 0xFF00      # $t9 = 0x00005600
   ori  $s0, $zero, 0xFFFF    # $s0 = 0x0000FFFF
   
   # 边界条件测试
   lui  $s1, 0xFFFF           # $s1 = 0xFFFF0000
   ori  $s1, $s1, 0xFFFF      # $s1 = 0xFFFFFFFF (测试前推)
   addiu $s2, $zero, -1       # $s2 = 0xFFFFFFFF
   addu $s3, $s1, $s2         # $s3 = 0xFFFFFFFE (测试前推，溢出)
   
   # 零寄存器测试
   add  $s4, $zero, $t0       # $s4 = $t0 = 0x12345678
   or   $s5, $zero, $t1       # $s5 = $t1 = 0xABCDEF00
   xor  $s6, $t0, $t0         # $s6 = 0 (测试前推)
   
   # 连续依赖测试
   ori  $s7, $zero, 1         # $s7 = 1
   addu $v0, $s7, $s7         # $v0 = 2 (测试前推)
   addu $v1, $v0, $v0         # $v1 = 4 (测试前推)
   addu $a0, $v1, $v1         # $a0 = 8 (测试前推)
   
   HIT_GOOD_TRAP
