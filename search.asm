search .namespace

; Remove this when clipping is no longer necessary
MAX_CHARS_TO_CONSIDER = 80

START_POS .byte 0
; searches whether the text in SEARCH_BUFFER appears in LINE_BUFFER. This routine
; uses only simple optimizations. Maybe I will implement the Knuth Morris Pratt
; algorithm if this turns out to be too slow. Carry is set if the search pattern
; can be found in the line.
searchText
    ldx #0
    ldy #0
    stz START_POS
_compare
    ; we have exhausted the search string => we have a match
    cpx SEARCH_BUFFER.len
    beq _found
    ; check whether we have reached the end of the line
    cpy LINE_BUFFER.len
    beq _notFound
    ; clip to 80 characters as long as side scrolling does not work
    ; remove this when side scrolling works
    cpy #MAX_CHARS_TO_CONSIDER
    beq _notFound
    lda SEARCH_BUFFER, x
    cmp LINE_BUFFER, y
    beq _next
    ldx #0
    inc START_POS
    ldy START_POS
    bra _compare
_next
    inx
    iny
    bra _compare
_found 
    sec
    rts
_notFound
    clc
    rts

.endnamespace