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

.endnamespace