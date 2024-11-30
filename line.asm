NUM_SUB_BLOCKS = 7
LINE_BUFFER_LEN = NUM_SUB_BLOCKS * BLOCK_SIZE

Line_t .struct 
    next            .dstruct FarPtr_t
    prev            .dstruct FarPtr_t
    len             .byte 0
    numBlocks       .byte 0
    flags           .byte 0
    reserved        .fill 2
    block1          .dstruct FarPtr_t
    block2          .dstruct FarPtr_t
    block3          .dstruct FarPtr_t
    block4          .dstruct FarPtr_t
    block5          .dstruct FarPtr_t
    block6          .dstruct FarPtr_t
    block7          .dstruct FarPtr_t    
.endstruct

LineBuffer_t .struct
    buffer .fill LINE_BUFFER_LEN + 1                 ; make room for line ending character
    len    .byte 0
    dirty  .byte 0
.endstruct

SCRATCH_BUFFER .dstruct LineBuffer_t
BASIC_LINE_NR  .text "      "
LINE_BUFFER    .dstruct LineBuffer_t 
SEARCH_BUFFER  .dstruct LineBuffer_t

line .namespace

toLower
    #load16BitImmediate LINE_BUFFER.buffer, LINE_PTR1
    ldy LINE_BUFFER.len
    jsr toLowerInt
_done
    lda #BOOL_TRUE
    sta LINE_BUFFER.dirty
    rts


; addr in LINE_PTR1, length in y
LOWER_LEN .byte 0
toLowerInt
    sty LOWER_LEN
    ldy #0
_loop    
    cpy LOWER_LEN
    beq _done
    lda (LINE_PTR1), y
    cmp #$5b
    bcs _next
    cmp #$41
    bcc _next
    ; we have an uppercase letter => convert it to lower case
    clc
    adc #32
    sta (LINE_PTR1), y
_next
    iny
    bra _loop
_done
    rts


SPACE_CHAR = $20
; y contains the number of blanks that prefix the current line
countBlanks
    ldy #0
_loop
    cpy LINE_BUFFER.len
    beq _done
    lda LINE_BUFFER.buffer, y
    cmp #SPACE_CHAR
    bne _done
    iny
    bra _loop
_done
    rts


NUM_INDENT .byte 0
NUM_BLANKS .byte 0
doIndent
    stz NUM_INDENT
    sta NUM_BLANKS
    #load16BitImmediate LINE_BUFFER.buffer, MEM_PTR1
    lda #search.MAX_CHARS_TO_CONSIDER
    sta memory.INS_PARAM.maxLength
_indentLoop
    lda NUM_BLANKS
    beq _done    
    ldy LINE_BUFFER.len
    lda #0
    ldx #$20
    jsr memory.insertCharacterGrow
    bcs _done
    dec NUM_BLANKS
    inc LINE_BUFFER.len
    inc NUM_INDENT
    bra _indentLoop
_done
    lda NUM_INDENT
    beq _return
    lda #BOOL_TRUE
    sta LINE_BUFFER.dirty
_return
    rts


NUM_UNINDENT .byte 0
doUnindent
    stz NUM_UNINDENT
    sta NUM_BLANKS
    #load16BitImmediate LINE_BUFFER.buffer, MEM_PTR1
_loop
    lda NUM_BLANKS
    beq _done
    ldy LINE_BUFFER.len
    beq _done
    lda LINE_BUFFER.buffer
    cmp #$20
    bne _done
    lda #0
    jsr memory.vecShiftLeft
    dec NUM_BLANKS
    inc NUM_UNINDENT
    dec LINE_BUFFER.len
    bra _loop
_done
    lda NUM_UNINDENT
    beq _return
    lda #BOOL_TRUE
    sta LINE_BUFFER.dirty
_return
    rts


init_module
    lda #0
    sta LINE_BUFFER.len
    stz LINE_BUFFER.dirty
    rts


; Initializes a new Line_t item to which MEM_PTR3 points
init
    #copyMem2Ptr NIL, MEM_PTR3, Line_t.next
    #copyMem2Ptr NIL, MEM_PTR3, Line_t.prev
    lda #0
    ; set len to zero
    ldy #Line_t.len
    sta (MEM_PTR3), y
    ; set numBlocks to 0
    ldy #Line_t.numBlocks
    sta (MEM_PTR3), y
    ; initialize LinePtr_t.flags
    ; set flags
    ldy #Line_t.flags
    sta (MEM_PTR3), y     
    ; set all pointers to subblocks to NIL
    lda #0
    ldx #0
    ldy #Line_t.block1
_loop
    sta (MEM_PTR3), y
    iny
    inx
    cpx #(size(FarPtr_t) * 7)
    bne _loop
    rts 


