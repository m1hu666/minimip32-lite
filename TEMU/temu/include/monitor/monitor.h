#ifndef __MONITOR_H__
#define __MONITOR_H__

enum { STOP, RUNNING, END };
extern int temu_state;

// GUI 函数声明
void ui_mainloop_gui();
void gui_console_print(const char *text);
#endif
