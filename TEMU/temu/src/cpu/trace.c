#include "trace.h"
#include <stdio.h>

static FILE *trace_fp = NULL;

void trace_init(const char *filename) {
    trace_fp = fopen(filename, "w");
    fprintf(trace_fp, "%-10s %-12s %-16s\n",
            "PC值", "寄存器编号", "待写入寄存器的值");
    if (trace_fp == NULL) {
        perror("trace file open failed");
    }
}

void trace_close(void) {
    if (trace_fp) {
        fclose(trace_fp);
        trace_fp = NULL;
    }
}

void trace_reg_write(uint32_t pc, int reg, uint32_t value) {
    if (!trace_fp) return;

    // 不记录写 $0
    if (reg == 0) return;

    fprintf(trace_fp, "%-10.8x %-12.2d %-16.8x\n",
            pc, reg, value);
    // 如果不在意性能，可以每次都 flush，方便调试
    // fflush(trace_fp);
}