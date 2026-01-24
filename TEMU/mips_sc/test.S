#include "trap.h"
   .set noat
   
   .data
   .align 2
test_data1: .word 0x12345678
test_data2: .word 0xABCDEF00
test_array: .word 0x11, 0x22, 0x33, 0x44
   
   .text
   .globl main
main:
   # --- 基础寄存器初始化 ---
   # 1. addiu
   addiu $s0, $zero, 0x100     # addiu: $s0 = 0x100
   addiu $s1, $zero, 0x200     # addiu: $s1 = 0x200

   # --- 算术/逻辑指令测试 ---
   # 2. addu
   addu  $s0, $zero, $s1         # addu: $s0 = 0 + 0x200 = 0x200
   addiu $s0, $zero, 0x100       # 恢复 $s0 = 0x100

   # 3. andi
   andi  $t0, $s1, 0x00FF      # andi: $t0 = 0x200 & 0xFF = 0x00
   
   # 4. or
   or    $t1, $s0, $s1         # or: $t1 = 0x100 | 0x200 = 0x300
   
   # 5. xor
   xor   $t2, $t1, $s0         # xor: $t2 = 0x300 ^ 0x100 = 0x200
   
   # 6. sll (逻辑左移)
   sll   $t3, $s0, 2           # sll: $t3 = 0x100 << 2 = 0x400
   
   # 7. sub (减法)
   sub   $t4, $s1, $s0         # sub: $t4 = 0x200 - 0x100 = 0x100
   
   # 8. srlv (变量逻辑右移)
   addiu $a0, $zero, 4
   srlv  $t5, $t3, $a0         # srlv: $t5 = 0x400 >> 4 = 0x40

   # --- 访存指令测试 ---
   # 9. lui / 10. ori
   lui   $s2, 0x8000           # lui: 基地址 0x80000000
   ori   $s2, $s2, 0x1000      # ori: 偏移 0x1000，即地址 0x80001000
   
   # 11. sw / 12. lw
   sw    $s1, 0x0($s2)         # sw: [0x80001000] = 0x200
   lw    $t6, 0x0($s2)         # lw: $t6 = 0x200
   
   # 13. sb / 14. lb
   addiu $a1, $zero, 0x55
   sb    $a1, 0x4($s2)         # sb: [0x80001004] = 0x55
   lb    $t7, 0x4($s2)         # lb: $t7 = 0x55

   # --- 分支指令测试 ---
   # 15. beq (相等则跳转)
   beq   $t6, $s1, test_bne    # 如果 $t6 == $s1 (都是0x200)，跳转
   addiu $v0, $zero, 0x111     # 不应该执行
   
test_bne:
   # 16. bne (不等则跳转)
   addiu $a2, $zero, 0x123
   bne   $a2, $zero, test_bltz # 如果 $a2 != 0，跳转
   addiu $v0, $zero, 0x222     # 不应该执行

test_bltz:
   # 17. bltz (小于0则跳转)
   addiu $a3, $zero, -1        # $a3 = 0xFFFFFFFF
   bltz  $a3, test_end         # 如果 $a3 < 0，跳转
   addiu $v0, $zero, 0x333     # 不应该执行

test_end:
   HIT_GOOD_TRAP               # 测试结束
