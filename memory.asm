NUM_PAGES_SIMPLE = 48
NUM_PAGES_RAM_EXP = NUM_PAGES_SIMPLE + 32
; block sizes of 32, 64 and 128 bytes are supported
BLOCK_SIZE = 32
BLOCK_MASK = $FF
PAGE_SIZE = 8192
BLOCKS_PER_PAGE = PAGE_SIZE / BLOCK_SIZE
; number of bytes needed to represent a page in the pageMap
BYTES_PER_PAGE = BLOCKS_PER_PAGE / 8
PAGE_MAP_LEN = NUM_PAGES_RAM_EXP * BYTES_PER_PAGE

PAGE_WINDOW = $A000
MMU_REG = (PAGE_WINDOW / PAGE_SIZE) + 8

FarPtr_t .struct
    lo   .byte 0
    hi   .byte 0
    page .byte 0
.endstruct

MapBit_t .struct 
    address .word 0
    mask    .byte 0
.endstruct

MainMem_t .struct
    addrPageMap   .word PAGE_WINDOW
    numPages      .byte NUM_PAGES_SIMPLE
    pageMapLen    .word 0
    numFreeBlocks .word NUM_PAGES_SIMPLE * BLOCKS_PER_PAGE
    numBlocks     .word NUM_PAGES_SIMPLE * BLOCKS_PER_PAGE
    maxBlockPos   .byte 0, NUM_PAGES_SIMPLE
    blockPos      .word 0
    ramExpFound   .byte 0
    mapPos        .dstruct MapBit_t
    pages         .fill NUM_PAGES_RAM_EXP
    pageMap       .fill PAGE_MAP_LEN
.endstruct

ENTER_ZP .macro ptr
    pha
    phy
    ldy #FarPtr_t.page
    lda (\ptr), y
    sta MMU_REG
    ply
    pla
.endmacro

ENTER_ADDR .macro ptr
    pha
    lda \ptr + FarPtr_t.page
    sta MMU_REG
    pla
.endmacro

IS_NIL_ADDR .macro addr
    lda \addr.page
.endmacro


LEAVE_ZP .macro ptr
    ; nothing at the moment
.endmacro

LEAVE_ADDR .macro ptr
    ; nothing at the moment
.endmacro

copyMem2Mem .macro src, target
    lda \src.lo
    sta \target.lo
    lda \src.hi
    sta \target.hi
    lda \src.page
    sta \target.page
.endmacro


copyPtr2Mem .macro ptr, index, target
    ldy #\index
    lda (\ptr), y
    sta \target.lo
    iny
    lda (\ptr), y
    sta \target.hi
    iny
    lda (\ptr), y
    sta \target.hi
.endmacro


copyMem2Ptr .macro source, ptr, index
    ldy #\index
    lda \source.lo
    sta (\ptr), y
    iny
    lda \source.hi
    sta (\ptr), y
    iny
    lda \source.page
    sta (\ptr), y
.endmacro

NIL   .dstruct FarPtr_t

memory .namespace

BIT_MASKS .byte 1, 2, 4, 8, 16, 32, 64, 128
MEM_STATE .dstruct MainMem_t

MemSet_t .struct 
    valToSet     .byte ?
    startAddress .word ?
    length       .word ?
.endstruct

MEM_SET .dstruct MemSet_t

; parameters in MEM_SET
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

; parameters in MEM_CPY
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
_loop2
    sta MEM_STATE.pages, y
    ina
    iny
    cpy #NUM_PAGES_RAM_EXP
    bne _loop2

    rts


BLOCK_POS_TEMP .word 0
; MEM_PTR3 points to target far ptr.
blockPosToFarPtr
    ;
    ; determine page number
    ;
    ldx MEM_STATE.blockPos + 1
    lda MEM_STATE.pages, x
    ldy #FarPtr_t.page
    sta (MEM_PTR3), y
    ;
    ; determine physical address in PAGE_WINDOW
    ;
    stz $DE01
    lda MEM_STATE.blockPos
    sta $DE00
    #load16BitImmediate BLOCK_SIZE, $DE02
    ; Mutliply by BLOCK_SIZE
    
    ; $DE10/$DE11 now contains the offset into the PAGE_WINDOW
    ; which represents the first byte of the block
    ;
    ; Now add address of PAGE_WINDOW to complete the calculation
    lda $DE10
    ldy #FarPtr_t.lo
    sta (MEM_PTR3), y
    ; Adding hi byte is enough as lo byte is expected
    ; to be zero
    clc
    lda $DE11
    adc #>PAGE_WINDOW
    iny
    sta (MEM_PTR3), y
    rts


ADDR_HELP .word ?
; MEM_PTR3 has to point to far pointer
; After calling this routine FREE_POS is filled
; with the information to identify the bit in the
; block map which is rsponsible for the far pointer
; carry is clear if FREE_POS was filled.
farPtrToMapBit
    ; search for page number in MEM_STATE.pages
    ldy #FarPtr_t.page
    lda (MEM_PTR3), y
    ldx #0
