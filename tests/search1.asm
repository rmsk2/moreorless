* = $0800
.cpu "w65c02"

jmp main

SEARCH_BUF .word SEARCH_BUFFER       ; 3
LINE_BUF   .word LINE_BUFFER         ; 5
LEN        .byte LINE_BUFFER_LEN + 1 ; 7

.include "zeropage.asm"
.include "arith16.asm"
.include "setup.asm"
.include "memory.asm"
.include "line.asm"
.include "search.asm"

main
    jsr search.TextFromStart
    brk
