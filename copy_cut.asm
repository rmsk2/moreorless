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
    old       .dstruct FarPtr_t 
    start     .dstruct FarPtr_t
    len       .word 0
    ctr       .word 0
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
    #changeLine list.setTo
    clc
    rts
_outOfMemory
    ; we have run out of memory => clear clipboard
    jsr clear
_genericError
    ; restore list pointer to the value which we saw at the begining
    #copyMem2Mem CPCT_PARMS.old, list.SET_PTR
    #changeLine list.setTo
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
; Carry is set upon return if an error. Which can only happen when parameters are wrong. In essence
; this routine can nor fail, as it does not perform any memory allocations.
LEN_TEMP .word 0
cutSegement
    cmp16BitImmediate 0, CPCT_PARMS.len
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
    rts


; Pastes the clipboard below the current line of the document. Carry is set if this routine fails
; (due to running out of memory).
pasteSegment
    ; nothing todo if len is zero
    #cmp16BitImmediate 0, CLIP.length
    bne _doWork
    clc
    rts
_doWork    
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
    jsr toClip
    jsr list.destroy
    jsr toDocument
    #copyMem2Mem NIL, CLIP.head
    #copyMem2Mem NIL, CLIP.current
    #load16BitImmediate 0, CLIP.length    
_done
    rts


init
    #copyMem2Mem NIL, CLIP.head
    #copyMem2Mem NIL, CLIP.current
    #load16BitImmediate 0, CLIP.length
    rts


.endnamespace