_loop
    cmp MEM_STATE.pages, x
    beq _found
    inx
    cpx MEM_STATE.numPages
    bne _loop
    ; do nothing if page was not found
    sec
    rts
_found
    ; page was found. Index is in X register
    stx $DE00
    stz $DE01
    #load16BitImmediate BYTES_PER_PAGE, $DE02
    #move16Bit $DE10, BLOCK_POS_TEMP
    ; now BLOCK_POS_TEMP contains the offset of the first byte in the
    ; block map that belongs to the page determined above
    ;
    ; load address of far pointer to which MEM_PTR3 points to ADDR_HELP
    ldy #FarPtr_t.lo
    lda (MEM_PTR3), y
    sta ADDR_HELP
    iny
    lda (MEM_PTR3), y
    sta ADDR_HELP + 1
    ;
    ; determine offset in page
    ;
    #sub16BitImmediate PAGE_WINDOW, ADDR_HELP
    ;
    ; divide offset by BLOCK_SIZE => $DE14 contains number of block in page
    #move16Bit ADDR_HELP, $DE06
    #load16BitImmediate BLOCK_SIZE, $DE04

    ; Only $DE14 is relevant as the minimum block size is 32 byte,
    ; which in turn means that the block number fits in one byte
    ; as 8192 / 32 = 256
    lda $DE14
    ; calculate block number mod 8 (bits per byte)
    and #%00000111
    ; bit in page map
    sta FREE_POS.mask
    lda $DE14
    ; divide block number by 8 (bits per byte)
    lsr
    lsr
    lsr
    ; now the accu contains the offset of the byte in
    ; the block map
    ;
    ; Add base offset that represents the whole page in pageMap
    clc
    adc BLOCK_POS_TEMP
    sta BLOCK_POS_TEMP
    lda #0
    adc BLOCK_POS_TEMP+1
    ; now BLOCK_POS contains the offset of the byte in 
    ; the page/block map
    ;
    ; finally add base address of pageMap
    #load16BitImmediate MEM_STATE.pageMap, FREE_POS.address
    #add16Bit BLOCK_POS_TEMP, FREE_POS.address
    clc
    rts


; input byte to search in accu
; after return the accu contains the position (0...7) of the
; first zero bit. 
;
; There has to be at least one zero bit for
; this routine to work correctly.
findFirstZeroBit
    ldx #0
_loop
    lsr
    bcc _done
    inx
    bra _loop
_done    
    txa
    rts


; this routine moves MEM_STATE.blockPos and MEM_STATE.mapPos to
; a position which contains a free block, which is known to exist.
SEARCH_LEN .word 0
searchFreeBlock
    #move16Bit MEM_STATE.pageMapLen, SEARCH_LEN
    #load16BitImmediate MEM_STATE.pageMap, MEM_PTR1
    ldy #0
_search
    ; SEARCH_LEN + 1 contains the number of full blocks the
    ; pageMap uses
    lda SEARCH_LEN + 1
    beq _lastBlockOnly
_searchBlock
    lda (MEM_PTR1), y
    cmp #$FF
    bne _blockFound
    iny
    bne _searchBlock
    dec SEARCH_LEN + 1
    inc MEM_PTR1 + 1
    bra _search
    ; Y register is zero here
_lastBlockOnly
    ; SEARCH_LEN contains the number of bytes in last block
    lda SEARCH_LEN
    beq _notFound
_loop
    lda (MEM_PTR1), y
    cmp #$FF
    bne _blockFound
    iny
    cpy SEARCH_LEN
    bne _loop
_notFound
    ; due to the precondition that a free block must exist we should never
    ; end up here    
    rts
    ; we have found a block. Now set MEM_STATE.mapPos and 
    ; MEM_STATE.blockPos to the position of the found block.
_blockFound
    ;
    ; calculate MEM_STATE.mapPos
    ;
    tya
    clc
    adc MEM_PTR1
    sta MEM_PTR1
    lda #0
    adc MEM_PTR1 + 1
    sta MEM_PTR1 + 1
    ; MEM_PTR1 now contains the address of the byte which contains the
    ; bit for the free block
    lda (MEM_PTR1)
    jsr findFirstZeroBit
    sta MEM_STATE.mapPos.mask    
    #move16Bit MEM_PTR1, MEM_STATE.mapPos.address
    ;
    ; calculate MEM_STATE.blockPos
    ;
    #sub16BitImmediate MEM_STATE.pageMap, MEM_PTR1
    ; Now MEM_PTR1 contains the offset into the block map to 
    ; the byte which represents the found free block
    ; 
    ; calculate (OFFSET_INTO_MAP div BYTES_PER_PAGE) and (OFFSET_INTO_MAP mod BYTES_PER_PAGE)
    #load16BitImmediate BYTES_PER_PAGE, $DE04
    #move16Bit MEM_PTR1, $DE06
    ; contains lo byte of division result, i.e. the number of the
    ; page
    lda $DE14
    sta MEM_STATE.blockPos + 1
    ; contains lo byte of remainder, i.e. the number of the byte representing the block in the 
    ; page
    lda $DE16
    ; calculate position of block in the page
    ; multiply by 8
    asl
    asl
    asl
    ; add bit pos
    clc
    adc MEM_STATE.mapPos.mask
    sta MEM_STATE.blockPos
    rts    


