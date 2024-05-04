NUM_PAGES_SIMPLE = 48
NUM_PAGES_RAM_EXP = NUM_PAGES_SIMPLE + 32
; block sizes of 32, 64 and 128 bytes are supported
BLOCK_SIZE = 32
BLOCK_MASK = $FF
BLOCK_SHIFTS = 5
PAGE_SIZE = 8192
BLOCKS_PER_PAGE = PAGE_SIZE / BLOCK_SIZE
PAGE_MAP_LEN = NUM_PAGES_RAM_EXP * BLOCKS_PER_PAGE / 8

PAGE_WINDOW = $A000

FarPtr_t .struct
    lo   .byte 0
    hi   .byte 0
    page .byte 0
.endstruct

MainMem_t .struct
    addrPageMap   .word PAGE_WINDOW
    numPages      .byte NUM_PAGES_RAM_EXP
    numFreeBlocks .word NUM_PAGES_RAM_EXP * BLOCKS_PER_PAGE
    numBlocks     .word NUM_PAGES_RAM_EXP * BLOCKS_PER_PAGE
    maxBlockPos   .byte 0, NUM_PAGES_RAM_EXP
    blockPos      .word 0
    ramExpFound   .byte 0
    pages         .fill NUM_PAGES_RAM_EXP
    pageMap       .fill PAGE_MAP_LEN
.endstruct

memory .namespace

MEM_STATE .dstruct MainMem_t

MemSet_t .struct 
    valToSet     .byte ?
    startAddress .word ?
    length       .word ?
.endstruct

MEM_SET .dstruct MemSet_t


memSet
    #move16Bit MEM_SET.startAddress, MEM_PTR1
memSetInt
    ldy #0
_set
    ; MEM_SET.length + 1 contains the number of full blocks
    lda MEM_SET.length + 1
    beq _lastBlockOnly
    lda MEM_SET.valToSet
_setBlock
    sta (MEM_PTR1), y
    iny
    bne _setBlock
    dec MEM_SET.length + 1
    inc MEM_PTR1+1
    bra _set

    ; Y register is zero here
_lastBlockOnly
    ; MEM_SET.length contains the number of bytes in last block
    lda MEM_SET.length
    beq _done
    lda MEM_SET.valToSet
_loop
    sta (MEM_PTR1), y
    iny
    cpy MEM_SET.length
    bne _loop
_done
    rts


MemCpy_t .struct 
    startAddress  .word ?
    targetAddress .word ?
    length        .word ?
.endstruct

MEM_CPY .dstruct MemCpy_t


; works only for non overlapping slices of memory
memCpy
    #move16Bit MEM_CPY.startAddress, MEM_PTR1
    #move16Bit MEM_CPY.targetAddress, MEM_PTR2
memCpyInt    
    ldy #0
_copy
    ; MEM_CPY.length + 1 contains the number of full blocks
    lda MEM_CPY.length + 1
    beq _lastBlockOnly
_copyBlock
    lda (MEM_PTR1), y
    sta (MEM_PTR2), y
    iny
    bne _copyBlock
    dec MEM_CPY.length + 1
    inc MEM_PTR1+1
    inc MEM_PTR2+1
    bra _copy

    ; Y register is zero here
_lastBlockOnly
    ; MEM_CPY.length contains the number of bytes in last block
    lda MEM_CPY.length
    beq _done
_loop
    lda (MEM_PTR1), y
    sta (MEM_PTR2), y
    iny
    cpy MEM_CPY.length
    bne _loop
_done
    rts


initPageBytes
    ; page bytes (16-63) for memory from $020000 - $07FFFF
    lda #16
    ldy #0
_loop1
    sta MEM_STATE.pages, y
    ina
    iny
    cpy #48
    bne _loop1

    ; page bytes (128-159) for memory from $100000 - $13FFFF
    ; i.e. the RAM expansion cartridge
    lda #128
    ldy #0
_loop2
    sta MEM_STATE.pages, y
    ina
    iny
    cpy #32
    bne _loop2

    rts

blockShifts5 .macro
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
.endmacro

blockShifts6 .macro
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
.endmacro

blockShifts7 .macro
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
    #double16Bit BLOCK_POS_TEMP
.endmacro


BLOCK_POS_TEMP .word 0
; MEM_PTR3 points to target far ptr.
blockPosToFarPtr
    ldx MEM_STATE.blockPos + 1
    lda MEM_STATE.pages, x
    ldy #FarPtr_t.page
    sta (MEM_PTR3), y
    stz BLOCK_POS_TEMP + 1
    lda MEM_STATE.blockPos
    sta BLOCK_POS_TEMP
    ; Do more shifts for bigger blocks. 
    ; Change here when block size increases
    #blockShifts5
    lda BLOCK_POS_TEMP
    ldy #FarPtr_t.lo
    sta (MEM_PTR3), y
    clc
    lda BLOCK_POS_TEMP + 1
    adc #>PAGE_WINDOW
    iny
    sta (MEM_PTR3), y
    rts


farPtrToBlockPos
    rts


blockPosToMapBit
    rts


incBlockPosCtr
    lda MEM_STATE.blockPos
    ina
    and #BLOCK_MASK
    beq _carryOccured
    bra _noCarry
_carryOccured
    inc MEM_STATE.blockPos + 1
_noCarry
    sta MEM_STATE.blockPos
    #cmp16Bit MEM_STATE.blockPos, MEM_STATE.maxBlockPos
    bne _done
    ; wrap around. Max block was reached.
    #load16BitImmediate 0, MEM_STATE.blockPos
_done
    rts


; block_pos => FarPtr
; block_pos => map bit
; FarPtr => map bit

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
    ; calc number of available blocks with or without RAM expansion
    lda MEM_STATE.numPages
    sta $DE00
    stz $DE01
    #load16BitImmediate BLOCKS_PER_PAGE, $DE02
    #move16Bit $DE10, MEM_STATE.numFreeBlocks
    #move16Bit $DE10, MEM_STATE.numBlocks

    lda MEM_STATE.numPages
    sta MEM_STATE.maxBlockPos + 1
    stz MEM_STATE.maxBlockPos

    ; clear MEM_STATE.pageMap
    stz MEM_SET.valToSet
    #load16BitImmediate MEM_STATE.pageMap, MEM_SET.startAddress
    #load16BitImmediate PAGE_MAP_LEN, MEM_SET.length
    jsr memSet

    ; reset current block position
    stz MEM_STATE.blockPos
    stz MEM_STATE.blockPos+1

    ; list all page identifiers which are available to this module
    jsr initPageBytes

    rts

.endnamespace