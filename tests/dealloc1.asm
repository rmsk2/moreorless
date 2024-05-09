* = $0800
.cpu "w65c02"

HELP_PTR = $30

jmp main

PAGE_MAP .word memory.MEM_STATE.pageMap ; 3
ADDR     .word 0                        ; 5
MASK     .byte 0                        ; 7 
SET      .byte 0                        ; 8
STATE    .word memory.MEM_STATE         ; 9


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"


main
    jsr setup.mmu
    jsr memory.init

    ; set position
    #move16Bit ADDR, memory.FREE_POS.address
    lda MASK
    sta memory.FREE_POS.mask

    lda SET
    beq notSet
    ; set bit in block map
    #move16Bit ADDR, HELP_PTR
    ldx MASK
    lda memory.BIT_MASKS, x
    sta (HELP_PTR)
    ; decrement numFreeBlocks
    #dec16Bit memory.MEM_STATE.numFreeBlocks
notSet
    ; call routine to test
    jsr memory.markBlockFree
    brk