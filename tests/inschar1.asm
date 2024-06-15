* = $0800
.cpu "w65c02"

jmp main

LINE_BUF .word LINE_BUFFER

.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"
.include "line.asm"

main
    pha
    lda #80
    sta memory.INS_PARAM.maxLength
    #load16BitImmediate LINE_BUFFER.buffer, MEM_PTR1
    pla
    jsr memory.insertCharacterGrow
    lda memory.INS_PARAM.curLength
    brk