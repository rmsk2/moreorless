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
    #load16BitImmediate LINE_BUFFER.buffer, LINE_PTR1
    ldy LINE_BUFFER.len
    jsr toLowerInt
_done
    lda #BOOL_TRUE
    sta LINE_BUFFER.dirty
    rts


; addr in LINE_PTR1, length in y
LOWER_LEN .byte 0
toLowerInt
    sty LOWER_LEN
    ldy #0
_loop    
    cpy LOWER_LEN
    beq _done
    lda (LINE_PTR1), y
    cmp #$5b
    bcs _next
    cmp #$41
    bcc _next
    ; we have an uppercase letter => convert it to lower case
    clc
    adc #32
    sta (LINE_PTR1), y
_next
    iny
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


NUM_INDENT .byte 0
NUM_BLANKS .byte 0
doIndent
    stz NUM_INDENT
    sta NUM_BLANKS
    #load16BitImmediate LINE_BUFFER.buffer, MEM_PTR1
    lda #search.MAX_CHARS_TO_CONSIDER
    sta memory.INS_PARAM.maxLength
_indentLoop
    lda NUM_BLANKS
    beq _done    
    ldy LINE_BUFFER.len
    lda #0
    ldx #$20
    jsr memory.insertCharacterGrow
    bcs _done
    dec NUM_BLANKS
    inc LINE_BUFFER.len
    inc NUM_INDENT
    bra _indentLoop
_done
    lda NUM_INDENT
    beq _return
    lda #BOOL_TRUE
    sta LINE_BUFFER.dirty
_return
    rts


NUM_UNINDENT .byte 0
doUnindent
    stz NUM_UNINDENT
    sta NUM_BLANKS
    #load16BitImmediate LINE_BUFFER.buffer, MEM_PTR1
_loop
    lda NUM_BLANKS
    beq _done
    ldy LINE_BUFFER.len
    beq _done
    lda LINE_BUFFER.buffer
    cmp #$20
    bne _done
    lda #0
    jsr memory.vecShiftLeft
    dec NUM_BLANKS
    inc NUM_UNINDENT
    dec LINE_BUFFER.len
    bra _loop
_done
    lda NUM_UNINDENT
    beq _return
    lda #BOOL_TRUE
    sta LINE_BUFFER.dirty
_return
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