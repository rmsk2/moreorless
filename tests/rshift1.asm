
* = $0800
.cpu "w65c02"

jmp main

BUFFER .text "01234567890123456789012345678901234567890123456789012345678901234567890123456789"

.include "zeropage.asm"
.include "arith16.asm"
.include "setup.asm"
.include "memory.asm"

main
    #load16BitImmediate BUFFER, MEM_PTR1
    lda #0
    ldy #size(BUFFER)
    jsr memory.vecShiftRight
    brk
