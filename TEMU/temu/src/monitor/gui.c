#ifdef USE_GUI
#include <gtk/gtk.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "monitor.h"
#include "reg.h"
#include "temu.h"
#include "watchpoint.h"

// 外部函数声明
extern void cpu_exec(uint32_t);
extern void display_reg();
extern uint32_t mem_read(uint32_t, size_t);
extern CPU_state cpu;
extern int temu_state;
extern const char *regfile[32];

// 监视点相关函数
extern WP* new_wp();
extern void delete_wp(int n);
extern void print_wp();
extern bool check_wp();

// GUI 组件
static GtkWidget *window;
static GtkWidget *text_view_console;
static GtkTextBuffer *buffer_console;
static GtkWidget *text_view_text_segment;
static GtkTextBuffer *buffer_text_segment;
static GtkWidget *reg_tree_view;
static GtkListStore *reg_store;
static GtkWidget *mem_tree_view;
static GtkListStore *mem_store;
static GtkWidget *status_label;
static GtkWidget *pc_label;
static GtkWidget *wp_tree_view;
static GtkListStore *wp_store;

// 内存范围定义
#define MEM_BASE_INSTR  0x80000000
#define MEM_SIZE_INSTR  (64 * 1024)
#define MEM_BASE_DATA   0x80010000
#define MEM_SIZE_DATA   (64 * 1024)

// ==================== 工具函数 ====================

int is_valid_address(uint32_t addr) {
    if (addr >= MEM_BASE_INSTR && addr < MEM_BASE_INSTR + MEM_SIZE_INSTR) {
        return 1;
    }
    if (addr >= MEM_BASE_DATA && addr < MEM_BASE_DATA + MEM_SIZE_DATA) {
        return 1;
    }
    return 0;
}

uint32_t safe_mem_read(uint32_t addr, size_t len) {
    if (!is_valid_address(addr)) {
        return 0;
    }
    return mem_read(addr, len);
}

void gui_console_print(const char *text) {
    if (!buffer_console) return;
    
    GtkTextIter iter;
    gtk_text_buffer_get_end_iter(buffer_console, &iter);
    gtk_text_buffer_insert(buffer_console, &iter, text, -1);
    
    GtkTextMark *mark = gtk_text_buffer_get_insert(buffer_console);
    gtk_text_view_scroll_to_mark(GTK_TEXT_VIEW(text_view_console), mark, 0.0, TRUE, 0.0, 1.0);  
}

void update_status(const char *status) {
    if (!status_label) return;
    
    char status_text[256];
    const char *state_str;
    
    switch(temu_state) {
        case 0: state_str = "STOPPED"; break;
        case 1: state_str = "RUNNING"; break;
        case 2: state_str = "END"; break;
        default: state_str = "UNKNOWN"; break;
    }
    
    snprintf(status_text, sizeof(status_text), "Status:  %s | %s", state_str, status);
    gtk_label_set_text(GTK_LABEL(status_label), status_text);
}

void update_pc_display() {
    if (!pc_label) return;
    
    char pc_text[128];
    snprintf(pc_text, sizeof(pc_text), "PC: 0x%08x (%u)", cpu.pc, cpu.pc);
    gtk_label_set_text(GTK_LABEL(pc_label), pc_text);
}

void update_register_display() {
    if (!reg_store) return;
    
    gtk_list_store_clear(reg_store);
    
    GtkTreeIter iter;
    for(int i = 0; i < 32; i++) {
        gtk_list_store_append(reg_store, &iter);
        gtk_list_store_set(reg_store, &iter,
            0, i,
            1, regfile[i],
            2, cpu.gpr[i]._32,
            3, (gint)cpu.gpr[i]._32,
            -1);
    }
    
    update_pc_display();
}

void update_watchpoint_display() {
    if (!wp_store) return;
    
    gtk_list_store_clear(wp_store);
    
    extern WP *get_wp_head();
    WP *wp = get_wp_head();
    
    GtkTreeIter iter;
    while (wp != NULL) {
        gtk_list_store_append(wp_store, &iter);
        gtk_list_store_set(wp_store, &iter,
            0, wp->NO,
            1, wp->expr,
            2, wp->val,
            -1);
        wp = wp->next;
    }
}

