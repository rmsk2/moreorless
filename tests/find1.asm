* = $0800
.cpu "w65c02"

jmp main

PAGE_MAP   .word memory.MEM_STATE.pageMap
ADDRESS    .word ?
MASK       .byte ?
MEM_STATE  .word memory.MEM_STATE

.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"

main
    jsr setup.mmu
    jsr memory.init

    ; mark all blocks as allocated
    lda #$FF
    sta memory.MEM_SET.valToSet
    #load16BitImmediate memory.MEM_STATE.pageMap, memory.MEM_SET.startAddress
    #load16BitImmediate PAGE_MAP_LEN, memory.MEM_SET.length
    jsr memory.memSet

    ; free exactly one block
    #move16Bit ADDRESS, TXT_PTR1
    lda (TXT_PTR1)
    and MASK
    sta (TXT_PTR1)

    ; see whether we find it
    jsr memory.searchFreeBlock
    brk