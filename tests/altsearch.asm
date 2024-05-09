* = $0800
.cpu "w65c02"

HELP_PTR = $30

jmp main

STATE    .word memory.MEM_STATE         ; 3


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"

TEMP .dstruct FarPtr_t

main
    jsr setup.mmu
    jsr memory.init

    ; allocate the first 512 blocks
    #load16BitImmediate memory.MEM_STATE.pageMap, HELP_PTR
    ldy #0
    lda #$FF
_loop
    sta (HELP_PTR), y
    iny
    cpy #64
    bne _loop
    ; Adapt number of free blocks
    #sub16BitImmediate 512, memory.MEM_STATE.numFreeBlocks

    ; we are at block 0 on page 0. Try to allocate a new block. The next
    ; free one is block 0 on page 2.
    #load16BitImmediate TEMP, MEM_PTR3
    jsr memory.allocPtr
    brk