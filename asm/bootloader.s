/* bootloader.s : copy payload from ROM to RAM and jump */

    .section .text
    .globl _start

_start:
    /* Load absolute addresses without la pseudo ------------- */
    lui   t0, %hi(_payload_src)     # t0 = upper 20 bits
    addi  t0, t0, %lo(_payload_src)

    lui   t2, %hi(_payload_end)
    addi  t2, t2, %lo(_payload_end)

    lui   t1, 0x80000               # t1 = 0x8000_0000 (RAM base)

copy_loop:
    lw    t3, 0(t0)
    sw    t3, 0(t1)
    addi  t0, t0, 4
    addi  t1, t1, 4
    bltu  t0, t2, copy_loop

    /* Jump to RAM start (0x8000_0000) ----------------------- */
    jalr  x0, t1, 0                 # jr t1

    /* Should never reach here */
    j _start

    .size _start, . - _start