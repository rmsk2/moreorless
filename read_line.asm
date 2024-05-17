
LINE_END_CHAR = $0A

iohelp .namespace

begin
    stz TXT_FILE.eofReached
    #load16BitImmediate LINE_BUFFER.buffer, TXT_FILE.dataPtr
    lda #LINE_BUFFER_LEN + 1
    sta TXT_FILE.dataLen
    rts


; Carry is set, if an error ocurred. Zero length lines can and will occur.
readline
    rts


; carry is set if all data has been successfully read and the
; the file can be closed. Should only be called when readLine has returned
; with a set carry bit.
isSuccessfullyFinished
    rts


TEMP .byte 0
; shift LINE_BUFFER left as many bytes as given in accu
shiftLeft 
    sta TEMP
    ldy #0
    ldx #1
_loop
    cpy TEMP
    beq _done
    lda LINE_BUFFER, x
    sta LINE_BUFFER, y
    inx
    iny
    bra _loop
_done
    sec
    lda LINE_BUFFER.len
    sbc TEMP
    sta LINE_BUFFER.len
    rts


MAX_POS .byte 0
; searches for LINE_END_CHAR in the line buffer. If found the carry is set 
; upon return and the x register contains the length of the found line. 
; Otherwise the carry is clear.
searchLineEnd
    ldx #0    
_loop
    cpx MAX_POS
    beq _notFound
    lda LINE_BUFFER.buffer, x
    cmp LINE_END_CHAR
    beq _found
    inx 
    bra _loop
_found
    ; transform position to length
    inx
    sec
    rts
_notFound
    clc
    rts

.endnamespace