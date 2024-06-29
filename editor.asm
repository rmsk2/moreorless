INDENT_SIZE = 2

WHITE_ON_BLUE = 0
GREEN_ON_BLACK = 1
BLACK_ON_WHITE = 2
WHITE_ON_BLACK = 3
AMBER_ON_BLACK = 4

MarkState_t .struct 
    line    .word 0
    xPos    .byte 0
    yPos    .byte 0
    isValid .byte 0
    element .dstruct FarPtr_t
.endstruct


EditState_t .struct 
    curLine          .word 0
    searchPatternSet .byte BOOL_FALSE
    col              .byte $12
    colReversed      .byte $21
    ptrScratch       .dstruct FarPtr_t
    navigateCol      .byte 0
    inputVector      .word 0
    dirty            .byte 0
    mark             .dstruct MarkState_t
    fileNameSet      .byte 0
    colorIndex       .byte GREEN_ON_BLACK
    maxCol           .byte 0
    indentLevel      .byte INDENT_SIZE
.endstruct

MAX_FILE_LENGTH = 100

FILE_NAME .fill MAX_FILE_LENGTH

TXT_FILE .dstruct FileState_t, 76, FILE_NAME, len(FILE_NAME), LINE_BUFFER.buffer, LINE_BUFFER_LEN + 1, MODE_READ, DEVICE_NUM


editor .namespace

COLOURS .byte $12, $21, $30, $03, $01, $10, $10, $01, $40, $04

ALREADY_CREATED .byte 1

; on error carry is set, otherwise it is clear
saveFile
    ; initialize file pointer
    load16BitImmediate TXT_FILE, FILEIO_PTR1
    ; initialize FileState struct

    ; resest EOF state
    lda #EOF_NOT_REACHED
    sta TXT_FILE.eofReached

    ; set mode to write
    lda #MODE_WRITE
    sta TXT_FILE.mode

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
    lda #<LINE_BUFFER.buffer
    sta TXT_FILE.dataPtr
    lda #>LINE_BUFFER.buffer
    sta TXT_FILE.dataPtr + 1
    ; set data buffer length
    lda LINE_BUFFER.len
    ; increment length because of line ending character
    ina
    sta TXT_FILE.dataLen
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


cycleColour
    inc STATE.colorIndex
    lda STATE.colorIndex
    cmp STATE.maxCol
    bne setColour
    stz STATE.colorIndex
setColour
    lda STATE.colorIndex
    asl
    tay
    lda COLOURS, y
    sta STATE.col
    iny
    lda COLOURS, y
    sta STATE.colReversed
    rts


init
    lda #(len(COLOURS)/2)
    sta STATE.maxCol
    jsr setColour
    lda #BOOL_FALSE
    sta STATE.searchPatternSet
    stz STATE.navigateCol
    stz STATE.dirty
    stz STATE.mark.isValid
    stz STATE.fileNameSet
    rts

.endnamespace