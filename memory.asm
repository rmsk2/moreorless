NUM_PAGES_SIMPLE = 48
NUM_PAGES_RAM_EXP = NUM_PAGES_SIMPLE + 32
BLOCK_SIZE = 32
PAGE_SIZE = 8192
BLOCKS_PER_PAGE = PAGE_SIZE / BLOCK_SIZE

PAGE_WINDOW = $A000

FarPtr_t .struct
    lo   .byte 0
    hi   .byte 0
    page .byte 0
.endstruct

MainMem_t .struct
    addrPageMap   .word PAGE_WINDOW
    numPages      .byte NUM_PAGES_SIMPLE
    numFreeBlocks .word NUM_PAGES_SIMPLE * BLOCKS_PER_PAGE
    ramExpFound   .byte 0
    numToPage     .fill NUM_PAGES_RAM_EXP
    pageToNum     .fill NUM_PAGES_RAM_EXP
    pageMap       .fill NUM_PAGES_RAM_EXP * (PAGE_SIZE / BLOCK_SIZE) / 8
.endstruct

memory .namespace

MEM_STATE .dstruct MainMem_t

init
    ; assume no RAM expansion
    stz MEM_STATE.ramExpFound
    ; set default for number of pages
    lda #NUM_PAGES_SIMPLE
    sta MEM_STATE.numPages

    jsr setup.checkForRamExpansion
    bcs _noRamExp
    ; record that RAM explansion is present
    inc MEM_STATE.ramExpFound
    ; Increase number of available pages
    lda #NUM_PAGES_RAM_EXP
    sta MEM_STATE.numPages
_noRamExp
    lda MEM_STATE.numPages
    sta $DE00
    stz $DE01
    #load16BitImmediate BLOCKS_PER_PAGE, $DE02
    #move16Bit $DE10, MEM_STATE.numFreeBlocks
    rts

.endnamespace