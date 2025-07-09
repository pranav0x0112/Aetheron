    .section .text
    .globl _start

_start:
    li t0, 0x00000100       # Source: ROM offset of payload
    li t1, 0x80000000       # Destination: RAM base address

copy_loop:
    lw t2, 0(t0)
    sw t2, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    bnez t2, copy_loop      # Stop when word == 0

    li t0, 0x80000000
    jr t0                   # Jump to RAM