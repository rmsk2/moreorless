* = $0800
.cpu "w65c02"

jmp main

STATE_ADDR .word memory.MEM_STATE

.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"


main
    jsr setup.mmu
    jsr memory.init
    brk