void update_memory_display(uint32_t start_addr, int lines) {
    if (!mem_store) return;
    
    gtk_list_store_clear(mem_store);
    
    if (! is_valid_address(start_addr)) {
        GtkTreeIter iter;
        gtk_list_store_append(mem_store, &iter);
        gtk_list_store_set(mem_store, &iter,
            0, start_addr,
            1, 0,
            2, "Invalid address",
            -1);
        return;
    }
    
    GtkTreeIter iter;
    for(int i = 0; i < lines; i++) {
        uint32_t addr = start_addr + i * 4;
        
        if (! is_valid_address(addr)) {
            break;
        }
        
        uint32_t data = safe_mem_read(addr, 4);
        char instr_text[64] = "";
        
        gtk_list_store_append(mem_store, &iter);
        gtk_list_store_set(mem_store, &iter,
            0, addr,
            1, data,
            2, instr_text,
            -1);
    }
}

void load_text_segment() {
    if (!buffer_text_segment) return;
    
    gtk_text_buffer_set_text(buffer_text_segment, "", -1);
    
    char line[256];
    snprintf(line, sizeof(line), "=== Text Segment (Instructions) ===\n\n");
    
    GtkTextIter iter;
    gtk_text_buffer_get_end_iter(buffer_text_segment, &iter);
    gtk_text_buffer_insert(buffer_text_segment, &iter, line, -1);
    
    if (! is_valid_address(cpu.pc)) {
        snprintf(line, sizeof(line), "Warning: PC (0x%08x) is outside valid memory range!\n", cpu.pc);
        gtk_text_buffer_get_end_iter(buffer_text_segment, &iter);
        gtk_text_buffer_insert(buffer_text_segment, &iter, line, -1);
        return;
    }
    
    uint32_t start_pc = cpu.pc;
    if (cpu.pc > 0x40 && cpu.pc >= MEM_BASE_INSTR + 0x40) {
        start_pc = cpu.pc - 0x40;
    } else {
        start_pc = MEM_BASE_INSTR;
    }
    
    for(int i = 0; i < 32; i++) {
        uint32_t addr = start_pc + i * 4;
        
        if (!is_valid_address(addr)) {
            break;
        }
        
        uint32_t instr = safe_mem_read(addr, 4);
        
        char marker = (addr == cpu.pc) ? '>' : ' ';
        snprintf(line, sizeof(line), "%c 0x%08x:       %08x\n", marker, addr, instr);
        
        gtk_text_buffer_get_end_iter(buffer_text_segment, &iter);
        gtk_text_buffer_insert(buffer_text_segment, &iter, line, -1);
    }
}

// ==================== 按钮回调函数 ====================

static void on_run_clicked(GtkWidget *widget, gpointer data) {
    gui_console_print("\n========== Running Program ==========\n");
    update_status("Running...");
    
    while(gtk_events_pending())
        gtk_main_iteration();
    
    cpu_exec(-1);
    
    update_register_display();
    load_text_segment();
    update_memory_display(MEM_BASE_DATA, 16);
    update_watchpoint_display();
    update_status("Program completed");
    gui_console_print("Program execution completed.\n");
}

static void on_step_clicked(GtkWidget *widget, gpointer data) {
    char msg[128];
    snprintf(msg, sizeof(msg), "\n--- Step:    PC=0x%08x ---\n", cpu.pc);
    gui_console_print(msg);
    
    cpu_exec(1);
    
    update_register_display();
    load_text_segment();
    update_memory_display(MEM_BASE_DATA, 16);
    update_watchpoint_display();
    update_status("Stepped 1 instruction");
}

static void on_step_n_clicked(GtkWidget *widget, gpointer data) {
    GtkWidget *entry = (GtkWidget *)data;
    const char *text = gtk_entry_get_text(GTK_ENTRY(entry));
    int steps = atoi(text);
    
    if(steps <= 0) steps = 1;
    
    char msg[128];
    snprintf(msg, sizeof(msg), "\n--- Stepping %d instructions ---\n", steps);
    gui_console_print(msg);
    
    cpu_exec(steps);
    
    update_register_display();
    load_text_segment();
    update_memory_display(MEM_BASE_DATA, 16);
    update_watchpoint_display();
    
    snprintf(msg, sizeof(msg), "Stepped %d instructions", steps);
    update_status(msg);
}

