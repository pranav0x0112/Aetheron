    .section .text
    .globl _start

_start:
    lui x1, 0x80001      # UART MMIO base = 0x8000_0000
    addi  x2, x0, 'A'      # ASCII 'A'
    nop
    sw    x2, 0(x1)        # write 'A' to UART data register

loop:
    j     loop             # idle forever