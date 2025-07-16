.section .text
.global payload_start
payload_start:

    lui t0, %hi(0x80001000)
    addi t0, t0, %lo(0x80001000)
    li   t1, 0xCAFEBABE
    sw   t1, 0(t0)
    call main
    j .