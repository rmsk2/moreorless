
LINE_END_CHAR .byte $0A

printLineBuffer .macro
    #load16BitImmediate LINE_BUFFER.buffer, TXT_PTR3
    lda LINE_BUFFER.len
    jsr txtio.printStrClipped
.endmacro

iohelp .namespace

DATA_AVAILABLE .byte 0
ALL_DATA_READ .byte 0
NUM_SHIFT_LEFT .byte 0

; returns with set carry in case an error occurred
begin
    stz TXT_FILE.eofReached
    stz ALL_DATA_READ
    stz DATA_AVAILABLE
    stz NUM_SHIFT_LEFT
    jsr readMore
    ; evaluate result
    bcc _done
    lda TXT_FILE.eofReached
    beq _error
    ; The file is already read in full
    inc ALL_DATA_READ
    bra _done
    ; A simple read error occurred
_error
    sec
    rts
    ; we have successfully read at least some data
_done
    clc
    rts


; Carry is set if an error ocurred. Zero length lines can and will occur.
readLine
    ; cleanup previous line
    lda NUM_SHIFT_LEFT
    jsr shiftLeft
_tryAgain
    ; look for a line ending character in the remaining data
    jsr searchLineEnd
    bcc _noLineEnd
    ; we have found a full line
    stx LINE_BUFFER.len
    inx
    stx NUM_SHIFT_LEFT
    clc
    rts
_noLineEnd
    ; check whether the line is too long
    lda DATA_AVAILABLE
    cmp #LINE_BUFFER_LEN + 1
    ; we have not found a new line even though the buffer is full
    ; => line is too long
    beq _finished
    ; Here DATA_AVAILABLE <= LINE_BUFFER_LEN
    lda ALL_DATA_READ
    beq _readMore
    ; The file is exhausted. 
    ; is there data left?
    lda DATA_AVAILABLE
    ; If no data is available and we have reached the end of the file we are done
    beq _finished
    ; we have at least one byte left in the buffer but the file is exhausted => We simply 
    ; assume the rest in the buffer is the last line
    lda DATA_AVAILABLE
    sta LINE_BUFFER.len
    sta NUM_SHIFT_LEFT
    clc
    rts
_readMore
    ; there is still data to read from the file
    jsr readMore
    bcc _tryAgain
    lda TXT_FILE.eofReached
    ; we have a read error which is not EOF => we give up
    beq _finished
    ; We have reached EOF => the file is now read in full
    inc ALL_DATA_READ
    ; try to find full lines in the remaining data
    bra _tryAgain
_finished
    sec
    rts


BYTES_TO_READ .byte 0
readMore
    #load16BitImmediate LINE_BUFFER.buffer, TXT_FILE.dataPtr
    ; calculate LINE_BUFFER_LEN + 1 - DATA_AVAILABLE, i.e. the number
    ; of bytes missing in the full buffer
    sec
    lda #LINE_BUFFER_LEN + 1
    sbc DATA_AVAILABLE
    ; tell diskio routines how many bytes we want to read
    sta TXT_FILE.dataLen
    sta BYTES_TO_READ
    ; calculate address where the new bytes should start to load, i.e.
    ; LINE_BUFFER.buffer + DATA_AVAILABLE
    clc
    lda DATA_AVAILABLE
    adc TXT_FILE.dataPtr
    sta TXT_FILE.dataPtr
    lda #0
    adc TXT_FILE.dataPtr + 1
    sta TXT_FILE.dataPtr + 1
    ; This call now fills the buffer
    jsr disk.waitReadBlock
    ; save carry which indicates error
    php
    ; calculate the number of bytes which have been read. dataLen
    ; contains the number of bytes which have not been read.
    sec
    lda BYTES_TO_READ
    sbc TXT_FILE.dataLen    
    ; accu contains the number of bytes read
    clc
    ; add this value to DATA_AVAILABLE
    adc DATA_AVAILABLE
    sta DATA_AVAILABLE
    ; restore error state
    plp
    rts


; carry is set if all data has been successfully read and the
; the file can be closed. Should only be called when readLine has returned
; with a set carry bit.
isSuccessfullyFinished
    ; file is successfully read when no data is available in the buffer
    ; and all bytes have been read from the file.
    lda DATA_AVAILABLE
    bne _doneNotOK
    lda ALL_DATA_READ
    beq _doneNotOK
    sec
    rts
_doneNotOK
    clc
    rts


NUM_COPIES .byte 0
; shift LINE_BUFFER left as many bytes as given in NUM_SHIFT_LEFT
shiftLeft 
    ldy #0
    ldx NUM_SHIFT_LEFT
    beq _exit
    lda DATA_AVAILABLE 
    sec
    sbc NUM_SHIFT_LEFT
    sta NUM_COPIES
_loop
    cpy NUM_COPIES
    beq _done
    lda LINE_BUFFER.buffer, x
    sta LINE_BUFFER.buffer, y
    inx
    iny
    bra _loop
_done
    sec
    lda DATA_AVAILABLE
    sbc NUM_SHIFT_LEFT
    sta DATA_AVAILABLE
_exit
    rts


; searches for LINE_END_CHAR in the line buffer. If found the carry is set 
; upon return and the x register contains the length of the found line. 
; Otherwise the carry is clear.
searchLineEnd
    ldx #0    
_loop
    cpx DATA_AVAILABLE
    beq _notFound
    lda LINE_BUFFER.buffer, x
    cmp LINE_END_CHAR
    beq _found
    inx 
    bra _loop
_found
    sec
    rts
_notFound
    clc
    rts

.endnamespace