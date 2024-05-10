
NUM_EDIT_LINES = 60

Line_t .struct 
    next            .dstruct FarPtr_t
    prev            .dstruct FarPtr_t
    len             .byte 0
    freeInLastBlock .byte 0
    lastBlock       .byte 0
    reserved        .fill 2
    block1          .dstruct FarPtr_t
    block2          .dstruct FarPtr_t
    block3          .dstruct FarPtr_t
    block4          .dstruct FarPtr_t
    block5          .dstruct FarPtr_t
    block6          .dstruct FarPtr_t
    block7          .dstruct FarPtr_t    
.endstruct


EditState_t .struct 
    curLine      .word 0
    curCol       .byte 0
    numEditLines .byte NUM_EDIT_LINES
    numLines     .word 0
    col          .byte $12
    colReversed  .byte $21
    firstLine    .dstruct FarPtr_t
.endstruct

editor .namespace

STATE .dstruct EditState_t

init
    lda #$12
    sta STATE.col
    lda #$21
    sta STATE.colReversed
    rts

.endnamespace