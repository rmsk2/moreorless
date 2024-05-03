NUM_PAGES_SIMPLE = 48
NUM_PAGES_RAM_EXP = NUM_PAGES_SIMPLE + 32
BLOCK_SIZE = 32
PAGE_SIZE = 8192

FarPtr_t .struct
    lo   .byte 0
    hi   .byte 0
    page .byte 0
.endstruct

MainMem_t .struct
    addrPageMap   .word 0
    numPages      .byte 0
    numFreeBlocks .word 0
    ramExpFound   .byte 0
    numToPage     .fill NUM_PAGES_RAM_EXP
    pageToNum     .fill NUM_PAGES_RAM_EXP
    pageMap       .fill NUM_PAGES_RAM_EXP * (PAGE_SIZE / BLOCK_SIZE) / 8
.endstruct

memory .namespace

MEM_STATE .dstruct MainMem_t

init
    lda #0
    sta MEM_STATE.ramExpFound
    jsr setup.checkForRamExpansion
    bcs _noRamExp
    inc MEM_STATE.ramExpFound
_noRamExp
    rts

.endnamespace