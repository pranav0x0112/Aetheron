# ========================
# -------- CONFIG --------
# ========================

TOP          ?= mkAetheronTop

SRC_DIR      := src
ASM_DIR      := asm
C_DIR        := c_src
LD_DIR       := linker
HEX_DIR      := hex
BUILD_DIR    := build
EXE          := sim

BOOT_S       := $(ASM_DIR)/bootloader.S
BOOT_LD      := $(LD_DIR)/boot.ld
RAM_LD       := $(LD_DIR)/ram.ld

PAYLOAD_SRC  ?= $(C_DIR)/main.c

# -------- Toolchain --------
RISCV_PREFIX ?= riscv64-elf
CC      := $(RISCV_PREFIX)-gcc
LD      := $(RISCV_PREFIX)-ld
OBJCOPY := $(RISCV_PREFIX)-objcopy

RISCV_ARCH ?= rv32im_zifencei
RISCV_ABI  ?= ilp32

# -------- Flags --------
CFLAGS  := -march=$(RISCV_ARCH) -mabi=$(RISCV_ABI) \
           -ffreestanding -nostdlib -Wall -Wextra \
           -I$(C_DIR)/include
ASFLAGS := -march=$(RISCV_ARCH) -mabi=$(RISCV_ABI) -c
LDFLAGS := -m elf32lriscv

# -------- Bluespec Flags --------
BSC_FLAGS := -sim \
             -p +:$(SRC_DIR) \
             -p +:$(SRC_DIR)/TileLinkPkg \
             -p +:$(SRC_DIR)/PeripheralsPkg \
             -p +:$(SRC_DIR)/MemoryPkg \
             -bdir $(BUILD_DIR) \
             -info-dir $(BUILD_DIR)

# -------- Derived Artifacts --------
BOOT_OBJ       := $(BUILD_DIR)/bootloader.o
CRT0_OBJ       := $(BUILD_DIR)/crt0.o
MAIN_OBJ       := $(BUILD_DIR)/main.o
PAYLOAD_ELF    := $(BUILD_DIR)/payload.elf
PAYLOAD_BIN    := $(BUILD_DIR)/payload.bin
PAYLOAD_WRAP_S := $(BUILD_DIR)/payload_wrapper.S
PAYLOAD_OBJ    := $(BUILD_DIR)/payload.o
BOOT_ELF       := $(BUILD_DIR)/boot.elf
ROM_HEX        := $(HEX_DIR)/rom.hex
SIM_EXE        := $(BUILD_DIR)/$(EXE)

# ========================
# -------- TARGETS -------
# ========================

.PHONY: all run asm-run bsim clean

all: $(ROM_HEX)

# -------- 1. Payload (C or ASM) --------
ifeq ($(suffix $(PAYLOAD_SRC)),.c)   # C path

$(CRT0_OBJ): c_src/crt0.S | $(BUILD_DIR)
	@echo "[C   ] Compiling crt0.o"
	$(CC) $(CFLAGS) -c $< -o $@

$(MAIN_OBJ): $(PAYLOAD_SRC) | $(BUILD_DIR)
	@echo "[C   ] Compiling main payload"
	$(CC) $(CFLAGS) -c $< -o $@

$(PAYLOAD_ELF): $(CRT0_OBJ) $(MAIN_OBJ) $(RAM_LD)
	@echo "[LD  ] Linking payload.elf"
	$(LD) $(LDFLAGS) -T $(RAM_LD) -o $@ $(CRT0_OBJ) $(MAIN_OBJ)

$(PAYLOAD_BIN): $(PAYLOAD_ELF)
	@echo "[BIN ] Extract raw binary"
	$(OBJCOPY) -O binary $< $@

$(PAYLOAD_WRAP_S): $(PAYLOAD_BIN)
	@echo "[WRAP] Emit wrapper assembly"
	printf '.section .payload, \"a\"\n.incbin \"%s\"\n' "$<" > $@

$(PAYLOAD_OBJ): $(PAYLOAD_WRAP_S)
	@echo "[ASM ] Assemble wrapper"
	$(CC) $(ASFLAGS) -o $@ $<

else  # ASM path

$(PAYLOAD_OBJ): $(PAYLOAD_SRC) | $(BUILD_DIR)
	@echo "[ASM ] Assembling payload: $<"
	$(CC) $(ASFLAGS) -o $(BUILD_DIR)/payload_tmp.o $<
	@echo "[REMAP] Rename .text → .payload"
	$(OBJCOPY) --rename-section .text=.payload $(BUILD_DIR)/payload_tmp.o $@

endif

# -------- 2. Bootloader --------

$(BOOT_OBJ): $(BOOT_S) | $(BUILD_DIR)
	@echo "[ASM ] Assembling bootloader"
	$(CC) $(ASFLAGS) -o $@ $<

$(BOOT_ELF): $(BOOT_OBJ) $(PAYLOAD_OBJ) $(BOOT_LD)
	@echo "[LD  ] Linking boot.elf (ROM image)"
	$(LD) $(LDFLAGS) -T $(BOOT_LD) -o $@ $(BOOT_OBJ) $(PAYLOAD_OBJ)

# -------- 3. ELF ➜ ROM HEX --------

$(ROM_HEX): $(BOOT_ELF) | $(HEX_DIR)
	@echo "[HEX ] Generating ROM HEX"
	$(OBJCOPY) -O binary --gap-fill 0x00 $< $(BUILD_DIR)/rom.bin
	dd if=$(BUILD_DIR)/rom.bin of=$(BUILD_DIR)/rom_padded.bin bs=32768 count=1 conv=sync
	od -An -tx4 -w4 -v $(BUILD_DIR)/rom_padded.bin | sed 's/^[ \t]*//' > $@

# -------- 4. Bluespec Simulation --------

bsim: $(SIM_EXE)

$(SIM_EXE): $(wildcard $(SRC_DIR)/**/*.bsv) $(SRC_DIR)/*.bsv | $(BUILD_DIR)
	@echo "[BSV ] Compiling Bluespec"
	bsc $(BSC_FLAGS) -u -g $(TOP) $(SRC_DIR)/AetheronTop.bsv
	bsc $(BSC_FLAGS) -e $(TOP) -o $@

# -------- 5. Simulation Run --------

run: all bsim
	@echo "[SIM ] Launching"
	./$(SIM_EXE)

asm-run:
	$(MAKE) run PAYLOAD_SRC=$(ASM_DIR)/uart_test.s

# -------- Utility --------

$(BUILD_DIR) $(HEX_DIR):
	mkdir -p $@

clean:
	rm -rf $(BUILD_DIR) $(HEX_DIR)