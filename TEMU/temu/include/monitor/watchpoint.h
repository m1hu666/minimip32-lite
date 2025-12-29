#ifndef __WATCHPOINT_H__
#define __WATCHPOINT_H__

#include "common.h"

typedef struct watchpoint {
	int NO;
	struct watchpoint *next;

	/* TODO: Add more members if necessary */
	char expr[100];
	uint32_t val;

} WP;

void init_wp_pool();
WP* new_wp();
void free_wp(WP *wp);
bool check_wp();
void delete_wp(int n);
void print_wp();
WP* get_wp_head();  // 新增：获取监视点链表头
#endif
