* = $0800
.cpu "w65c02"

DATA_PTR = $30

jmp main

BLOCK_NR   .byte 0
PAGE_NR    .byte 0

.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"

TEST_PTR .dstruct FarPtr_t

main
    jsr setup.mmu
    jsr memory.init

    ldx PAGE_NR
    lda memory.MEM_STATE.pages, x
    sta memory.MEM_STATE.blockPos + 1
    lda BLOCK_NR
    sta memory.MEM_STATE.blockPos
    
    #load16BitImmediate TEST_PTR, MEM_PTR3
    jsr memory.blockPosToFarPtr

    lda TEST_PTR.page
    sta MMU_REG
    #move16Bit TEST_PTR, DATA_PTR

    ldy #0
_loop
    tya
    sta (DATA_PTR), y
    iny
    cpy #BLOCK_SIZE
    bne _loop

    brk