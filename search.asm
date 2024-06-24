search .namespace

; Remove this when clipping is no longer necessary
MAX_CHARS_TO_CONSIDER = 80

OFFSET       .byte 0
START_POS    .byte 0
END_INDEX    .byte 0
MIN_POSSIBLE .byte 0
TEMP_POS     .byte 0


ReplaceStr_t .struct 
    buffer .fill MAX_CHARS_TO_CONSIDER
    len    .byte 0
.endstruct


REPLACE_TXT .dstruct ReplaceStr_t

TextFromEnd
    lda LINE_BUFFER.len
TextBackward
    sta TEMP_POS
    ldx #$FF
    stx OFFSET
    stx END_INDEX    
    cmp #0
    beq TextFromPos                                            ; zero length is a special case, start pos remains 0
    ; calculate first possible start position in current line
    lda LINE_BUFFER.len
    cmp #MAX_CHARS_TO_CONSIDER
    bcc _noCalc
    lda #MAX_CHARS_TO_CONSIDER
_noCalc
    sec
    sbc SEARCH_BUFFER.len
    bmi _fail
    cmp TEMP_POS
    bcc TextFromPos
    beq TextFromEnd
    lda TEMP_POS
    bra TextFromPos
_fail
    clc
    rts


; searches whether the text in SEARCH_BUFFER appears in LINE_BUFFER. This routine
; uses only simple optimizations. Maybe I will implement the Knuth Morris Pratt
; algorithm if this turns out to be too slow. On the other hand I don't know whether
; the asymptotic advantage of that algorithm really comes into play in this case.
;
; Carry is set if the search pattern can be found in the line  and x is set to the
; start position of the searched string.
TextFromStart
    lda #0
; start here if you know the start pos before starting the search
; put the start pos in the accu
TextForward
    ldx #1
    stx OFFSET
    ldx LINE_BUFFER.len
    stx END_INDEX    
TextFromPos
    ; set accu to the desired start pos if you do not want to start the search at the
    ; beginning of the line and call TextFromPos
    sta START_POS
    tay
    ; we can't find anything in an empty line
    lda LINE_BUFFER.len
    beq _notFound
    ldx #0
_compare
    ; we have exhausted the search string => we have a match
    cpx SEARCH_BUFFER.len
    beq _found
    ; check whether we have reached the end of the line
    cpy END_INDEX
    beq _notFound
    ; clip to 80 characters as long as side scrolling does not work
    ; remove this when side scrolling works
    cpy #MAX_CHARS_TO_CONSIDER
    beq _notFound
    ; convert uppercase letters to lowercase
    lda LINE_BUFFER.buffer, y
    cmp #$5b
    bcs _doComp
    cmp #$41
    bcc _doComp
    ; we have an uppercase letter => convert it to lower case
    clc
    adc #32    
_doComp
    cmp SEARCH_BUFFER.buffer, x
    beq _next
    ldx #0
    clc
    lda START_POS
    adc OFFSET
    sta START_POS
    tay
    bra _compare
_next
    inx
    iny
    bra _compare
_found 
    ldx START_POS
    sec
    rts
_notFound
    clc
    rts


LINE_END .byte 0
; Check whether the search string appears at the given position.
; start pos in accu. Carry is set if check is OK, i.e. if expected value has been found
CheckAtPos
    tay
    lda LINE_BUFFER.len
    beq _notFound
    sta LINE_END
    ldx #0
_loop
    ; we have exhausted the search string => we have a match
    cpx SEARCH_BUFFER.len
    beq _found
    ; check whether we have reached the end of the line
    cpy LINE_END
    beq _notFound
    ; clip to 80 characters as long as side scrolling does not work
    ; remove this when side scrolling works
    cpy #MAX_CHARS_TO_CONSIDER
    beq _notFound
    ; convert uppercase letters to lowercase
    lda LINE_BUFFER.buffer, y
    cmp #$5b
    bcs _doComp
    cmp #$41
    bcc _doComp
    ; we have an uppercase letter => convert it to lower case
    clc
    adc #32    
_doComp
    cmp SEARCH_BUFFER.buffer, x
    bne _notFound
    inx
    iny
    bra _loop
_notFound
    clc
    rts
_found
    sec
    rts


TEMP_LEN .word 0
TEMP_LEN2 .word 0
REPL_POS .byte 0
; accu has to contain the position where to insert the REPLACE_TXT. Carry is set
; upon return if the line would become too long after the replacement
Replace
    sta REPL_POS
    ; check if operation is possible
    stz TEMP_LEN2 + 1
    lda LINE_BUFFER.len
    sta TEMP_LEN2
    
    stz TEMP_LEN + 1
    lda SEARCH_BUFFER.len
    sta TEMP_LEN 

    #sub16Bit TEMP_LEN, TEMP_LEN2    

    stz TEMP_LEN + 1
    lda REPLACE_TXT.len
    sta TEMP_LEN

    #add16Bit TEMP_LEN, TEMP_LEN2
    #cmp16BitImmediate MAX_CHARS_TO_CONSIDER, TEMP_LEN2
    ;beq _allowed
    bcc _done
    ; perform copy operation
    ; first copy prefix from LINE_BUFFER to SCRATCH_BUFFER
_allowed
    ldy #0
_loopPrefix
    cpy REPL_POS
    beq _replace
    lda LINE_BUFFER.buffer, y
    sta SCRATCH_BUFFER.buffer, y
    iny
    bra _loopPrefix
    ; then copy replace text from REPLACE_TXT to SCRATCH_BUFFER
_replace
    tya
    tax
    ldy #0
_loopReplace
    cpy REPLACE_TXT.len
    beq _postfix
    lda REPLACE_TXT.buffer, y
    sta SCRATCH_BUFFER.buffer, x
    inx
    iny
    bra _loopReplace
_postfix
    ; then copy postfix from LINE_BUFFER to SCRATCH_BUFFER
    lda REPL_POS
    clc
    adc SEARCH_BUFFER.len
    tay
_loopPostfix
    cpy LINE_BUFFER.len
    beq _copyBack
    lda LINE_BUFFER.buffer, y
    sta SCRATCH_BUFFER.buffer, x
    inx
    iny
    bra _loopPostfix
_copyBack
    stx SCRATCH_BUFFER.len
    ; copy SCRATCH_BUFFER to LINE_BUFFER
    ldy #0
_loopCopyBack
    cpy SCRATCH_BUFFER.len
    beq _doneOK
    lda SCRATCH_BUFFER.buffer, y
    sta LINE_BUFFER.buffer, y
    iny
    bra _loopCopyBack
_doneOK
    sty LINE_BUFFER.len
    clc
_done
    rts


init
    stz REPLACE_TXT.len
    rts

.endnamespace