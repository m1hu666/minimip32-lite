#include "trace.h"
#include <string.h>
#include <stdio.h>

void init_monitor(int, char *[]);
void restart();
void ui_mainloop();

#ifdef USE_GUI
void ui_mainloop_gui();  // 只在 USE_GUI 定义时声明
#endif

int main(int argc, char *argv[]) {
    
    /* 检查是否使用GUI模式 */
    int use_gui = 0;
    
#ifdef USE_GUI
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--gui") == 0 || strcmp(argv[i], "-g") == 0) {
            use_gui = 1;
            break;
        }
    }
#endif

    printf("=== Starting TEMU ===\n");
    printf("Mode: %s\n", use_gui ? "GUI" : "CLI");
    
    /* Initialize the monitor.   */
    printf("Step 1: Initializing monitor.. .\n");
    init_monitor(argc, argv);
    printf("Step 1:  Done\n");

    /* Initialize the virtual computer system.  */
    printf("Step 2: Restarting system...\n");
    restart();
    printf("Step 2: Done\n");

    /* Receive commands from user. */
    printf("Step 3: Starting UI.. .\n");
    
#ifdef USE_GUI
    if (use_gui) {
        ui_mainloop_gui();  // 图形界面
    } else {
        ui_mainloop();      // 命令行界面
    }
#else
    if (use_gui) {
        printf("Warning: GUI not available in this build.\n");
        printf("Please recompile with 'make run-gui' for GUI support.\n");
        printf("Starting in command-line mode...\n");
    }
    ui_mainloop();  // 命令行界面
#endif

    trace_close();
    return 0;
}