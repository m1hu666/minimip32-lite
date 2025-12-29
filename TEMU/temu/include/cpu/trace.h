#ifndef __TRACE_H__
#define __TRACE_H__

#include <stdint.h>

void trace_init(const char *filename);
void trace_close(void);

// 记录一次“写寄存器”事件
void trace_reg_write(uint32_t pc, int reg, uint32_t value);

#endif