static void on_reset_clicked(GtkWidget *widget, gpointer data) {
    gui_console_print("\n========== System Reset ==========\n");
    
    extern void restart();
    restart();
    
    update_register_display();
    load_text_segment();
    update_memory_display(MEM_BASE_DATA, 16);
    update_watchpoint_display();
    update_status("System reset");
}

static void on_goto_pc_clicked(GtkWidget *widget, gpointer data) {
    load_text_segment();
    update_status("Jumped to current PC");
}

static void on_mem_addr_changed(GtkWidget *widget, gpointer data) {
    GtkWidget *entry = (data != NULL) ? (GtkWidget *)data : widget;
    const char *addr_text = gtk_entry_get_text(GTK_ENTRY(entry));
    uint32_t addr;
    
    if (sscanf(addr_text, "%x", &addr) != 1) {
        gui_console_print("Invalid address format!\n");
        return;
    }
    
    if (!is_valid_address(addr)) {
        char msg[128];
        snprintf(msg, sizeof(msg), "Warning: Address 0x%08x is outside valid memory range!\n", addr);
        gui_console_print(msg);
    }
    
    update_memory_display(addr, 16);
}

static void on_set_watchpoint_clicked(GtkWidget *widget, gpointer data) {
    GtkWidget *entry = (GtkWidget *)data;
    const char *expr_text = gtk_entry_get_text(GTK_ENTRY(entry));
    
    if (strlen(expr_text) == 0) {
        gui_console_print("Please enter an expression to watch!\n");
        return;
    }
    
    WP *wp = new_wp();
    if (wp == NULL) {
        gui_console_print("Failed to create watchpoint (maximum reached)!\n");
        return;
    }
    
    strncpy(wp->expr, expr_text, sizeof(wp->expr) - 1);
    wp->expr[sizeof(wp->expr) - 1] = '\0';
    
    bool success = false;
    extern uint32_t expr(char *e, bool *success);
    wp->val = expr(wp->expr, &success);
    
    if (! success) {
        gui_console_print("Invalid expression!\n");
        delete_wp(wp->NO);
        return;
    }
    
    char msg[256];
    snprintf(msg, sizeof(msg), "Watchpoint %d set:   %s = 0x%08x (%d)\n", 
             wp->NO, wp->expr, wp->val, wp->val);
    gui_console_print(msg);
    
    update_watchpoint_display();
    update_status("Watchpoint added");
}

static void on_clear_watchpoints_clicked(GtkWidget *widget, gpointer data) {
    extern WP *get_wp_head();
    WP *wp = get_wp_head();
    
    int count = 0;
    while (wp != NULL) {
        WP *next = wp->next;
        delete_wp(wp->NO);
        wp = next;
        count++;
    }
    
    char msg[64];
    snprintf(msg, sizeof(msg), "Cleared %d watchpoint(s).\n", count);
    gui_console_print(msg);
    
    update_watchpoint_display();
    update_status("Watchpoints cleared");
}

// 移除未使用的函数 on_delete_watchpoint_clicked

static void on_quit_clicked(GtkWidget *widget, gpointer data) {
    gtk_main_quit();
}

// ==================== 回调函数：格式化单元格数据 ====================

static void format_hex_address(GtkTreeViewColumn *col, GtkCellRenderer *cell,
                                GtkTreeModel *model, GtkTreeIter *iter, gpointer data) {
    guint val;
    gtk_tree_model_get(model, iter, 0, &val, -1);
    char text[16];
    snprintf(text, sizeof(text), "0x%08x", val);
    g_object_set(cell, "text", text, NULL);
}

static void format_hex_data(GtkTreeViewColumn *col, GtkCellRenderer *cell,
                             GtkTreeModel *model, GtkTreeIter *iter, gpointer data) {
    guint val;
    gtk_tree_model_get(model, iter, 1, &val, -1);
    char text[16];
    snprintf(text, sizeof(text), "0x%08x", val);
    g_object_set(cell, "text", text, NULL);
}

static void format_reg_hex(GtkTreeViewColumn *col, GtkCellRenderer *cell,
                            GtkTreeModel *model, GtkTreeIter *iter, gpointer data) {
    guint val;
    gtk_tree_model_get(model, iter, 2, &val, -1);
    char text[16];
    snprintf(text, sizeof(text), "0x%08x", val);
    g_object_set(cell, "text", text, NULL);
}

