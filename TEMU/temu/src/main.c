#include "trace.h"
#include <string.h>
#include <stdio.h>

void init_monitor(int, char *[]);
void restart();
void ui_mainloop();
void ui_mainloop_gui();  // GUI 模式

int main(int argc, char *argv[]) {
    
    /* 检查是否使用GUI模式 */
    int use_gui = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--gui") == 0 || strcmp(argv[i], "-g") == 0) {
            use_gui = 1;
            break;
        }
    }

    printf("=== Starting TEMU ===\n");
    printf("Mode: %s\n", use_gui ? "GUI" : "CLI");
    
    /* Initialize the monitor.   */
    printf("Step 1: Initializing monitor.. .\n");
    init_monitor(argc, argv);
    printf("Step 1:  Done\n");

    /* Test the implementation of the `CPU_state' structure.  */
    //reg_test();

    /* Initialize the virtual computer system. */
    printf("Step 2: Restarting system...\n");
    restart();
    printf("Step 2: Done\n");

    /* Receive commands from user. */
    printf("Step 3: Starting UI...\n");
    if (use_gui) {
        ui_mainloop_gui();  // 图形界面
    } else {
        ui_mainloop();      // 命令行界面
    }

    trace_close();
    return 0;
}