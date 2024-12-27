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
    cpy #4
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
    #load16BitImmediate FILE_NAME, PATH_PTR
    lda CLI_DATA.nameLen
    ; default drive is zero
    ldx #0
    jsr iohelp.parseFileName
    bcs _error
    sta CLI_DATA.nameLen
    stx CLI_DATA.driveNumber
    lda #BOOL_TRUE
    sta CLI_DATA.fileNameParsed
_error
    rts

.endnamespace