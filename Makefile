# -------- CONFIG --------
TOP       ?= mkAetheronTop
SRC_DIR   := src
ASM_DIR   := asm
C_DIR     := c_src
LD_DIR    := linker
HEX_DIR   := hex
BUILD_DIR := build
EXE       := sim
LINKER    := $(LD_DIR)/boot.ld
PAYLOAD   ?= $(ASM_DIR)/uart_test.s
ROM_HEX   := $(HEX_DIR)/rom.hex

BSC_FLAGS := -sim \
             -p +:$(SRC_DIR) \
             -p +:$(SRC_DIR)/TileLinkPkg \
             -p +:$(SRC_DIR)/PeripheralsPkg \
             -p +:$(SRC_DIR)/MemoryPkg \
             -bdir $(BUILD_DIR) \
             -info-dir $(BUILD_DIR)

RISCV_PREFIX ?= riscv64-elf
AS      := $(RISCV_PREFIX)-as
LD      := $(RISCV_PREFIX)-ld
OBJCOPY := $(RISCV_PREFIX)-objcopy

# -------- TARGETS --------

.PHONY: all run clean bsim hex

all: $(ROM_HEX)

# === [1] Build ROM from Assembly ===
$(ROM_HEX): $(PAYLOAD) | $(HEX_DIR)
	@echo "[1/4] Assembling: $(PAYLOAD)"
	$(AS) -march=rv32i -mabi=ilp32 -o $(ASM_DIR)/bootloader.o $(PAYLOAD)

	@echo "[2/4] Linking with boot.ld"
	$(LD) -m elf32lriscv -T $(LINKER) -o $(ASM_DIR)/bootloader.elf $(ASM_DIR)/bootloader.o

	@echo "[3/4] Creating binary"
	$(OBJCOPY) -O binary $(ASM_DIR)/bootloader.elf $(ASM_DIR)/bootloader.bin

	@echo "[4/4] Converting to rom.hex"
	od -An -tx4 -v -w4 $(ASM_DIR)/bootloader.bin | sed 's/^[ \t]*//' > $(ROM_HEX)

# === [2] Bluespec Simulation Build ===
bsim: $(BUILD_DIR)/$(EXE)

$(BUILD_DIR)/$(EXE): $(wildcard $(SRC_DIR)/**/*.bsv) $(SRC_DIR)/*.bsv | $(BUILD_DIR)
	@echo "[BSV] Compiling Bluespec modules"
	bsc $(BSC_FLAGS) -u -g $(TOP) $(SRC_DIR)/AetheronTop.bsv
	bsc $(BSC_FLAGS) -e $(TOP) -o $(BUILD_DIR)/$(EXE)

# === [3] Run Simulation ===
run: all bsim
	@echo "[SIM] Launching simulation..."
	./$(BUILD_DIR)/$(EXE)

# -------- UTILITY --------

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(HEX_DIR):
	mkdir -p $(HEX_DIR)

clean:
	rm -rf $(BUILD_DIR) $(HEX_DIR)
	rm -f $(ASM_DIR)/*.o $(ASM_DIR)/*.elf $(ASM_DIR)/*.bin