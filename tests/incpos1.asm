* = $0800
.cpu "w65c02"

DATA_PTR = $30

jmp main

ITERATION .byte 0
MEM_STATE .word memory.MEM_STATE
PAGE_MAP  .word memory.MEM_STATE.pageMap
BLOCK .byte 0
PAGE  .byte 0
ADDR  .word 0
MASK  .byte 0


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"


main
    lda ITERATION
    cmp #1
    bne _noInit
    jsr setup.mmu
    jsr memory.init

_noInit
    ; set position
    lda BLOCK
    sta memory.MEM_STATE.blockPos
    lda PAGE
    sta memory.MEM_STATE.blockPos + 1
    #move16Bit ADDR, memory.MEM_STATE.mapPos.address
    lda MASK
    sta memory.MEM_STATE.mapPos.mask

    ; call routine to test
    jsr memory.incBlockPosCtr
    brk