static void format_wp_value(GtkTreeViewColumn *col, GtkCellRenderer *cell,
                             GtkTreeModel *model, GtkTreeIter *iter, gpointer data) {
    guint val;
    gtk_tree_model_get(model, iter, 2, &val, -1);
    char text[32];
    snprintf(text, sizeof(text), "0x%08x (%d)", val, (int)val);
    g_object_set(cell, "text", text, NULL);
}

// ==================== 视图创建 ====================

GtkWidget* create_register_view() {
    reg_store = gtk_list_store_new(4, G_TYPE_INT, G_TYPE_STRING, G_TYPE_UINT, G_TYPE_INT);
    
    reg_tree_view = gtk_tree_view_new_with_model(GTK_TREE_MODEL(reg_store));
    gtk_tree_view_set_grid_lines(GTK_TREE_VIEW(reg_tree_view), GTK_TREE_VIEW_GRID_LINES_BOTH);
    
    GtkCellRenderer *renderer;
    GtkTreeViewColumn *column;
    
    renderer = gtk_cell_renderer_text_new();
    column = gtk_tree_view_column_new_with_attributes("No.", renderer, "text", 0, NULL);
    gtk_tree_view_column_set_min_width(column, 40);
    gtk_tree_view_append_column(GTK_TREE_VIEW(reg_tree_view), column);
    
    renderer = gtk_cell_renderer_text_new();
    column = gtk_tree_view_column_new_with_attributes("Register", renderer, "text", 1, NULL);
    gtk_tree_view_column_set_min_width(column, 60);
    gtk_tree_view_append_column(GTK_TREE_VIEW(reg_tree_view), column);
    
    renderer = gtk_cell_renderer_text_new();
    g_object_set(renderer, "family", "monospace", NULL);
    column = gtk_tree_view_column_new_with_attributes("Hex Value", renderer, NULL);
    gtk_tree_view_column_set_cell_data_func(column, renderer, format_reg_hex, NULL, NULL);
    gtk_tree_view_column_set_min_width(column, 100);
    gtk_tree_view_append_column(GTK_TREE_VIEW(reg_tree_view), column);
    
    renderer = gtk_cell_renderer_text_new();
    column = gtk_tree_view_column_new_with_attributes("Dec Value", renderer, "text", 3, NULL);
    gtk_tree_view_column_set_min_width(column, 100);
    gtk_tree_view_append_column(GTK_TREE_VIEW(reg_tree_view), column);
    
    GtkWidget *scrolled = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled),
                                   GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_container_add(GTK_CONTAINER(scrolled), reg_tree_view);
    
    return scrolled;
}

GtkWidget* create_watchpoint_view() {
    wp_store = gtk_list_store_new(3, G_TYPE_INT, G_TYPE_STRING, G_TYPE_UINT);
    
    wp_tree_view = gtk_tree_view_new_with_model(GTK_TREE_MODEL(wp_store));
    gtk_tree_view_set_grid_lines(GTK_TREE_VIEW(wp_tree_view), GTK_TREE_VIEW_GRID_LINES_BOTH);
    
    GtkCellRenderer *renderer;
    GtkTreeViewColumn *column;
    
    renderer = gtk_cell_renderer_text_new();
    column = gtk_tree_view_column_new_with_attributes("No.", renderer, "text", 0, NULL);
    gtk_tree_view_column_set_min_width(column, 40);
    gtk_tree_view_append_column(GTK_TREE_VIEW(wp_tree_view), column);
    
    renderer = gtk_cell_renderer_text_new();
    g_object_set(renderer, "family", "monospace", NULL);
    column = gtk_tree_view_column_new_with_attributes("Expression", renderer, "text", 1, NULL);
    gtk_tree_view_column_set_min_width(column, 120);
    gtk_tree_view_append_column(GTK_TREE_VIEW(wp_tree_view), column);
    
    renderer = gtk_cell_renderer_text_new();
    g_object_set(renderer, "family", "monospace", NULL);
    column = gtk_tree_view_column_new_with_attributes("Value", renderer, NULL);
    gtk_tree_view_column_set_cell_data_func(column, renderer, format_wp_value, NULL, NULL);
    gtk_tree_view_column_set_min_width(column, 150);
    gtk_tree_view_append_column(GTK_TREE_VIEW(wp_tree_view), column);
    
    GtkWidget *scrolled = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled),
                                   GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_container_add(GTK_CONTAINER(scrolled), wp_tree_view);
    
    return scrolled;
}

