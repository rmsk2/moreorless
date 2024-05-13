NUM_SUB_BLOCKS = 7

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
    buffer .fill NUM_SUB_BLOCKS * BLOCK_SIZE
    len    .byte 0
.endstruct

LINE_BUFFER .dstruct LineBuffer_t 

line .namespace

init_module
    lda #0
    sta LINE_BUFFER.len
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