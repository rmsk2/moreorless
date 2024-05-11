
NUM_EDIT_LINES = 60


EditState_t .struct 
    curLine      .word 0
    curCol       .byte 0
    numEditLines .byte NUM_EDIT_LINES
    numLines     .word 0
    col          .byte $12
    colReversed  .byte $21
    line_list    .word 0
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