GtkWidget* create_memory_view() {
    mem_store = gtk_list_store_new(3, G_TYPE_UINT, G_TYPE_UINT, G_TYPE_STRING);
    
    mem_tree_view = gtk_tree_view_new_with_model(GTK_TREE_MODEL(mem_store));
    gtk_tree_view_set_grid_lines(GTK_TREE_VIEW(mem_tree_view), GTK_TREE_VIEW_GRID_LINES_BOTH);
    
    GtkCellRenderer *renderer;
    GtkTreeViewColumn *column;
    
    renderer = gtk_cell_renderer_text_new();
    g_object_set(renderer, "family", "monospace", NULL);
    column = gtk_tree_view_column_new_with_attributes("Address", renderer, NULL);
    gtk_tree_view_column_set_cell_data_func(column, renderer, format_hex_address, NULL, NULL);
    gtk_tree_view_column_set_min_width(column, 100);
    gtk_tree_view_append_column(GTK_TREE_VIEW(mem_tree_view), column);
    
    renderer = gtk_cell_renderer_text_new();
    g_object_set(renderer, "family", "monospace", NULL);
    column = gtk_tree_view_column_new_with_attributes("Data (Hex)", renderer, NULL);
    gtk_tree_view_column_set_cell_data_func(column, renderer, format_hex_data, NULL, NULL);
    gtk_tree_view_column_set_min_width(column, 100);
    gtk_tree_view_append_column(GTK_TREE_VIEW(mem_tree_view), column);
    
    renderer = gtk_cell_renderer_text_new();
    column = gtk_tree_view_column_new_with_attributes("Instruction", renderer, "text", 2, NULL);
    gtk_tree_view_column_set_min_width(column, 150);
    gtk_tree_view_append_column(GTK_TREE_VIEW(mem_tree_view), column);
    
    GtkWidget *scrolled = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled),
                                   GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_container_add(GTK_CONTAINER(scrolled), mem_tree_view);
    
    return scrolled;
}

// ==================== 主界面创建 ====================

