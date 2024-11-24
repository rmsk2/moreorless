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


HELP_OFFSET .word 0
; carry is set if this fails. Currently does no reformatting but implements the 
; most basic expected behaviour: i.e. make last line inserted the current line, 
; set CPCT_PARMS.reformatLen and set carry if out of memory occurs
reformatSegment
    lda CPCT_PARMS.len
    sta CPCT_PARMS.reformatLen
    #copyMem2Mem CPCT_PARMS.start, list.SET_PTR
    #changeLine list.setTo
    #move16Bit CPCT_PARMS.len, HELP_OFFSET
    #dec16Bit HELP_OFFSET
    ldx HELP_OFFSET
    lda HELP_OFFSET + 1
    jsr list.move
    jsr list.readCurrentLine
    clc
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