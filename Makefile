# ---------- CONFIG -----------

TOP      ?= mkAetheronTop
SRC_DIR  ?= src
OUT_DIR  ?= build
EXE      ?= sim

# Find all BSV source files recursively
SRCS     := $(shell find $(SRC_DIR) -name '*.bsv')

# Bluespec Compiler Flags
BSC_FLAGS := -sim -p +:$(SRC_DIR) -bdir $(OUT_DIR) -info-dir $(OUT_DIR)

# ---------- TARGETS -----------

.PHONY: all run clean

all: $(OUT_DIR)/$(EXE)

$(OUT_DIR)/$(EXE): $(SRCS) | $(OUT_DIR)
	@echo "[1/3] Compiling Bluespec modules"
	bsc $(BSC_FLAGS) -u -g $(TOP) $(SRC_DIR)/AetheronTop.bsv
	@echo "[2/3] Elaborating Top"
	bsc $(BSC_FLAGS) -e $(TOP) -o $(OUT_DIR)/$(EXE)

run: all
	@echo "[3/3] Running simulation"
	./$(OUT_DIR)/$(EXE)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

clean:
	rm -rf $(OUT_DIR)