EditState_t .struct 
    curLine          .word 0
    searchPatternSet .byte BOOL_FALSE
    curCol           .byte 0
    col              .byte $12
    colReversed      .byte $21
    ptrScratch       .dstruct FarPtr_t
    navigateCol      .byte 0
.endstruct

MAX_FILE_LENGTH = 100

FILE_NAME .fill MAX_FILE_LENGTH

TXT_FILE .dstruct FileState_t, 76, FILE_NAME, len(FILE_NAME), LINE_BUFFER.buffer, LINE_BUFFER_LEN + 1, MODE_READ, DEVICE_NUM

editor .namespace

ALREADY_CREATED .byte 1

; carry is set if loading file failed
; ToDo: Expand tab characters to four blanks
loadFile
    jsr list.create
    bcc _created
    rts
_created
    lda #1
    sta ALREADY_CREATED
    load16BitImmediate TXT_FILE, FILEIO_PTR1
    jsr disk.waitOpen
    bcs _error    
    jsr iohelp.begin
    bcs _error
_lineLoop
    jsr iohelp.readLine
    bcc _process
    jsr iohelp.isSuccessfullyFinished
    bcs _doneOK
    jmp _errorClose
_process
    jsr addLine
    bcs _errorClose
    bra _lineLoop
_doneOK
    jsr disk.waitClose
    jsr list.rewind
    clc
    rts
_errorClose
    jsr disk.waitClose
_error
    jsr list.destroy
    sec
    rts


; carry is set if an error occurred. Zero length lines are OK.
addLine
    lda ALREADY_CREATED
    bne _noInsert
    jsr list.insertAfter
    bcs _done
    jsr list.next
    bra _setData
_noInsert
    stz ALREADY_CREATED
_setData
    jsr list.setCurrentLine
_done    
    rts

STATE .dstruct EditState_t

init
    lda #$12
    sta STATE.col
    lda #$21
    sta STATE.colReversed
    lda #BOOL_FALSE
    sta STATE.searchPatternSet
    stz STATE.navigateCol
    rts

.endnamespace