commandline .namespace

LEN_PARMS_IN_BYTES .byte 0
BYTE_COUNT .byte 0

CliParms_t .struct
    fileNamePresent .byte BOOL_FALSE
    fileNameParsed  .byte BOOL_FALSE
    driveNumber     .byte 0
    nameLen         .byte 0
.endstruct

CLI_DATA .dstruct CliParms_t

evalCliParms
    stz CLI_DATA.driveNumber
    stz CLI_DATA.nameLen

    lda #BOOL_FALSE
    sta CLI_DATA.fileNamePresent
    sta CLI_DATA.fileNameParsed
    
    #move16Bit kernel.args.ext, CLI_PTR1
    lda kernel.args.extlen
    sta LEN_PARMS_IN_BYTES

    stz BYTE_COUNT
_loop
    ldy BYTE_COUNT
    cpy LEN_PARMS_IN_BYTES
    beq _doneParams
    lda (CLI_PTR1), y
    sta CLI_PTR2
    iny
    lda (CLI_PTR1), y
    sta CLI_PTR2 + 1
    iny
    sty BYTE_COUNT
    jsr copyZeroTerminated
    bra _loop
_doneParams
    lda #BOOL_TRUE
    sta CLI_DATA.fileNamePresent
    lda LEN_PARMS_IN_BYTES
    lsr
    cmp #2
    bcs _parse
    stz CLI_DATA.fileNamePresent
    bra _done
_parse
    jsr parseName
_done
    rts


copyZeroTerminated
    ldy #0
_loop
    lda (CLI_PTR2), y
    beq _done
    sta FILE_NAME, y
    iny
    cpy #MAX_FILE_LENGTH
    bne _loop
_done
    sty CLI_DATA.nameLen
    rts


parseName
    stz CLI_DATA.fileNameParsed
    lda CLI_DATA.nameLen
    beq _done                                        ; a zero length name is not OK
    cmp #2
    bcs _atLeastTwo
    bra _success                                     ; file name has length one => This is OK
_atLeastTwo
    lda FILE_NAME + 1
    cmp #58
    bne _success                                    ; byte at index 1 is not a colon
    lda FILE_NAME
    cmp #$30
    bcc _success                                    ; byte at index 0 is < '0'
    cmp #$33
    bcs _success                                    ; byte at index 0 is >= '3'
    ; we have a valid drive number and a colon
    lda CLI_DATA.nameLen
    cmp #2
    beq _done                                       ; we only have a drive designation => this is not OK
    ; convert drive number
    lda FILE_NAME
    sec
    sbc #$30
    sta CLI_DATA.driveNumber
    ; remove drive designation from file name
    #load16BitImmediate FILE_NAME, MEM_PTR1
    ldy CLI_DATA.nameLen
    lda #0
    jsr memory.vecShiftleft
    dec CLI_DATA.nameLen
    ldy CLI_DATA.nameLen
    lda #0
    jsr memory.vecShiftleft
    dec CLI_DATA.nameLen
    bra _setSuccess
_success
    stz CLI_DATA.driveNumber                         ; set drive number 0
_setSuccess
    lda #BOOL_TRUE
    sta CLI_DATA.fileNameParsed
_done
    rts

.endnamespace