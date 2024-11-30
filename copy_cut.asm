clip .namespace

CLIP     .dstruct List_t
DOCUMENT .dstruct List_t


; --------------------------------------------------
; This routine saves the current values stored in the list.LIST
; struct to the memory location to which CLIP_PTR2 points.
;
; This routine does not return a value.
; --------------------------------------------------
saveList
    #copyStructToPtr list.LIST, CLIP_PTR2, size(List_t)
    rts


; --------------------------------------------------
; This routine restores the saved list.LIST struct from
; the memory location to which CLIP_PTR1 points.
;
; This routine does not return a value.
; --------------------------------------------------
restoreList
    #copyPtrToStruct CLIP_PTR1, list.LIST, size(List_t)
    rts


toClip
    #load16BitImmediate DOCUMENT, CLIP_PTR2
    #load16BitImmediate CLIP, CLIP_PTR1
    jsr saveList
    jsr restoreList
    rts


toDocument
    #load16BitImmediate CLIP, CLIP_PTR2
    #load16BitImmediate DOCUMENT, CLIP_PTR1
    jsr saveList
    jsr restoreList
    rts


CopyCutParam_t .struct
    old         .dstruct FarPtr_t 
    start       .dstruct FarPtr_t
    len         .word 0
    ctr         .word 0
    reformatLen .word 0
.endstruct

CPCT_PARMS .dstruct CopyCutParam_t


copyClipLine
    jsr toClip
    ; set data in current node of clipboard list
    jsr list.setCurrentLine
    ; switch back to document
    php
    jsr toDocument
    plp
    rts


appendClipLine
    jsr toClip
    ; set data in current node of clipboard list
    jsr list.insertAfter
    ; switch back to document
    php
    jsr toDocument
    plp
    rts


nextClipLine
    jsr toClip
    jsr list.next
    jsr toDocument
    rts

; This routine copies CPCT_PARAMS.len lines from the document starting with the one given in
; CPCT_PARAMS.start to the clipboard.
;
; carry is set upon return if an error (i.e. out of memory) occurred. The current document 
; list pointer is restored to the value it had before the call.
copySegment
    ; nothing todo if len is zero
    #cmp16BitImmediate 0, CPCT_PARMS.len
    bne _doWork
    clc
    rts
_doWork
    ; save current list state
    #copyMem2Mem list.LIST.current, CPCT_PARMS.old
    ; clear current clipboard list
    jsr clear
    ; create an empty clipboard list which has one (still empty) line
    jsr new
    bcc _goOn
    ; we can not clear the clipboard list as it was not allocated
    jmp _genericError
_goOn
    ; set copy counter to 0
    #load16BitImmediate 0, CPCT_PARMS.ctr
    ; set pointer in document to start element for copy and fill LINE_BUFFER
    #copyMem2Mem CPCT_PARMS.start, list.SET_PTR
    #changeLine list.setTo
_copyLoop
    ; use contents of LINE_BUFFER to fill current clipboard element
    jsr copyClipLine
    bcc _nextLine
    jmp _outOfMemory
_nextLine
    ; test whether all requested elements were copied
    #inc16Bit CPCT_PARMS.ctr
    #cmp16Bit CPCT_PARMS.ctr, CPCT_PARMS.len
    bcs _done                                            ; all elements have been copied
    ; goto next element in document and fill LINE_BUFFER
    #changeLine list.next
    bcs _done                                            ; we are at the end of the document, nothing can be done anymore
    ; insert new (empty) line in clipboard list
    jsr appendClipLine
    bcs _outOfMemory
    ; move list pointer in clipboard list to the new element
    jsr nextClipLine
    bra _copyLoop
_done
    ; restore list pointer to the value which we saw at the begining
    #copyMem2Mem CPCT_PARMS.old, list.SET_PTR
    jsr list.setTo
    jsr list.readCurrentLine
    clc
    rts
_outOfMemory
    ; we have run out of memory => clear clipboard
    jsr clear
_genericError
    ; restore list pointer to the value which we saw at the begining
    #copyMem2Mem CPCT_PARMS.old, list.SET_PTR
    jsr list.setTo
    jsr list.readCurrentLine
    sec
    rts


