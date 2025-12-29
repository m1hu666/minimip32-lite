include mips_sc/src/Makefile.testcase

.PHONY: run run-gui clean clean-temu

ifndef INCLUDE_DIR
INCLUDE_DIR := ./temu/include
endif
ifndef SRC_DIR
SRC_DIR := ./temu/src
endif
ifndef BUILD_DIR
BUILD_DIR := build/
endif
DEBUG := false

# Compilation flags
CC := gcc
CFLAGS := -I$(INCLUDE_DIR) -I$(INCLUDE_DIR)/cpu -I$(INCLUDE_DIR)/memory -I$(INCLUDE_DIR)/monitor -Wall -Werror
LDFLAGS := -lreadline

# GTK flags (检测是否安装了GTK)
GTK_CFLAGS := $(shell pkg-config --cflags gtk+-3.0 2>/dev/null)
GTK_LIBS := $(shell pkg-config --libs gtk+-3.0 2>/dev/null)

# 如果GTK可用，添加GUI编译标志
ifneq ($(GTK_CFLAGS),)
	HAS_GTK := yes
	CFLAGS_GUI := $(CFLAGS) $(GTK_CFLAGS) -DUSE_GUI
	LDFLAGS_GUI := $(LDFLAGS) $(GTK_LIBS)
else
	HAS_GTK := no
endif

# Files to be compiled
SRCS := $(wildcard $(SRC_DIR)/*.c) $(wildcard $(SRC_DIR)/memory/*.c) $(wildcard $(SRC_DIR)/cpu/*.c) $(wildcard $(SRC_DIR)/monitor/*.c)

TEMU_TARGET := temu
TEMU_GUI_TARGET := temu-gui

ifeq ($(DEBUG), true)
CFLAGS += -g
CFLAGS_GUI += -g
endif

export	INCLUDE_DIR
export	SRC_DIR
export	BUILD_DIR

# ********************
# Rules of Compilation
# ********************

# 默认命令行版本
$(BUILD_DIR)$(TEMU_TARGET): 
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $(SRCS) $(LDFLAGS)

# GUI版本
$(BUILD_DIR)$(TEMU_GUI_TARGET): 
	@mkdir -p $(BUILD_DIR)
ifeq ($(HAS_GTK),yes)
	@echo "Building TEMU with GUI support..."
	$(CC) $(CFLAGS_GUI) -o $@ $(SRCS) $(LDFLAGS_GUI)
	@echo "GUI version built successfully!"
else
	@echo "========================================="
	@echo "Error: GTK+3.0 not found!"
	@echo "Please install GTK+3.0 development files:"
	@echo "  Ubuntu/Debian: sudo apt-get install libgtk-3-dev pkg-config"
	@echo "  CentOS/RHEL:    sudo yum install gtk3-devel"
	@echo "  macOS:         brew install gtk+3"
	@echo "========================================="
	@exit 1
endif

# 命令行模式运行
run: $(BUILD_DIR)$(TEMU_TARGET)
	@./$(BUILD_DIR)$(TEMU_TARGET) $(USER_PROGRAM)

# GUI模式运行
run-gui: $(BUILD_DIR)$(TEMU_GUI_TARGET)
	@echo "Starting TEMU in GUI mode..."
	@./$(BUILD_DIR)$(TEMU_GUI_TARGET) $(USER_PROGRAM) --gui

# 检查GUI依赖
check-gui:
ifeq ($(HAS_GTK),yes)
	@echo "GTK+3.0 is installed and available"
	@echo "GTK_CFLAGS: $(GTK_CFLAGS)"
	@echo "GTK_LIBS: $(GTK_LIBS)"
else
	@echo "GTK+3.0 is NOT installed"
	@echo "Please install it to use GUI mode"
endif

# 编译所有版本
all: $(BUILD_DIR)$(TEMU_TARGET)
ifeq ($(HAS_GTK),yes)
	@$(MAKE) $(BUILD_DIR)$(TEMU_GUI_TARGET)
	@echo ""
	@echo "========================================="
	@echo "Build complete!"
	@echo "  Command-line version: ./$(BUILD_DIR)$(TEMU_TARGET)"
	@echo "  GUI version:           ./$(BUILD_DIR)$(TEMU_GUI_TARGET)"
	@echo ""
	@echo "Usage:"
	@echo "  make run       - Run in command-line mode"
	@echo "  make run-gui   - Run in GUI mode"
	@echo "========================================="
else
	@echo ""
	@echo "========================================="
	@echo "Build complete!  (Command-line only)"
	@echo "  Command-line version: ./$(BUILD_DIR)$(TEMU_TARGET)"
	@echo ""
	@echo "To enable GUI support, install GTK+3.0"
	@echo "========================================="
endif

# 帮助信息
help: 
	@echo "TEMU Makefile - Available targets:"
	@echo ""
	@echo "  make              - Build command-line version only"
	@echo "  make all          - Build all available versions"
	@echo "  make run          - Run in command-line mode"
	@echo "  make run-gui      - Run in GUI mode (requires GTK+3.0)"
	@echo "  make check-gui    - Check if GTK+3.0 is available"
	@echo "  make clean        - Clean all build files"
	@echo "  make clean-temu   - Clean only TEMU build files"
	@echo "  make help         - Show this help message"
	@echo ""
ifeq ($(HAS_GTK),yes)
	@echo "GUI support:  Available ✓"
else
	@echo "GUI support: Not available ✗"
	@echo "Install GTK+3.0 to enable GUI mode"
endif

clean-temu:
	rm -f -r $(BUILD_DIR)

clean:
	rm -f -r $(BUILD_DIR)
	rm -f -r ./mips_sc/build
	rm -f log.txt
	rm -f *.bin