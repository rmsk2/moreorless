EditState_t .struct 
    curLine          .word 0
    searchPatternSet .byte BOOL_FALSE
    col              .byte $12
    colReversed      .byte $21
    ptrScratch       .dstruct FarPtr_t
    navigateCol      .byte 0
    inputVector      .word 0
    dirty            .byte 0
    searchInProgress .byte 0
.endstruct

MAX_FILE_LENGTH = 100

FILE_NAME .fill MAX_FILE_LENGTH

TXT_FILE .dstruct FileState_t, 76, FILE_NAME, len(FILE_NAME), LINE_BUFFER.buffer, LINE_BUFFER_LEN + 1, MODE_READ, DEVICE_NUM

OUT_OF_MEMORY .word panic
; ToDo: Think about a global out of memory handler
panic
    rts


changeLine .macro func
    pha
    phx
    phy
    lda LINE_BUFFER.dirty
    beq _call
    jsr list.setCurrentLine
    bcc _call
    ply
    plx
    pla
    jmp (OUT_OF_MEMORY)
_call
    ply
    plx
    pla
    jsr \func
    php
    phx    
    jsr list.readCurrentLine
    plx
    plp
_done
.endmacro


editor .namespace

ALREADY_CREATED .byte 1

; on error carry is set, otherwise it is clear
saveFile
    ; initialize file pointer
    load16BitImmediate TXT_FILE, FILEIO_PTR1
    ; initialize FileState struct

    ; resest EOF state
    ldy #FileState_t.eofReached
    lda #EOF_NOT_REACHED
    sta (FILEIO_PTR1), y

    ; set mode to write
    ldy #FileState_t.mode
    lda #MODE_WRITE
    sta (FILEIO_PTR1), y

    ; open file for writing
    jsr disk.waitOpen
    bcc _fileIsOpen
    jmp _errorDuringOpen
_fileIsOpen
    ; save current list pointer
    #copyMem2Mem list.LIST.current, STATE.ptrScratch    
    ; goto start of document
    #changeLine list.rewind
_lineLoop
    ; append line ending character to LINE_BUFFER.buffer
    ldy LINE_BUFFER.len
    lda LINE_END_CHAR
    sta LINE_BUFFER.buffer, y
    ; set data buffer
    ldy #FileState_t.dataPtr
    lda #<LINE_BUFFER.buffer
    sta (FILEIO_PTR1), y
    iny
    lda #>LINE_BUFFER.buffer
    sta (FILEIO_PTR1), y
    ; set data buffer length
    ldy #FileState_t.dataLen
    lda LINE_BUFFER.len
    ; increment length because of line ending character
    ina
    sta (FILEIO_PTR1), y
    ; write block
    jsr disk.waitWriteBlock
    bcs _errorClose
    ; goto next line
    #changeLine list.next
    bcc _lineLoop
    ; close file
    jsr disk.waitClose
    bcs _errorDuringClose
    ; restore current list element
    #copyMem2Mem STATE.ptrScratch, list.LIST.current
    jsr list.readCurrentLine
    jsr markDocumentAsClean
    clc
    rts
_errorClose
    jsr disk.waitClose
_errorDuringClose
    #copyMem2Mem STATE.ptrScratch, list.LIST.current
    jsr markDocumentAsDirty
    sec
_errorDuringOpen
    rts


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
    jsr list.readCurrentLine
    jsr markDocumentAsClean
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
    stz STATE.dirty
    stz STATE.searchInProgress
    rts

.endnamespace