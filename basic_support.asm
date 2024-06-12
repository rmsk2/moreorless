basic .namespace

BASIC_NAME .fill MAX_FILE_LENGTH
BASIC_FILE .dstruct FileState_t, 177, BASIC_NAME, len(BASIC_NAME), BASIC_LINE_NR, LINE_BUFFER_LEN + 1 + size(BASIC_LINE_NR), MODE_WRITE, DEVICE_NUM

LINE_NUMBER  .word 0
COUNT_DIGITS .byte 0
generateLineNr
    #inc16Bit LINE_NUMBER
    stz COUNT_DIGITS
    #load16BitImmediate 10, $DE04
    lda LINE_NUMBER 
    sta $DE06
    lda LINE_NUMBER + 1
    sta $DE07
_loop
    ldx $DE16
    lda txtio.PRBYTE.hex_chars, x
    pha
    inc COUNT_DIGITS
    #cmp16BitImmediate 0, $DE14
    beq _done
    #move16Bit $DE14, $DE06
    bra _loop
_done
    ldy #0
_loop2
    pla
    sta BASIC_LINE_NR, y
    iny
    cpy COUNT_DIGITS
    bne _loop2
_loop3  
    lda #$20
    sta BASIC_LINE_NR, y
    iny
    cpy #len(BASIC_LINE_NR)
    bne _loop3    
    rts


resetLineNr
    #load16BitImmediate 0, LINE_NUMBER
    rts


; on error carry is set, otherwise it is clear
autoRenumber
    jsr resetLineNr
    ; initialize file pointer
    load16BitImmediate BASIC_FILE, FILEIO_PTR1
    ; initialize FileState struct

    lda TXT_FILE.drive
    sta BASIC_FILE.drive

    ; resest EOF state
    lda #EOF_NOT_REACHED
    sta BASIC_FILE.eofReached

    ; set mode to write
    lda #MODE_WRITE
    sta BASIC_FILE.mode

    ; open file for writing
    jsr disk.waitOpen
    bcc _fileIsOpen
    jmp _errorDuringOpen
_fileIsOpen
    ; save current list pointer
    #copyMem2Mem list.LIST.current, editor.STATE.ptrScratch    
    ; goto start of document
    #changeLine list.rewind
_lineLoop
    jsr generateLineNr
    ; append line ending character to LINE_BUFFER.buffer
    ldy LINE_BUFFER.len
    lda LINE_END_CHAR
    sta LINE_BUFFER.buffer, y
    ; set data buffer

    lda #<BASIC_LINE_NR
    sta BASIC_FILE.dataPtr
    lda #>BASIC_LINE_NR
    sta BASIC_FILE.dataPtr + 1
    ; set data buffer length => 1 line end char + 6 byte line number    
    clc
    lda LINE_BUFFER.len
    adc #size(BASIC_LINE_NR) + 1
    sta BASIC_FILE.dataLen
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
    #copyMem2Mem editor.STATE.ptrScratch, list.LIST.current
    jsr list.readCurrentLine
    clc
    rts
_errorClose
    jsr disk.waitClose
_errorDuringClose
    #copyMem2Mem editor.STATE.ptrScratch, list.LIST.current
    sec
_errorDuringOpen
    rts




init
    rts



.endnamespace