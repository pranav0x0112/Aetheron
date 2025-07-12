    .section .text
    .globl _start

_start:
    # t0 = ROM src ptr  (_payload_src)
    lui   t0, %hi(_payload_src)
    addi  t0, t0, %lo(_payload_src)

    # t2 = ROM end ptr  (_payload_end)
    lui   t2, %hi(_payload_end)
    addi  t2, t2, %lo(_payload_end)

    # t1 = RAM dst ptr  (0x8000_0000)
    lui   t1, 0x80000          

copy_loop:
    lw    t3, 0(t0)
    sw    t3, 0(t1)
    addi  t0, t0, 4
    addi  t1, t1, 4
    bltu  t0, t2, copy_loop    

    # Jump to RAM entry (0x8000_0000)
    jalr  x0, t1, 0

hang:
    j hang                     # never return

    .size _start, . - _start