
build/test1:     file format elf32-tradlittlemips
build/test1


Disassembly of section .text:

80000000 <main>:
80000000:	3c081234 	lui	t0,0x1234
80000004:	35085678 	ori	t0,t0,0x5678
80000008:	3c09abcd 	lui	t1,0xabcd
8000000c:	3529ef00 	ori	t1,t1,0xef00
80000010:	01095020 	add	t2,t0,t1
80000014:	01095821 	addu	t3,t0,t1
80000018:	250c1000 	addiu	t4,t0,4096
8000001c:	258dff9c 	addiu	t5,t4,-100
80000020:	01097024 	and	t6,t0,t1
80000024:	01097825 	or	t7,t0,t1
80000028:	0109c026 	xor	t8,t0,t1
8000002c:	3119ff00 	andi	t9,t0,0xff00
80000030:	3410ffff 	li	s0,0xffff
80000034:	3c11ffff 	lui	s1,0xffff
80000038:	3631ffff 	ori	s1,s1,0xffff
8000003c:	2412ffff 	li	s2,-1
80000040:	02329821 	addu	s3,s1,s2
80000044:	0008a020 	add	s4,zero,t0
80000048:	0009a825 	or	s5,zero,t1
8000004c:	0108b026 	xor	s6,t0,t0
80000050:	34170001 	li	s7,0x1
80000054:	02f71021 	addu	v0,s7,s7
80000058:	00421821 	addu	v1,v0,v0
8000005c:	00632021 	addu	a0,v1,v1
80000060:	4a000000 	c2	0x0

Disassembly of section .reginfo:

00000000 <.reginfo>:
   0:	03ffff1c 	0x3ffff1c
	...
