#include "common.h"

uint32_t dram_read(uint32_t, size_t);
void dram_write(uint32_t, size_t, uint32_t);

/* 将虚拟地址转换为物理地址 */
static inline uint32_t vaddr_to_paddr(uint32_t vaddr) {
    /* MIPS 地址映射：
     * 0x80000000 - 0x9FFFFFFF (kseg0): 直接映射，物理地址 = 虚拟地址 & 0x1FFFFFFF
     * 0xA0000000 - 0xBFFFFFFF (kseg1): 直接映射，物理地址 = 虚拟地址 & 0x1FFFFFFF
     * 其他：直接使用虚拟地址
     */
    if (vaddr >= 0x80000000 && vaddr < 0xC0000000) {
        return vaddr & 0x1FFFFFFF;  // 去掉高3位
    }
    return vaddr;
}

/* Memory accessing interfaces */

uint32_t mem_read(uint32_t addr, size_t len) {
#ifdef DEBUG
	assert(len == 1 || len == 2 || len == 4);
#endif
    uint32_t paddr = vaddr_to_paddr(addr);
	return dram_read(paddr, len) & (~0u >> ((4 - len) << 3));
}

void mem_write(uint32_t addr, size_t len, uint32_t data) {
#ifdef DEBUG
	assert(len == 1 || len == 2 || len == 4);
#endif
    uint32_t paddr = vaddr_to_paddr(addr);
	dram_write(paddr, len, data);
}