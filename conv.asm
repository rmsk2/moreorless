conv .namespace

Int16_t .struct
    lo     .byte 0
    hi     .byte 0
.endstruct

TEMP_LEN .byte 0
TEMP_BYTE .byte 0
ATOW .dstruct Int16_t
; this routine expects a pointer to a numeric string in CONV_PTR1 and its length
; in the accu. The result can be read from ATOW. The value of the numeric string
; must not exceed 65535 otherweise you'll get incorrect results.
atouw
    stz ATOW.lo
    stz ATOW.hi
    sta TEMP_LEN    
    #load16BitImmediate 10, $DE00
    ldy #0
_loop
    cpy TEMP_LEN
    beq _done
    ; multiply ATOW by 10
    #move16Bit ATOW, $DE02
    #move16Bit $DE10, ATOW
    lda (CONV_PTR1), y
    sec
    sbc #$30
    sta TEMP_BYTE
    #add16BitByte TEMP_BYTE, ATOW
    iny
    bra _loop
_done
    rts


MAX_INT_STR .text "65535"
; This routine checks whether the string to which CONV_PTR1 (length in accu)
; points represents a word that is 65536 or bigger. The carry is set if the
; string can be converted to an unsigned word.
checkMaxWord
    cmp #0
    beq _doneError
    cmp #6
    bcs _doneError
    ; here we know the string is 5 characters or shorter
    cmp #5
    beq _fullCheck
    ; Here we know the string is 4 Characters or shorter
    bne _doneOK
_fullCheck
    ; the string is five characters long
    ldy #0
_loop
    lda (CONV_PTR1), y
    cmp MAX_INT_STR, y
    ; value in string to test is equal to corresponding value in MAX_INT_STR => Check further
    beq _next
    ; value in string to test is bigger => not OK
    bcs _doneError
    ; value in string to test is smaller => OK
    bra _doneOK
_next
    iny
    cpy #5
    bne _loop
    ; string value is equal to MAX_INT_STR => OK
_doneOK
    sec
    rts
_doneError
    clc
    rts

.endnamespace