; This routine deletes CPCT_PARMS.len lines from the document starting with the one given in
; CPCT_PARMS.start from the document and makes them the new clipboard. 
;
; After the call the current document list pointer is set to the element preceeding the first element 
; of the cut. If that does not exist (because the cut starts at element 1) the new current pointer is 
; the one following the last element of the cut. You must not remove all elements from the list as a
; document always contains at least one line.
;
; Carry is set upon return if an error occurred. Which can only happen when parameters are wrong. In 
; essence this routine can nor fail, as it does not perform any memory allocations.
LEN_TEMP .word 0
cutSegement
    #cmp16BitImmediate 0, CPCT_PARMS.len
    bne _checkMaxLen
    ; Length has to be at least one
    sec
    rts
_checkMaxLen
    #cmp16Bit CPCT_PARMS.len, list.LIST.length
    bcc _doCut
    ; we can not cut all lines from the document. A document has to have at least one line (which 
    ; on the other hand can be empty)
    rts
_doCut
    ; free current clipboard contents
    jsr clear
    ; move to start element
    #copyMem2Mem CPCT_PARMS.start, list.SET_PTR
    #changeLine list.setTo
    ; calculate offset for list.split => offset is length - 1
    #move16Bit CPCT_PARMS.len, LEN_TEMP
    #dec16Bit LEN_TEMP
    ldx LEN_TEMP
    lda LEN_TEMP + 1
    ; due to the checks above this call can not fail
    jsr list.split
    ; make sure data of current line is in LINE_BUFFER
    jsr list.readCurrentLine
    ; setup CLIP structure
    #copyMem2Mem list.SPLIT_RESULT.start, CLIP.head
    #copyMem2Mem list.SPLIT_RESULT.start, CLIP.current
    #move16Bit list.SPLIT_RESULT.splitLen, CLIP.length
    clc
    rts


; Pastes the clipboard below the current line of the document. Carry is set if this routine fails
; (due to running out of memory). The current element after the paste is set to the last line
; pasted
pasteSegment
    ; nothing todo if len is zero
    #cmp16BitImmediate 0, CLIP.length
    bne _doWork
    clc
    rts
_doWork
    ; make sure we save last changes to the current line of the document, i.e. we copy
    ; the data from LINE_BUFFER into the document
    jsr list.setCurrentLine
    ; switch to CLIP as the current list element
    jsr toClip
    ; goto first element and fill LINE_BUFFER
    jsr list.rewind
    jsr list.readCurrentLine
_pasteLoop
    ; copy clipboard data to document    
    jsr toDocument
    ; add new line to document
    jsr list.insertAfter
    bcs _doneError
    ; move to that line
    jsr list.next
    ; copy data from LINE_BUFFER into this line
    jsr list.setCurrentLine
    bcs _doneError
    ; switch back to clipboard
    jsr toClip
    jsr list.next
    bcc _oneMoreLine
    ; we have reached the end of the clipboard => we are done
    jsr toDocument
    jsr list.readCurrentLine
    bra _doneOK
_oneMoreLine    
    ; fill LINE_BUFFER with clipboard data
    jsr list.readCurrentLine
    bra _pasteLoop
_doneOK
    clc
_doneError
    rts

CopyRegion_t .struct
    lineCounter .word 0
    ptrScratch  .dstruct FarPtr_t
    copyOk      .byte 0
.endstruct

COPY_REGION .dstruct CopyRegion_t

; store a cleaned up version of the selected region at $028000
; Errors are signalled through COPY_REGION.copyOk.
copyRegion
    jsr line.initCopyRes
    ; reset values to start configuration
    lda #BOOL_TRUE
    sta COPY_REGION.copyOk
    #load16BitImmediate 0, COPY_REGION.lineCounter

    ; save current list pointer
    #copyMem2Mem list.LIST.current, COPY_REGION.ptrScratch
    ; goto start of region
    #copyMem2Mem CPCT_PARMS.start, list.SET_PTR
    #changeLine list.setTo                            ; ** This saves possible changes in LINE_BUFER.buffer to linked list
    jsr line.initMMU
