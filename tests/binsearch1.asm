
* = $0800
.cpu "w65c02"

jmp main

LEN  .byte 0              ; 3
DATA .fill 256            ; 4

.include "zeropage.asm"
.include "zp_data.asm"
.include "arith16.asm"
.include "bin_search.asm"


main
    pha
    phx
    #load16BitImmediate DATA, KEY_SEARCH_PTR
    lda LEN
    sta BIN_STATE.numEntries
    plx
    pla
    jsr binsearch.searchEntry
    brk
