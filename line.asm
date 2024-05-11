
Line_t .struct 
    next            .dstruct FarPtr_t
    prev            .dstruct FarPtr_t
    len             .byte 0
    freeInLastBlock .byte 0
    lastBlock       .byte 0
    flags           .byte 0
    reserved        .fill 1
    block1          .dstruct FarPtr_t
    block2          .dstruct FarPtr_t
    block3          .dstruct FarPtr_t
    block4          .dstruct FarPtr_t
    block5          .dstruct FarPtr_t
    block6          .dstruct FarPtr_t
    block7          .dstruct FarPtr_t    
.endstruct

line .namespace


; Initializes a new Line_t item to which MEM_PTR3 points
init
    #copyMem2Ptr NIL, MEM_PTR3, Line_t.next
    #copyMem2Ptr NIL, MEM_PTR3, Line_t.prev
    ; set len to zero
    ldy #Line_t.len
    sta (MEM_PTR3), y
    ; set freeInLastBlock to zero
    ldy #Line_t.freeInLastBlock 
    sta (MEM_PTR3), y
    ; set lastBlock to 0
    ldy #Line_t.lastBlock
    sta (MEM_PTR3), y
    ; initialize LinePtr_t.flags
    lda #0
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