_lineLoop
    jsr line.procLine                                 ; copy and clean up current line
    bcs _cutOff                                       ; region was too large
    jsr list.next                                     ; No #changeLine: Here the linked list has to be current due to **
    jsr list.readCurrentLine                          ; copy text of line into LINE_BUFFER
    #inc16Bit COPY_REGION.lineCounter
    #cmp16Bit CPCT_PARMS.len, COPY_REGION.lineCounter ; have we processed the desired number of lines?
    bne _lineLoop                                     ; more lines
    ; write an entry with length zero as an end marker
    jsr line.writeEndMarker
    bcs _cutOff
    bra _copySuccess                                  ; we are done and we were successfull
_cutOff
    ; we have reached the length limit
    lda #BOOL_FALSE
    sta COPY_REGION.copyOk
_copySuccess
    jsr line.restoreMMU
    ; restore list pointer to the value it had at start
    #copyMem2Mem COPY_REGION.ptrScratch, list.LIST.current
    jsr list.readCurrentLine                           ; copy line contents from linked list to LINE_BUFFER
    rts


readByteLines
#readByteLinear $8000, BASIC_PTR

createClipCleanUp .macro
    jsr line.restoreMMU
    jsr toDocument
    jsr list.readCurrentLine
.endmacro

WORD_LEN     .byte 0
SPACE_OFFSET .byte 0

; This routine creates the reformatted clipboard contents using the word list
; generated by the subroutine copyRegion.
;
; Carry is set if an error was encountered.
createClipFromMemory
    jsr clear
    jsr new
    bcc _l1
    jmp _outOfMemory
_l1
    #load16BitImmediate $8000, BASIC_PTR
    stz SPACE_OFFSET
    jsr toClip
    jsr list.readCurrentLine
    jsr line.initMMU
_wordLoop
    jsr readByteLines
    cmp #0
    beq _doneOK                                       ; end marker reached => we are done
    sta WORD_LEN
    ; check line length with new word
    clc
    adc LINE_BUFFER.len
    adc SPACE_OFFSET
    cmp #line.MAX_WORD_LEN
    beq _doCopy
    bcc _doCopy
    ; new line is reached
    jsr list.setCurrentLine                           ; save state of current line
    bcs _outOfMemory
    ; add new line
    jsr list.insertAfter
    bcs _outOfMemory
    ; switch to new line
    jsr list.next
    jsr list.readCurrentLine
    lda #0
    sta SPACE_OFFSET
_doCopy
    ; copy word into line
    ldy LINE_BUFFER.len
    lda SPACE_OFFSET
    beq _noSpace                                       ; first word in line => skip space
    lda #line.SPACE_CHAR
    sta LINE_BUFFER.buffer, y
    iny
_noSpace    
    ldx #0
_copyLoop
    jsr readByteLines
    sta LINE_BUFFER.buffer, y
    iny
    inx
    cpx WORD_LEN
    bne _copyLoop
    ; from now on we also add a space character
    sty LINE_BUFFER.len
    lda #1
    sta SPACE_OFFSET
    bra _wordLoop
_doneOK
    jsr list.setCurrentLine
    php
    #createClipCleanUp
    plp
    rts
_outOfMemory
    #createClipCleanUp
    sec
    rts


Reformat_t .struct
    helpOffset  .word 0
    extraLine   .dstruct FarPtr_t
    scratchPtr  .dstruct FarPtr_t   
.endstruct

REFORMAT .dstruct Reformat_t

; Reformats a region which is specified by CPCT_PARMS. It does this in the
; following way:
;
; 1. Create a word list in memory at $028000 for all lines which are part
;    of the region. This may fail if the word list does not fit in 56K
; 2. Check if the segement to reformat starts at the top of the document.
;    If yes: Insert an empty dummy line which becomes the new first line
; 3. Then cut the segment from the document and free the clipboard. Inserting
;    the dummy line guarantees that the current list element after the cut
;    can be used as the location from where the newly created and reformatted
;    clipboard contents can be pasted,
; 4. Then create a new clipboard from the word list in memory
; 5. Paste the current clipboard and clear the clipboard
; 6. Remove the dummy line if it was inserted
; 7. Make sure the current element after the call is the last line which
;    was pasted.
;
; This routine does not allow to reformat the whole document. If this is detected
; or if creating the word list fails then no reformatting is performed. In this case
; the current element is moved to the last line of the selected region and then
; the subroutine ends.
;
; Carry is set if an error occurred
reformatSegment
    ; The segment must not contain the whole document
    #cmp16Bit CPCT_PARMS.len, list.LIST.length
    bcc _lenOk
    jmp _doNothing
