# Aetheron: A RISC-V SoC in Bluespec

**Aetheron** is a simulation-based RISC-V SoC built from scratch in Bluespec SystemVerilog. It supports real C programs, has a TileLink-lite interconnect, and features basic peripherals like UART, GPIO, and Timer — all memory-mapped and testable via simulation.

> Read the full journey: [aetheron-soc.hashnode.dev](https://aetheron-soc.hashnode.dev/aetheron-bringing-my-own-soc-to-life)

## Features

- Pipelined RV32I core
- Boot-from-ROM with C payloads loaded into RAM
- TileLink-lite interconnect
- Memory-mapped UART, GPIO, and Timer
- Clean C/ASM toolchain with linker script support
- Fully simulation-based (no FPGA needed)


## Getting Started

### Requirements

- Bluespec compiler (`bsc`)
- Verilator
- RISC-V GCC toolchain (`riscv64-elf-gcc`)

### Run a C program

```bash
make clean
make run PAYLOAD_SRC=c_src/tests/your_file.c
```

## Memory Map

![Aetheron-Memory-Map](/misc/memory-map.png)

