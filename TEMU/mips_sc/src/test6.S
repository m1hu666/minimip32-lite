#include "trap.h"
   .set noat
   .globl main
   .text
main:
   # test6.S - Load-Use冒险和流水线暂停测试
   # 测试需要暂停流水线的情况
   
   # 初始化数据段基地址
   lui  $s0, 0x8001           # $s0 = 0x80010000
   
   # 准备测试数据（测试前推）
   ori  $t0, $zero, 0x1234
   ori  $t1, $zero, 0x5678
   ori  $t2, $zero, 0xABCD
   sw   $t0, 0($s0)           # [0x80010000] = 0x1234 (测试前推)
   sw   $t1, 4($s0)           # [0x80010004] = 0x5678 (测试前推)
   sw   $t2, 8($s0)           # [0x80010008] = 0xABCD (测试前推)
   
   # Load-Use冒险测试1：紧邻的load和use（必须暂停）
   lw   $t3, 0($s0)           # $t3 = 0x1234
   addu $t4, $t3, $t3         # 立即使用$t3，必须暂停1周期
   
   # Load-Use冒险测试2：load后立即作为跳转条件（必须暂停）
   ori  $t5, $zero, 0x0001
   sw   $t5, 12($s0)          # [0x8001000C] = 0x0001 (测试前推)
   lw   $t6, 12($s0)          # $t6 = 0x0001
   beq  $t6, $t5, LABEL1      # 立即使用$t6作为分支条件，必须暂停
   nop
   ori  $t7, $zero, 0xBAD1    # 不应执行
   beq  $zero, $zero, LABEL2
   nop
   
LABEL1:
   ori  $t7, $zero, 0x0001    # $t7 = 1
   
LABEL2:
   # Load-Use冒险测试3：多个连续load-use（每次都暂停）
   lw   $t8, 0($s0)           # load
   addu $t9, $t8, $t8         # 立即use，必须暂停
   lw   $s1, 4($s0)           # load
   addu $s2, $s1, $s1         # 立即use，必须暂停
   addu $s3, $t9, $s2         # use两个前推的结果（不需要暂停）
   
   # Load-Use冒险测试4：load后间隔一条指令（不需要暂停）
   lw   $s4, 0($s0)           # load
   ori  $s5, $zero, 0x0100    # 中间指令（间隔）
   addu $s6, $s4, $s5         # 不需要暂停，可以用MEM前推
   
   # Load-Use冒险测试5：LB的load-use（必须暂停）
   ori  $s7, $zero, 0xFF
   sb   $s7, 20($s0)          # [0x80010014] = 0xFF (测试前推)
   lb   $v0, 20($s0)          # $v0 = 0xFFFFFFFF
   andi $v1, $v0, 0x00FF      # 立即use，必须暂停
   
   # Load-Use冒险测试6：load用于store的数据（必须暂停）
   lw   $a0, 0($s0)           # load
   sw   $a0, 24($s0)          # 立即store，必须暂停
   
   # Load-Use冒险测试7：连续三个load-use（连续暂停）
   lw   $a1, 0($s0)           # load1
   addu $a2, $a1, $a1         # use1，必须暂停
   addu $a3, $a2, $a2         # use2，必须暂停
   addu $t0, $a3, $a3         # use3，必须暂停
   
   # Load后立即用于地址计算（必须暂停）
   lw   $t1, 0($s0)           # load
   sw   $zero, 0($t1)         # 立即用作地址，必须暂停
   
   # 双源load-use（必须暂停）
   lw   $t2, 0($s0)           # load1
   lw   $t3, 4($s0)           # load2
   addu $t4, $t2, $t3         # 两个源都是load的，必须暂停
   
   HIT_GOOD_TRAP