_lenOK
    jsr copyRegion
    lda COPY_REGION.copyOk
    bne _copySuccess
    jmp _doNothing
_copySuccess
    ; set REFORMAT.extraLine to NIL
    #copyMem2Mem NIL, REFORMAT.extraLine

    ; check if beginning of segment to reformat is the first line
    #copyMem2Mem CPCT_PARMS.start, list.SET_PTR
    jsr list.setTo
    jsr list.getFlags
    and #FLAG_IS_FIRST    
    beq _noInsert
    ; it is the first line => We insert a new pseudo line in order to make handling
    ; of edge cases easier
    jsr list.insertBefore
    ; get address of newly inserted element and store it in REFORMAT.extraLine
    #SET_MMU_ADDR list.LIST.current
    #move16Bit list.LIST.current, PTR_CURRENT
    #copyPtr2Mem PTR_CURRENT, Line_t.prev, REFORMAT.extraLine
_noInsert
    ; cutSegement can not fail due to the length check at the beginning of this subroutine
    jsr cutSegement
    ; current element is the line preceeding the segment to reformat
    jsr createClipFromMemory
    bcc _ok1
    jmp _outOfMemory
_ok1
    jsr pasteSegment
    bcc _ok2
    jmp _outOfMemory
_ok2
    ; current element is the last line inserted
    #move16Bit CLIP.length, CPCT_PARMS.reformatLen
    ; clear clipboard
    jsr clear
    ; Do we need to remove a pseudo line?
    #IS_NIL_ADDR REFORMAT.extraLine
    bne _undoPseudoLine
    jmp _doneOK 
_undoPseudoLine    
    ; remove inserted pseudo line    
    #copyMem2Mem list.LIST.current, REFORMAT.scratchPtr
    #copyMem2Mem REFORMAT.extraLine, list.SET_PTR
    jsr list.setTo
    jsr list.remove
    #copyMem2Mem REFORMAT.scratchPtr, list.SET_PTR
    jsr list.setTo
    jmp _doneOK
_doNothing
    lda CPCT_PARMS.len
    sta CPCT_PARMS.reformatLen
    #copyMem2Mem CPCT_PARMS.start, list.SET_PTR
    #changeLine list.setTo
    #move16Bit CPCT_PARMS.len, REFORMAT.helpOffset
    #dec16Bit REFORMAT.helpOffset
    ldx REFORMAT.helpOffset
    lda REFORMAT.helpOffset + 1
    jsr list.move
_doneOK
    jsr list.readCurrentLine
    clc
    rts
_outOfMemory
    sec
    rts


new
    jsr toClip
    jsr list.create
    php
    jsr toDocument
    plp
    rts


clear
    #IS_NIL_ADDR CLIP.head
    beq _done
    jsr list.setCurrentLine
    jsr toClip
    jsr list.destroy
    jsr toDocument
    jsr list.readCurrentLine
    #copyMem2Mem NIL, CLIP.head
    #copyMem2Mem NIL, CLIP.current
    #load16BitImmediate 0, CLIP.length    
_done
    rts


LineClip_t .struct 
    buffer    .fill search.MAX_CHARS_TO_CONSIDER
    lenBuffer .byte 0
    startPos  .byte 0
    lenCopy   .byte 0
.endstruct

LINE_CLIP .dstruct LineClip_t

lineClipCopy
    ; save current state of line to linked list
    jsr list.setCurrentLine
    bcs outOfMemoryCopy
lineClipCopyInt
    lda LINE_BUFFER.len
    bne _notEmpty
    ; line is empty => there is noting to copy here
    stz LINE_CLIP.lenBuffer
    rts
