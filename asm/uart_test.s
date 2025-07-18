.section .text
    .globl test_start

test_start:
    lui x1, 0x40001      # UART MMIO base = 0x80001000
    addi x2, x0, 'A'     # ASCII 'A'
    nop
    sw x2, 0(x1)         # write 'A' to UART data register

loop:
    j loop               # idle forever