; This routine splits a line into its words. For each word which was found an entry
; is written to memory. This entry starts with a length byte which contains the length
; of the word followed by the characters of said word.
; carry is set if length limit for the target memory was reached.
cleanUpLine
    lda LINE_BUFFER.len
    beq _doneOK
    ; here we know that the line has a length of at least one byte
    ldy #0
_wordLoop
    jsr copyNextWordFromLine
    bcs _return
    cpy LINE_BUFFER.len
    bne _wordLoop
_doneOK
    clc
_return
    rts


; This routine stores a stream of bytes (one byte per call) at consecutive addresses in
; 21 bit address space.
writeByteLines
#storeByteLinear $8000, BASIC_PTR

writeOneByte
    jsr writeByteLines
    php
    #inc16Bit COPY_RES.byteCounter
    plp
    bcc _done
    lda 12
    cmp #LAST_PAGE_MEM_FREE
    beq _doneTooLarge
_done
    clc
    rts
_doneTooLarge
    sec
    rts    

TAB_CHAR = 9
MAX_WORD_LEN = 79

braIfNotWS .macro braAddress
    cmp #SPACE_CHAR
    bne _checkTab
    beq _done
_checkTab
    cmp #TAB_CHAR
    bne \braAddress
_done
.endmacro

braIfWS .macro braAddress
    cmp #SPACE_CHAR
    beq \braAddress
    cmp #TAB_CHAR
    beq \braAddress
    ; Todo: Check Tab character
.endmacro

copyWord2Target .macro failAddr
    ldx #0
_loopCopy    
    lda COPY_RES.curWord.word, x
    jsr writeOneByte
    bcs \failAddr
    inx
    cpx COPY_RES.curWord.len
    bne _loopCopy
.endmacro

copyLengthByte2Target .macro failAddr
    stx COPY_RES.curWord.len
    lda COPY_RES.curWord.len
    jsr writeOneByte
    bcs \failAddr
.endmacro

; This routine searches for the next word in the LINE_BUFFER. It first skips
; a whitespace prefix (if it is present). After that the characters of the
; word are copied COPY_RES.curWord until the line ends or a whitespace character
; is detected. Finally the contents of COPY_RES.curWord is written to target
; memory.
; Carry is set if the target memory has no room left for additional data.
copyNextWordFromLine
    ; reset word buffer length and X register
    stz COPY_RES.curWord.len
    ldx #0
_skipWhiteSpace
    ; skip leading whitespace
    cpy LINE_BUFFER.len
    beq returnNow
    lda LINE_BUFFER.buffer, y
    #braIfNotWS wordFound                          ; branch to given address, if accu contains no whitespace
    iny
    bra _skipWhiteSpace
wordFound
    ; copy word data to word buffer
    cpx #MAX_WORD_LEN
    beq copyWord                                   ; max word length is reached
    cpy LINE_BUFFER.len
    beq copyWord                                   ; last byte of line was reached
    lda LINE_BUFFER.buffer, y
    #braIfWS copyWord                              ; branch to given address, if accu contains whitespace
    sta COPY_RES.curWord.word, x
    inx
    iny
    bra wordFound
copyWord
    ; copy word buffer to target memory
    cpx #0
    beq returnNow                                  ; no word was found => nothing to copy 
    ; write length byte to target location
    #copyLengthByte2Target doneTooLarge            ; copy length byte or in case of failure branch to given address
    ; write word to target location
    #copyWord2Target doneTooLarge                  ; copy word data or in case of failure branch to given address
returnNow
    clc
    rts
doneTooLarge
    sec
    rts


WordBuffer_t .struct
    len  .byte 0
    word .fill 79
.endstruct

CopyResult_t .struct 
    mmuState    .byte 0
    byteCounter .word 0
    ; Any subroutine has to flag an error by setting the carry upon return.
    ; It has to write the processed byte to memory and must update byteCounter
    processVec  .word cleanUpLine
    curWord     .dstruct WordBuffer_t
.endstruct

procLine
    jmp (COPY_RES.processVec)

COPY_RES .dstruct CopyResult_t


initCopyRes
    #load16BitImmediate 0, COPY_RES.byteCounter
    #load16BitImmediate $8000, BASIC_PTR
    rts


; In target memory an entry with length byte of 0 signals the end of the
; word list.
writeEndMarker
    lda #0
    jsr writeOneByte
    rts


initMMU
    ; save current MMU state
    lda 12
    sta COPY_RES.mmuState
    ; bank in RAM page FIRST_PAGE_MEM_FREE to location $8000, i.e. bank in RAM page which starts
    ; at $028000
    lda #FIRST_PAGE_MEM_FREE
    sta 12
    rts


restoreMMU
    ; restore MMU state
    lda COPY_RES.mmuState
    sta 12
    rts

.endnamespace