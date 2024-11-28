* = $0800
.cpu "w65c02"

jmp main

LINE_BUF      .word LINE_BUFFER.buffer        ; 3
LEN           .word LINE_BUFFER.len           ; 5
BYTES_WRITTEN .word line.COPY_RES.byteCounter ; 7

.include "zeropage.asm"
.include "arith16.asm"
.include "setup.asm"
.include "memory.asm"
.include "search.asm"
.include "line.asm"

main
    jsr setup.mmu
    jsr line.initCopyRes
    jsr line.initMMU
    jsr line.cleanUpLine
    php
    jsr line.restoreMMU
    plp
    brk