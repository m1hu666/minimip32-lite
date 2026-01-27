#include "trap.h"
   .set noat
   .globl main
   .text
main:
   # test4.S - Load/Store指令测试
   # 测试：LW, LB, SW（data_ram不支持字节写使能）
   
   # 初始化基地址
   lui  $s0, 0x8001           # $s0 = 0x80010000 (数据段基地址)
   
   # 准备测试数据
   lui  $t0, 0x1234
   ori  $t0, $t0, 0x5678      # $t0 = 0x12345678 (测试前推)
   lui  $t1, 0xABCD
   ori  $t1, $t1, 0xEF00      # $t1 = 0xABCDEF00 (测试前推)
   lui  $t2, 0xFFFF
   ori  $t2, $t2, 0xFFFF      # $t2 = 0xFFFFFFFF
   ori  $t3, $zero, 0x0080    # $t3 = 0x00000080
   
   # SW测试：存储字（测试前推）
   sw   $t0, 0($s0)           # [0x80010000] = 0x12345678
   sw   $t1, 4($s0)           # [0x80010004] = 0xABCDEF00
   sw   $t2, 8($s0)           # [0x80010008] = 0xFFFFFFFF
   sw   $t3, 12($s0)          # [0x8001000C] = 0x00000080
   sw   $zero, 16($s0)        # [0x80010010] = 0x00000000
   
   # LW测试：加载字（无需nop，但测试load-use冒险）
   lw   $t4, 0($s0)           # $t4 = 0x12345678
   lw   $t5, 4($s0)           # $t5 = 0xABCDEF00
   lw   $t6, 8($s0)           # $t6 = 0xFFFFFFFF
   lw   $t7, 12($s0)          # $t7 = 0x00000080
   lw   $t8, 16($s0)          # $t8 = 0x00000000
   
   # LB测试：加载字节（符号扩展）- 从0x12345678读取
   lb   $s1, 0($s0)           # $s1 = 0x78 -> 0x00000078 (正数)
   lb   $s2, 1($s0)           # $s2 = 0x56 -> 0x00000056 (正数)
   lb   $s3, 2($s0)           # $s3 = 0x34 -> 0x00000034 (正数)
   lb   $s4, 3($s0)           # $s4 = 0x12 -> 0x00000012 (正数)
   
   # LB负数测试（符号扩展）- 从0xABCDEF00读取
   lb   $s5, 4($s0)           # $s5 = 0x00 -> 0x00000000
   lb   $s6, 5($s0)           # $s6 = 0xEF -> 0xFFFFFFEF (负数)
   lb   $s7, 6($s0)           # $s7 = 0xCD -> 0xFFFFFFCD (负数)
   lb   $v0, 7($s0)           # $v0 = 0xAB -> 0xFFFFFFAB (负数)
   
   # LB从0xFFFFFFFF读取（全是负数）
   lb   $t9, 8($s0)           # $t9 = 0xFF -> 0xFFFFFFFF (负数)
   lb   $s0, 9($s0)           # $s0 = 0xFF -> 0xFFFFFFFF (负数，覆盖基地址)
   
   # 重新设置基地址
   lui  $s0, 0x8001           # $s0 = 0x80010000 (恢复基地址)

   # SB测试：存字节（读-改-写验证）
   # 初始 [0] = 0x12345678
   ori  $t4, $zero, 0xAA     # 0xAA
   sb   $t4, 0($s0)          # byte0 <- 0xAA -> word becomes 0x123456AA
   lw   $t5, 0($s0)          # $t5 = 0x123456AA (验证整字读回)

   ori  $t4, $zero, 0x55     # 0x55
   sb   $t4, 1($s0)          # byte1 <- 0x55 -> word becomes 0x123455AA
   lw   $t6, 0($s0)          # $t6 = 0x123455AA

   ori  $t4, $zero, 0xFF     # 0xFF
   sb   $t4, 2($s0)          # byte2 <- 0xFF -> word becomes 0x12FF55AA
   lw   $t7, 0($s0)          # $t7 = 0x12FF55AA

   # 在跨字边界的位置写字节（例如 offset 5 对应 word at addr 4）
   ori  $t4, $zero, 0x7F
   sb   $t4, 5($s0)          # write byte at addr 0x80010005 (affects word at 0x80010004)
   lb   $s6, 5($s0)          # read back the byte (sign-extended): expect 0x0000007F

   
   # 大偏移测试（测试前推）
   sw   $t1, 100($s0)         # [0x80010064] = 0xABCDEF00
   lw   $v1, 100($s0)         # $v1 = 0xABCDEF00
   
   # Load-use测试：立即使用load的结果（测试流水线暂停）
   lw   $a0, 0($s0)           # load
   addu $a1, $a0, $a0         # 立即use，测试暂停机制
   lw   $a2, 4($s0)           # load  
   or   $a3, $a2, $a2         # 立即use，测试暂停机制
   
   # 连续SW测试数据前推
   add  $k0, $t0, $t1         # $k0 = 0x12345678 + 0xABCDEF00
   sw   $k0, 20($s0)          # 立即存储计算结果
   lw   $k1, 20($s0)          # 读回验证
   
   HIT_GOOD_TRAP
