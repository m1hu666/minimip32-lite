#include "temu.h"
#include <stdlib.h>
#include "reg.h"
#include "trace.h"

CPU_state cpu;
extern uint32_t current_instr_pc;

const char *regfile[] = {"$zero", "$at", "$v0", "v1", "$a0", "$a1", "$a2", "$a3", "$t0", "$t1", "$t2", "$t3", "$t4", "$t5", "$t6", "$t7", "$s0", "$s1", "$s2", "$s3", "$s4", "$s5", "$s6", "$s7", "$t8", "$t9", "$k0", "$k1", "$gp", "$sp", "$fp", "$ra"};

void display_reg() {
        int i;
        for(i = 0; i < 32; i ++) {
                printf("%s\t\t0x%08x\t\t0x%08x\n", regfile[i], cpu.gpr[i]._32, cpu.gpr[i]._32);
        }

        printf("%s\t\t0x%08x\t\t0x%08x\n", "$pc", cpu.pc, cpu.pc);
}

void set_reg(int idx, uint32_t val) {
    // 保证 $0 恒为 0
    if (idx == 0) return;

    cpu.gpr[idx]._32 = val;

    // 记录 Golden Trace
    trace_reg_write(current_instr_pc, idx, val);
}