incBlockPosCtr
    ;
    ; increment map bit position
    ;
    lda MEM_STATE.mapPos.mask
    ina
    and #%00000111
    sta MEM_STATE.mapPos.mask
    bne _incPos
    #inc16Bit MEM_STATE.mapPos.address
_incPos
    ;
    ; increment blockPos
    ;
    lda MEM_STATE.blockPos
    ina
    and #BLOCK_MASK
    bne _noCarry
    inc MEM_STATE.blockPos + 1
_noCarry
    sta MEM_STATE.blockPos
    ;
    ; Check if we have reached the maximun position and need to
    ; do a wrap around.
    ;
    #cmp16Bit MEM_STATE.blockPos, MEM_STATE.maxBlockPos
    bne _done
    ; wrap around. Max block was reached.
    #load16BitImmediate 0, MEM_STATE.blockPos
    ; reset map bit position
    stz MEM_STATE.mapPos.mask
    #load16BitImmediate MEM_STATE.pageMap, MEM_STATE.mapPos.address    
_done
    rts


; carry is set if curent block is free
isCurrentBlockFree
    #move16Bit MEM_STATE.mapPos.address, MEM_PTR4
    ldx MEM_STATE.mapPos.mask
isCurrentBlockFreeInt
    lda (MEM_PTR4)
    and BIT_MASKS, x
    beq _free
    clc
    rts
_free
    sec
    rts


markCurrentBlockUsed
    jsr isCurrentBlockFree
    bcc _done
    ; here MEM_PTR4 points to MEM_STATE.mapPos.address
    ; and x contains MEM_STATE.mapPos.mask
    lda (MEM_PTR4)
    ora BIT_MASKS, x
    sta (MEM_PTR4)
    #dec16Bit MEM_STATE.numFreeBlocks
    ; jump here to prevent the number of free blocks
    ; becoming incorrect
_done
    rts


FREE_POS .dstruct MapBit_t
INVERSE_MASK .byte 0
markBlockFree
    ; check if block which is represented by FREE_POS is already free
    #move16Bit FREE_POS.address, MEM_PTR4
    ldx FREE_POS.mask
    jsr isCurrentBlockFreeInt
    bcs _done
    ; block is currently marked as allocated
    ; => free it and increase number of free blocks
    lda BIT_MASKS, x
    eor #$FF
    sta INVERSE_MASK    
    lda (MEM_PTR4)
    and INVERSE_MASK
    sta (MEM_PTR4)
    #inc16Bit MEM_STATE.numFreeBlocks
    ; jump here to prevent the number of free blocks
    ; becoming incorrect
_done
    rts


; MEM_PTR3 has to point to the far pointer
freePtr
    jsr farPtrToMapBit
    bcs _done
    jsr markBlockFree
_done
    rts


; MEM_PTR3 has to point to a far pointer
; carry is set if alloc failed
allocPtr
    #cmp16BitImmediate 0, MEM_STATE.numFreeBlocks
    beq _outOfMemory
    ; initialize trial counter
    stz TRY_CTR
_checkFree
    jsr isCurrentBlockFree
    bcs _isFree
    inc TRY_CTR
    beq _performSearch
    ; we have still tries left
    jsr incBlockPosCtr
    bra _checkFree
_performSearch
    ; we have tried 256 times to find a free block which did not work.
    ; we now speed things up a bit. There has to be at least one free block
    ; otherwise we would not be here.
    jsr searchFreeBlock
    bra _checkFree
_isFree
    jsr markCurrentBlockUsed
    jsr blockPosToFarPtr
    jsr incBlockPosCtr
    clc
    rts
_outOfMemory
    sec
    rts


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

    ; reset map bit position
    stz MEM_STATE.mapPos.mask
    #load16BitImmediate MEM_STATE.pageMap, MEM_STATE.mapPos.address

    ; list all page identifiers which are available to this module
    jsr initPageBytes

    ; calculate length of pageMap
    #move16Bit MEM_STATE.numBlocks, MEM_STATE.pageMapLen
    ; divide by 8 (bits per byte)
    #halve16Bit MEM_STATE.pageMapLen
    #halve16Bit MEM_STATE.pageMapLen
    #halve16Bit MEM_STATE.pageMapLen

    rts

.endnamespace