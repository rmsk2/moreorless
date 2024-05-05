* = $0800
.cpu "w65c02"

jmp main


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"


main
    jsr memory.findFirstZeroBit
    brk