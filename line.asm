NUM_SUB_BLOCKS = 7
LINE_BUFFER_LEN = NUM_SUB_BLOCKS * BLOCK_SIZE

Line_t .struct 
    next            .dstruct FarPtr_t
    prev            .dstruct FarPtr_t
    len             .byte 0
    numBlocks       .byte 0
    flags           .byte 0
    reserved        .fill 2
    block1          .dstruct FarPtr_t
    block2          .dstruct FarPtr_t
    block3          .dstruct FarPtr_t
    block4          .dstruct FarPtr_t
    block5          .dstruct FarPtr_t
    block6          .dstruct FarPtr_t
    block7          .dstruct FarPtr_t    
.endstruct

LineBuffer_t .struct
    buffer .fill LINE_BUFFER_LEN + 1                 ; make room for line ending character
    len    .byte 0
    dirty  .byte 0
.endstruct

SCRATCH_BUFFER .dstruct LineBuffer_t
BASIC_LINE_NR  .text "      "
LINE_BUFFER    .dstruct LineBuffer_t 
SEARCH_BUFFER  .dstruct LineBuffer_t

line .namespace

toLower
    ldx #0
_loop    
    cpx LINE_BUFFER.len
    beq _done
    lda LINE_BUFFER.buffer, x
    cmp #$5b
    bcs _next
    cmp #$41
    bcc _next
    ; we have an uppercase letter => convert it to lower case
    clc
    adc #32
    sta LINE_BUFFER.buffer, x
_next
    inx
    bra _loop
_done
    rts


SPACE_CHAR = $20
; y contains the number of blanks that prefix the current line
countBlanks
    ldy #0
_loop
    cpy LINE_BUFFER.len
    beq _done
    lda LINE_BUFFER.buffer, y
    cmp #SPACE_CHAR
    bne _done
    iny
    bra _loop
_done
    rts


init_module
    lda #0
    sta LINE_BUFFER.len
    stz LINE_BUFFER.dirty
    rts


; Initializes a new Line_t item to which MEM_PTR3 points
init
    #copyMem2Ptr NIL, MEM_PTR3, Line_t.next
    #copyMem2Ptr NIL, MEM_PTR3, Line_t.prev
    lda #0
    ; set len to zero
    ldy #Line_t.len
    sta (MEM_PTR3), y
    ; set numBlocks to 0
    ldy #Line_t.numBlocks
    sta (MEM_PTR3), y
    ; initialize LinePtr_t.flags
    ; set flags
    ldy #Line_t.flags
    sta (MEM_PTR3), y     
    ; set all pointers to subblocks to NIL
    lda #0
    ldx #0
    ldy #Line_t.block1
_loop
    sta (MEM_PTR3), y
    iny
    inx
    cpx #(size(FarPtr_t) * 7)
    bne _loop
    rts 

.endnamespace