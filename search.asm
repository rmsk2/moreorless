search .namespace

; Remove this when clipping is no longer necessary
MAX_CHARS_TO_CONSIDER = 80

OFFSET       .byte 0
START_POS    .byte 0
END_INDEX    .byte 0
MIN_POSSIBLE .byte 0
TEMP_POS     .byte 0

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

.endnamespace