_notEmpty
    ldy LINE_CLIP.startPos
    ldx #0
_loopChars
    cpx LINE_CLIP.lenCopy
    beq _done
    lda LINE_BUFFER.buffer, y
    sta LINE_CLIP, x
    inx
    iny
    bra _loopChars
_done
    stx LINE_CLIP.lenBuffer
_doNothing
    rts
outOfMemoryCopy
    jmp (OUT_OF_MEMORY)


lineClipCut
    ; save current state of line to linked list
    jsr list.setCurrentLine
    bcs _outOfMemory
    lda LINE_CLIP.lenCopy
    ; lenCopy is 0 => set LINE_CLIP.lenBuffer to zero and do nothing. Via the UI this can never happen
    bne _testEmpty
    stz LINE_CLIP.lenBuffer
    rts
_testEmpty    
    lda LINE_BUFFER.len
    bne _notEmpty
    ; line is empty => there is noting to cut here. Set LINE_CLIP.lenBuffer to zero.
    stz LINE_CLIP.lenBuffer
    rts
_notEmpty
    ; lenCopy and length of line are at least one if we get here => copy part of line which is to be deleted. 
    jsr lineClipCopyInt
    ; now cut out desired section
    lda LINE_CLIP.startPos
    tax
    clc
    adc LINE_CLIP.lenCopy
    tay
_cutLoop
    cpy LINE_BUFFER.len
    beq _cutFinished
    lda LINE_BUFFER.buffer, y
    sta LINE_BUFFER.buffer, x
    inx
    iny
    bra _cutLoop
_cutFinished
    ; Adapt length of line and save its changed value to the linked list
    lda LINE_BUFFER.len
    sec
    sbc LINE_CLIP.lenCopy
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcs _outOfMemory
_done
    rts
_outOfMemory
    jmp (OUT_OF_MEMORY)


CUR_CLIP_POS .byte 0
INSERT_POS   .byte 0
ORG_LEN      .byte 0
; carry is set if inserting LINE_CLIP leads to a line that would be too long. Insert pos is in accu.
lineClipPaste
    sta INSERT_POS
    ; save current state of line to linked list
    jsr list.setCurrentLine
    bcs _outOfMemory
    ; do nothing if LINE_CLIP is empty
    lda LINE_CLIP.lenBuffer
    beq _notAllowed
    ; do nothing if overall length would be beyond 80 characters
    lda LINE_BUFFER.len
    sta ORG_LEN
    clc
    adc LINE_CLIP.lenBuffer
    cmp #search.MAX_CHARS_TO_CONSIDER
    beq _allowed
    bcs _notAllowed
_allowed
    ; increase length of line buffer
    sta LINE_BUFFER.len
    lda ORG_LEN
    cmp INSERT_POS
    ; We have to move stuff around
    bne _makeRoom
    ; This is not an insert, we only append
    beq _copyNewChars
_makeRoom
    ; here the length of the new line is at least two and we have to
    ; move at least one char out of the way
    ldy LINE_BUFFER.len
    dey
    tya
    sec
    sbc LINE_CLIP.lenBuffer
    tax
_expandLoop
    lda LINE_BUFFER.buffer, x
    sta LINE_BUFFER.buffer, y
    cpx INSERT_POS
    beq _copyNewChars
    dex
    dey
    bra _expandLoop
_copyNewChars
    ldx #0
    ldy INSERT_POS
_copyLoop
    lda LINE_CLIP.buffer, x
    sta LINE_BUFFER.buffer, y
    inx
    iny
    cpx LINE_CLIP.lenBuffer
    bne _copyLoop
    jsr list.setCurrentLine
    bcs _outOfMemory
    clc
    rts
_notAllowed
    sec
    rts
_outOfMemory
    jmp (OUT_OF_MEMORY)


init
    #copyMem2Mem NIL, CLIP.head
    #copyMem2Mem NIL, CLIP.current
    #load16BitImmediate 0, CLIP.length
    stz LINE_CLIP.lenBuffer
    rts


.endnamespace