void create_gui() {
    gtk_init(NULL, NULL);
    
    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "TEMU - MIPS32 Emulator (QtSpim Style)");
    gtk_window_set_default_size(GTK_WINDOW(window), 1200, 800);
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    
    GtkWidget *main_vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_container_add(GTK_CONTAINER(window), main_vbox);
    
    GtkWidget *toolbar_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_pack_start(GTK_BOX(main_vbox), toolbar_box, FALSE, FALSE, 5);
    gtk_widget_set_margin_start(toolbar_box, 5);
    gtk_widget_set_margin_end(toolbar_box, 5);
    
    GtkWidget *btn_run = gtk_button_new_with_label("▶ Run");
    g_signal_connect(btn_run, "clicked", G_CALLBACK(on_run_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(toolbar_box), btn_run, FALSE, FALSE, 2);
    
    GtkWidget *btn_step = gtk_button_new_with_label("⏭ Step");
    g_signal_connect(btn_step, "clicked", G_CALLBACK(on_step_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(toolbar_box), btn_step, FALSE, FALSE, 2);
    
    GtkWidget *step_entry = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(step_entry), "10");
    gtk_entry_set_width_chars(GTK_ENTRY(step_entry), 5);
    gtk_box_pack_start(GTK_BOX(toolbar_box), step_entry, FALSE, FALSE, 2);
    
    GtkWidget *btn_step_n = gtk_button_new_with_label("⏩ Step N");
    g_signal_connect(btn_step_n, "clicked", G_CALLBACK(on_step_n_clicked), step_entry);
    gtk_box_pack_start(GTK_BOX(toolbar_box), btn_step_n, FALSE, FALSE, 2);
    
    gtk_box_pack_start(GTK_BOX(toolbar_box), gtk_separator_new(GTK_ORIENTATION_VERTICAL), FALSE, FALSE, 5);
    
    GtkWidget *btn_reset = gtk_button_new_with_label("🔄 Reset");
    g_signal_connect(btn_reset, "clicked", G_CALLBACK(on_reset_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(toolbar_box), btn_reset, FALSE, FALSE, 2);
    
    GtkWidget *btn_goto_pc = gtk_button_new_with_label("📍 Go to PC");
    g_signal_connect(btn_goto_pc, "clicked", G_CALLBACK(on_goto_pc_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(toolbar_box), btn_goto_pc, FALSE, FALSE, 2);
    
    gtk_box_pack_start(GTK_BOX(toolbar_box), gtk_separator_new(GTK_ORIENTATION_VERTICAL), FALSE, FALSE, 5);
    
    gtk_box_pack_start(GTK_BOX(toolbar_box), gtk_label_new("Watchpoint:    "), FALSE, FALSE, 2);
    GtkWidget *wp_entry = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(wp_entry), "$t0");
    gtk_entry_set_width_chars(GTK_ENTRY(wp_entry), 12);
    gtk_entry_set_placeholder_text(GTK_ENTRY(wp_entry), "e.g.    $t0, $s1+10");
    gtk_box_pack_start(GTK_BOX(toolbar_box), wp_entry, FALSE, FALSE, 2);
    
    GtkWidget *btn_set_wp = gtk_button_new_with_label("Set");
    g_signal_connect(btn_set_wp, "clicked", G_CALLBACK(on_set_watchpoint_clicked), wp_entry);
    gtk_box_pack_start(GTK_BOX(toolbar_box), btn_set_wp, FALSE, FALSE, 2);
    
    GtkWidget *btn_clear_wp = gtk_button_new_with_label("Clear All");
    g_signal_connect(btn_clear_wp, "clicked", G_CALLBACK(on_clear_watchpoints_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(toolbar_box), btn_clear_wp, FALSE, FALSE, 2);
    
    GtkWidget *btn_quit = gtk_button_new_with_label("❌ Quit");
    g_signal_connect(btn_quit, "clicked", G_CALLBACK(on_quit_clicked), NULL);
    gtk_box_pack_end(GTK_BOX(toolbar_box), btn_quit, FALSE, FALSE, 2);
    
    pc_label = gtk_label_new("PC: 0x00000000");
    gtk_label_set_xalign(GTK_LABEL(pc_label), 0.0);
    
    GtkCssProvider *css_provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(css_provider,
        "#pc-label { font-family: monospace; font-weight: bold; font-size: 11pt; }",
        -1, NULL);
    GtkStyleContext *context = gtk_widget_get_style_context(pc_label);
    gtk_style_context_add_provider(context,
        GTK_STYLE_PROVIDER(css_provider),
        GTK_STYLE_PROVIDER_PRIORITY_USER);
    gtk_widget_set_name(pc_label, "pc-label");
    
    gtk_box_pack_start(GTK_BOX(main_vbox), pc_label, FALSE, FALSE, 5);
    gtk_widget_set_margin_start(pc_label, 10);
    
    GtkWidget *main_paned = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL);
    gtk_box_pack_start(GTK_BOX(main_vbox), main_paned, TRUE, TRUE, 0);
    
    GtkWidget *left_paned = gtk_paned_new(GTK_ORIENTATION_VERTICAL);
    gtk_paned_add1(GTK_PANED(main_paned), left_paned);
    gtk_paned_set_position(GTK_PANED(main_paned), 600);
    
    GtkWidget *text_frame = gtk_frame_new("Text Segment (Instructions)");
    GtkWidget *text_scroll = gtk_scrolled_window_new(NULL, NULL);
    text_view_text_segment = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(text_view_text_segment), FALSE);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(text_view_text_segment), TRUE);
    buffer_text_segment = gtk_text_view_get_buffer(GTK_TEXT_VIEW(text_view_text_segment));
    gtk_container_add(GTK_CONTAINER(text_scroll), text_view_text_segment);
    gtk_container_add(GTK_CONTAINER(text_frame), text_scroll);
    gtk_paned_add1(GTK_PANED(left_paned), text_frame);
    
    GtkWidget *console_frame = gtk_frame_new("Console Output");
    GtkWidget *console_scroll = gtk_scrolled_window_new(NULL, NULL);
    text_view_console = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(text_view_console), FALSE);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(text_view_console), TRUE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(text_view_console), GTK_WRAP_WORD_CHAR);
    buffer_console = gtk_text_view_get_buffer(GTK_TEXT_VIEW(text_view_console));
    gtk_container_add(GTK_CONTAINER(console_scroll), text_view_console);
    gtk_container_add(GTK_CONTAINER(console_frame), console_scroll);
    gtk_paned_add2(GTK_PANED(left_paned), console_frame);
    gtk_paned_set_position(GTK_PANED(left_paned), 400);
    
    GtkWidget *right_vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
    gtk_paned_add2(GTK_PANED(main_paned), right_vbox);
    
    GtkWidget *reg_frame = gtk_frame_new("Registers");
    GtkWidget *reg_view = create_register_view();
    gtk_container_add(GTK_CONTAINER(reg_frame), reg_view);
    gtk_widget_set_size_request(reg_frame, -1, 250);
    gtk_box_pack_start(GTK_BOX(right_vbox), reg_frame, TRUE, TRUE, 2);
    
    GtkWidget *wp_frame = gtk_frame_new("Watchpoints");
    GtkWidget *wp_view = create_watchpoint_view();
    gtk_container_add(GTK_CONTAINER(wp_frame), wp_view);
    gtk_widget_set_size_request(wp_frame, -1, 150);
    gtk_box_pack_start(GTK_BOX(right_vbox), wp_frame, FALSE, FALSE, 2);
    
    GtkWidget *mem_vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
    GtkWidget *mem_frame = gtk_frame_new("Memory / Data Segment");
    
    GtkWidget *mem_ctrl_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_pack_start(GTK_BOX(mem_vbox), mem_ctrl_box, FALSE, FALSE, 5);
    gtk_widget_set_margin_start(mem_ctrl_box, 5);
    
    gtk_box_pack_start(GTK_BOX(mem_ctrl_box), gtk_label_new("Address:  "), FALSE, FALSE, 2);
    GtkWidget *mem_addr_entry = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(mem_addr_entry), "80010000");
    gtk_entry_set_width_chars(GTK_ENTRY(mem_addr_entry), 12);
    g_signal_connect(mem_addr_entry, "activate", G_CALLBACK(on_mem_addr_changed), mem_addr_entry);
    gtk_box_pack_start(GTK_BOX(mem_ctrl_box), mem_addr_entry, FALSE, FALSE, 2);
    
    GtkWidget *mem_go_btn = gtk_button_new_with_label("Go");
    g_signal_connect(mem_go_btn, "clicked", G_CALLBACK(on_mem_addr_changed), mem_addr_entry);
    gtk_box_pack_start(GTK_BOX(mem_ctrl_box), mem_go_btn, FALSE, FALSE, 2);
    
    GtkWidget *mem_view = create_memory_view();
    gtk_box_pack_start(GTK_BOX(mem_vbox), mem_view, TRUE, TRUE, 0);
    gtk_container_add(GTK_CONTAINER(mem_frame), mem_vbox);
    gtk_box_pack_start(GTK_BOX(right_vbox), mem_frame, TRUE, TRUE, 2);
    
    status_label = gtk_label_new("Status:    Initializing...");
    gtk_label_set_xalign(GTK_LABEL(status_label), 0.0);
    gtk_box_pack_start(GTK_BOX(main_vbox), status_label, FALSE, FALSE, 5);
    gtk_widget_set_margin_start(status_label, 10);
    gtk_widget_set_margin_bottom(status_label, 5);
    
    gtk_widget_show_all(window);
    
    gui_console_print("╔══════════════════════════════════════════╗\n");
    gui_console_print("║   TEMU - MIPS32 Instruction Emulator   ║\n");
    gui_console_print("║         QtSpim-Style Interface          ║\n");
    gui_console_print("╚══════════════════════════════════════════╝\n\n");
    gui_console_print("Initializing system...\n");
    
    while(gtk_events_pending())
        gtk_main_iteration();
}

static gboolean delayed_init(gpointer user_data) {
    gui_console_print("System initialized.     Ready to execute.\n\n");
    gui_console_print("Tip: Set watchpoints to monitor register values (e.g., $t0, $s1+10)\n\n");
    
    update_register_display();
    load_text_segment();
    update_memory_display(MEM_BASE_DATA, 16);
    update_watchpoint_display();
    update_status("Ready");
    
    return FALSE;
}

void ui_mainloop_gui() {
    create_gui();
    g_idle_add(delayed_init, NULL);
    gtk_main();
}

#endif 
