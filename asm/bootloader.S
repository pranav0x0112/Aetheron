.section .text
.globl _start
.global _global_pointer$
_global_pointer$ = 0

_start:
    lui   sp, 0x80000
    addi  sp, sp, -4

    la    gp, _global_pointer$
    
    la    t0, _payload_rom_start     # ROM copy source
    la    t1, _payload_ram_start     # RAM destination (same as VMA)
    la    t2, _payload_rom_end       # ROM copy end
    la    t4, _payload_ram_start     # t4 = jump target

copy_loop:
    lw    t3, 0(t0)
    sw    t3, 0(t1)
    addi  t0, t0, 4
    addi  t1, t1, 4
    bltu  t0, t2, copy_loop

    jr    t4