FLAG_IS_FIRST = 1
FLAG_IS_LAST = 2

List_t .struct 
    head    .dstruct FarPtr_t
    current .dstruct FarPtr_t
    length  .word 0
.endstruct

OUT_OF_MEMORY .word panic

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


list .namespace

NEW      .dstruct FarPtr_t
OLD_PREV .dstruct FarPtr_t
OLD_NEXT .dstruct FarPtr_t
TEMP     .dstruct FarPtr_t

LIST .dstruct List_t

; func (l *List) Remove() {
; 	if l.Length == 1 {
; 		return
; 	}
;
; 	switch {
; 	case (l.Current.Flags & FLAG_IS_LAST) != 0:
; 		temp := l.Current.Prev
; 		temp.Next = nil
; 		temp.Flags |= FLAG_IS_LAST
; 		// free l.Current and its subblocks
; 		l.Current = temp
; 	case (l.Current.Flags & FLAG_IS_FIRST) != 0:
; 		temp := l.Current.Next
; 		temp.Prev = nil
; 		temp.Flags |= FLAG_IS_FIRST
; 		// free l.Current and its subblocks
; 		l.Current = temp
; 		l.Head = temp
; 	default:
; 		oldPrev := l.Current.Prev
; 		oldNext := l.Current.Next
; 		oldPrev.Next = oldNext
; 		oldNext.Prev = oldPrev
; 		// free l.Current and its subblocks
; 		l.Current = oldNext
; 	}
;
; 	l.Length--
; }
;
; PUBLIC: remove current element from list and free its memory.
; If this routine fails the carry is set upon return.
remove
    ; if l.Length == 1 {
    ; 	return
    ; }
    #cmp16BitImmediate 1, LIST.length
    bne _atLeastTwo
    sec
    rts
_atLeastTwo
    #move16Bit LIST.current, PTR_CURRENT
    #SET_MMU_ADDR LIST.current
    ldy #Line_t.flags
    lda (PTR_CURRENT), y
    cmp #FLAG_IS_LAST
    bne _checkNext
    jmp _removeLast
_checkNext    
    cmp #FLAG_IS_FIRST
    bne _default
    jmp _removeFirst
_default
    ; MMU is at page of LIST.current
    ; oldPrev := l.Current.Prev    
    #copyPtr2Mem PTR_CURRENT, Line_t.prev, OLD_PREV
    #move16Bit OLD_PREV, PTR_OLD_PREV
    ; oldNext := l.Current.Next
    #copyPtr2Mem PTR_CURRENT, Line_t.next, OLD_NEXT
    #move16Bit OLD_NEXT, PTR_OLD_NEXT
    ; oldPrev.Next = oldNext
    #SET_MMU_ADDR OLD_PREV
    #copyMem2Ptr OLD_NEXT, PTR_OLD_PREV, Line_t.next
    ; oldNext.Prev = oldPrev
    #SET_MMU_ADDR OLD_NEXT
    #copyMem2Ptr OLD_PREV, PTR_OLD_NEXT, Line_t.prev
    ; free l.Current and its subblocks
    ; free subblocks
    jsr freeCurrentLine
    #load16BitImmediate LIST.current, MEM_PTR3
    ; free Line
    jsr memory.freePtr
    ; l.Current = oldNext    
    #copyMem2Mem OLD_NEXT, LIST.current
    jmp _doneOK
_removeLast
    ; MMU is at page of LIST.current
    ; temp := l.Current.Prev
    #copyPtr2Mem PTR_CURRENT, Line_t.prev, TEMP
    #move16Bit TEMP, PTR_TEMP
    ; temp.Next = nil
    #SET_MMU_ADDR TEMP
    #copyMem2Ptr NIL, PTR_TEMP, Line_t.next
    ; temp.Flags |= FLAG_IS_LAST
    lda #FLAG_IS_LAST
    ldy #Line_t.flags
    ora (PTR_TEMP), y
    sta (PTR_TEMP), y
    ; free subblocks
    jsr freeCurrentLine
    #load16BitImmediate LIST.current, MEM_PTR3
    ; free Line
    jsr memory.freePtr
    ; l.Current = temp
    #copyMem2Mem TEMP, LIST.current
    bra _doneOK
_removeFirst
    ; MMU is at page of LIST.current
    ; temp := l.Current.Next
    #copyPtr2Mem PTR_CURRENT, Line_t.next, TEMP
    #move16Bit TEMP, PTR_TEMP
    ; temp.Prev = nil
    #SET_MMU_ADDR TEMP
    #copyMem2Ptr NIL, PTR_TEMP, Line_t.prev
    ; temp.Flags |= FLAG_IS_FIRST
    lda #FLAG_IS_FIRST
    ldy #Line_t.flags
    ora (PTR_TEMP), y
    sta (PTR_TEMP), y
    ; free subblocks
    jsr freeCurrentLine
    #load16BitImmediate LIST.current, MEM_PTR3
    ; free Line
    jsr memory.freePtr
    ; l.Current = temp
    #copyMem2Mem TEMP, LIST.current
    ; l.Head = temp
    #copyMem2Mem TEMP, LIST.head
_doneOK
    #dec16Bit LIST.length
    clc
    rts


Split_t .struct 
    start      .dstruct FarPtr_t
    end        .dstruct FarPtr_t
    splitLen   .word 0
    forward    .byte 0
    flagsFirst .byte 0
    flagsLast  .byte 0
.endstruct

SPLIT_RESULT .dstruct Split_t
; PUBLIC: This routine removes the sublist which is bounded by the current list element and the element
; that can be reached by moving the current pointer using the signend offset given in accu (hi) and x (lo) 
; from the list. The removed elements remain intact and are not freed. This is intended to support cutting 
; lines from a document.
;
; After the call the current document list pointer is set to the element preceeding the first element 
; of the cut. If that does not exist (because the cut starts at element 1) the new current pointer is 
; the one following the last element of the cut. You must not remove all elements from the list as a
; document always contains at least one line. 
;
; SPLIT_RESULT.start and end point to the start and end of the removed sublist. SPLIT_RESULT.splitLen 
; contains the length of the sublist.
;
; Carry is set upon return if a split is not possible. Otherwise it is clear.
split
    ; store parameters
    sta MOVE_HELP.offsetH
    sta SPLIT_RESULT.splitLen + 1
    stx MOVE_HELP.offsetL
    stx SPLIT_RESULT.splitLen
    ; offset 0 is valid, it represents a cut length of 1.
    ; check if number of elements to cut >= overall length of list
    lda SPLIT_RESULT.splitLen + 1
    bpl _checkLen
    ; negate to get absolute value
    #twosComplement16 SPLIT_RESULT.splitLen
_checkLen
    ; the length of the cut is one more that the offset
    #inc16Bit SPLIT_RESULT.splitLen
    #cmp16Bit SPLIT_RESULT.splitLen, LIST.length
    bcc _doProcess
    ; Caller wants to cut more elements than exist (or all) => not possible
    ; a document always has to contain at least one element. Here the
    ; carry is set.
    rts
_doProcess
    ; length of cut is less than current list length
    ; set direction to forward
    lda #BOOL_TRUE
    sta SPLIT_RESULT.forward
    ; check if offset is negative
    lda MOVE_HELP.offsetH
    bpl _offsetPositive                                   ; => no, it is positive
    ; set direction to backward
    lda #BOOL_FALSE
    sta SPLIT_RESULT.forward
    ; current element is last element in cut
    #copyMem2Mem LIST.current, SPLIT_RESULT.end
    bra _goOn
_offsetPositive
    ; current element is first element in cut
    #copyMem2Mem LIST.current, SPLIT_RESULT.start
_goOn
    lda MOVE_HELP.offsetH
    ldx MOVE_HELP.offsetL
    ; move to other bounding element
    jsr move
    lda SPLIT_RESULT.forward
    bne _forward
    ; we have moved backward => this is the start element of the cut
    #copyMem2Mem LIST.current, SPLIT_RESULT.start
    bra _goOn2
_forward
    ; we have moved forward => this is the last element of the cut
    #copyMem2Mem LIST.current, SPLIT_RESULT.end    
_goOn2
    ; Here we know the bounding elements of the cut. Now we have to remove
    ; these and all in between (if they exist) from the list and set the flags 
    ; current and head of the modified list as well as the flags on the removed 
    ; list.
    #copyMem2Mem SPLIT_RESULT.start, SET_PTR
    jsr setTo
    jsr getFlags
    sta SPLIT_RESULT.flagsFirst
    #copyMem2Mem SPLIT_RESULT.end, SET_PTR
    jsr setTo
    jsr getFlags
    sta SPLIT_RESULT.flagsLast
    
    lda SPLIT_RESULT.flagsFirst
    and #FLAG_IS_FIRST
    beq _notFirst
    ; first element of cut is first element of list. Note that due to the
    ; fact that the cut is smaller than the list this means that this element
    ; can not also be the last element in the list. Also note that the first
    ; element in the cut can only be the last element of the list if the cut
    ; length is one and thereore the first and the last element of the cut are
    ; the same. This case is correctly handled with the following test.
    #SET_MMU_ADDR SPLIT_RESULT.end
    #move16Bit SPLIT_RESULT.end, PTR_TEMP
    ; copy next ptr of last element in cut. This is the new head of the list
    ; and the new current element
    #copyPtr2Mem PTR_TEMP, Line_t.next, OLD_NEXT
    #SET_MMU_ADDR OLD_NEXT
    #move16Bit OLD_NEXT, PTR_OLD_NEXT
    ; make the prev of the new head nil
    #copyMem2Ptr NIL, PTR_OLD_NEXT, Line_t.prev
    ; set flags of this element accordingly
    lda #FLAG_IS_FIRST
    ldy #Line_t.flags
    ora (PTR_OLD_NEXT), y
    sta (PTR_OLD_NEXT), y
    ; set head and new current element
    #copyMem2Mem OLD_NEXT, LIST.head
    #copyMem2Mem OLD_NEXT, LIST.current
    jmp _makeCutValidList
_notFirst
    lda SPLIT_RESULT.flagsLast
    and #FLAG_IS_LAST
    beq _notLast
    ; last element of cut is last element in list. Note that due to the
    ; fact that the cut is smaller than the list this means that this element
    ; can not also be the first element in the list.
    #SET_MMU_ADDR SPLIT_RESULT.start
    #move16Bit SPLIT_RESULT.start, PTR_TEMP
    ; get prev of first element of cut this is the last element of the new list.
    ; This is also the new current element of the list
    #copyPtr2Mem PTR_TEMP, Line_t.prev, OLD_PREV
    #SET_MMU_ADDR OLD_PREV
    #move16Bit OLD_PREV, PTR_OLD_PREV
    #copyMem2Ptr NIL, PTR_OLD_PREV, Line_t.next
    ; set flags
    lda #FLAG_IS_LAST
    ldy #Line_t.flags
    ora (PTR_OLD_PREV), y
    sta (PTR_OLD_PREV), y
    ; set new current element
    #copyMem2Mem OLD_PREV, LIST.current
    jmp _makeCutValidList
_notLast
    ; the cut does not contain the first or the last element of the list, therefore
    ; we do not have to fiddle with the flags

    ; copy prev of start element of cut to OLD_PREV
    #SET_MMU_ADDR SPLIT_RESULT.start
    #move16Bit SPLIT_RESULT.start, PTR_TEMP
    #copyPtr2Mem PTR_TEMP, Line_t.prev, OLD_PREV
    ; copy next of end element of cut to OLD_NEXT
    #SET_MMU_ADDR SPLIT_RESULT.end
    #move16Bit SPLIT_RESULT.end, PTR_TEMP
    #copyPtr2Mem PTR_TEMP, Line_t.next, OLD_NEXT
    ; set next of OLD_PREV to OLD_NEXT
    #SET_MMU_ADDR OLD_PREV
    #move16Bit OLD_PREV, PTR_OLD_PREV
    #copyMem2Ptr OLD_NEXT, PTR_OLD_PREV, Line_t.next
    ; set prev of OLD_NEXT to OLD_PREV
    #SET_MMU_ADDR OLD_NEXT
    #move16Bit OLD_NEXT, PTR_OLD_NEXT
    #copyMem2Ptr OLD_PREV, PTR_OLD_NEXT, Line_t.prev
    ; set current to element preceeding the split
    #copyMem2Mem OLD_PREV, LIST.current
_makeCutValidList
    ; adapt length of original list
    #sub16Bit SPLIT_RESULT.splitLen, LIST.length
    ; set flags on first element of cut.
    #SET_MMU_ADDR SPLIT_RESULT.start
    #move16Bit SPLIT_RESULT.start, PTR_TEMP
    ldy #Line_t.flags
    ; overwrite existing flags.
    lda #FLAG_IS_FIRST
    sta (PTR_TEMP),y
    ; set prev of first element to NIL
    #copyMem2Ptr NIL, PTR_TEMP, Line_t.prev

    ; set flags on last element of cut
    #SET_MMU_ADDR SPLIT_RESULT.end
    #move16Bit SPLIT_RESULT.end, PTR_TEMP
    ldy #Line_t.flags
    lda (PTR_TEMP), y
    ; last and first could be equal => use ora
    ora #FLAG_IS_LAST
    sta (PTR_TEMP), y
    ; set next of last element to NIL
    #copyMem2Ptr NIL, PTR_TEMP, Line_t.next
    clc
    rts


; func (l *List) InsertBefore() {
; 	newItem := NewLine(0)
;
; 	if (l.Current.Flags & FLAG_IS_FIRST) != 0 {
; 		l.Current.Flags = l.Current.Flags & ^FLAG_IS_FIRST
; 		newItem.Flags = newItem.Flags | FLAG_IS_FIRST
; 		newItem.Next = l.Current
; 		l.Current.Prev = newItem
; 		l.Head = newItem
; 	} else {
; 		oldPrev := l.Current.Prev
; 		oldPrev.Next = newItem
; 		l.Current.Prev = newItem
; 		newItem.Prev = oldPrev
; 		newItem.Next = l.Current
; 	}
;
; 	l.Length++
; }
;
; PUBLIC: Insert new element before the current element
; If this routine fails the carry is set upon return.
insertBefore
    jsr allocNewLine
    bcc _allocSuccess
    rts
_allocSuccess
    #move16Bit LIST.current, PTR_CURRENT
    #SET_MMU_ADDR LIST.current
    ; copy flags
    ldy #Line_t.flags
    lda (PTR_CURRENT), y
    sta ORIG_FLAGS

    ; test flags of current element
    and #FLAG_IS_FIRST
    beq _normal
_atStart
    ; we are at the current start of the list
    lda #FLAG_IS_FIRST
    eor #$FF
    sta MASK_TEMP
    ; l.Current.Flags = l.Current.Flags & ^FLAG_IS_FIRST
    ldy #Line_t.flags
    lda (PTR_CURRENT), y
    and MASK_TEMP
    sta (PTR_CURRENT), y

    #SET_MMU_ADDR NEW
    ; newItem.Flags = newItem.Flags | FLAG_IS_FIRST
    ldy #Line_t.flags
    lda #FLAG_IS_FIRST
    sta (PTR_NEW), y
    ;
    ; newItem.Next = l.Current
    #copyMem2Ptr LIST.current, PTR_NEW, Line_t.next
    ;l.Current.Prev = newItem
    #SET_MMU_ADDR LIST.current
    #copyMem2Ptr NEW, PTR_CURRENT, Line_t.prev 
    ; l.Head = newItem
    #copyMem2Mem NEW, LIST.head
    bra _doneOK
_normal
    ; here MMU is at page of LIST.current
    ; oldPrev := l.Current.Prev
    #copyPtr2Mem PTR_CURRENT, Line_t.prev, OLD_PREV
    #move16Bit OLD_PREV, PTR_OLD_PREV
    ; l.Current.Prev = newItem
    #copyMem2Ptr NEW, PTR_CURRENT, Line_t.prev
    ; oldPrev.Next = newItem
    #SET_MMU_ADDR OLD_PREV
    #copyMem2Ptr NEW, PTR_OLD_PREV, Line_t.next
    ; newItem.Prev = oldPrev
    #SET_MMU_ADDR NEW
    #copyMem2Ptr OLD_PREV, PTR_NEW, Line_t.prev
    ; newItem.Next = l.Current
    #copyMem2Ptr LIST.current, PTR_NEW, Line_t.next
_doneOK
    #inc16Bit LIST.length
    clc
    rts


; Allocate and initialize a new line. Carry is set if an error occurred.
; If the routine was successfull NEW and PTR_NEW point the newly allocated
; line and the MMU is configured to bank in the new line.
allocNewLine
    #load16BitImmediate NEW, MEM_PTR3
    ; allocate a new Line_t struct
    jsr memory.allocPtr
    bcs _done
    #SET_MMU_ADDR NEW
    #move16Bit NEW, MEM_PTR3    
    jsr line.init
    #move16Bit NEW, PTR_NEW
    clc
_done
    rts    


MASK_TEMP  .byte 0
ORIG_FLAGS .byte 0

; func (l *List) InsertAfter() {
; 	newItem := NewLine(0)
;
; 	if (l.Current.Flags & FLAG_IS_LAST) != 0 {
; 		l.Current.Flags = l.Current.Flags & ^FLAG_IS_LAST
; 		newItem.Flags = newItem.Flags | FLAG_IS_LAST
; 		l.Current.Next = newItem
; 		newItem.Prev = l.Current
; 	} else {
; 		oldNext := l.Current.Next
; 		l.Current.Next = newItem
; 		oldNext.Prev = newItem
; 		newItem.Prev = l.Current
; 		newItem.Next = oldNext
; 	}
;
; 	l.Length++
; }
;
; PUBLIC: Append a new empty line after the current item
; If this routine fails the carry is set upon return.
insertAfter
    jsr allocNewLine
    bcc _allocSuccess
    rts
_allocSuccess
    #move16Bit LIST.current, PTR_CURRENT
    #SET_MMU_ADDR LIST.current
    ; copy flags
    ldy #Line_t.flags
    lda (PTR_CURRENT), y
    sta ORIG_FLAGS

    ; test flags of current element
    and #FLAG_IS_LAST
    beq _normal
_atEnd
    ; we are at the current end of the list
    lda #FLAG_IS_LAST
    eor #$FF
    sta MASK_TEMP
    ; l.Current.Flags = l.Current.Flags & ^FLAG_IS_LAST
    ldy #Line_t.flags
    lda (PTR_CURRENT), y
    and MASK_TEMP
    sta (PTR_CURRENT), y

    #SET_MMU_ADDR NEW
    ; newItem.Flags = newItem.Flags | FLAG_IS_LAST
    ldy #Line_t.flags
    lda #FLAG_IS_LAST
    sta (PTR_NEW), y
    ; newItem.Prev = l.Current
    #copyMem2Ptr LIST.current, PTR_NEW, Line_t.prev

    #SET_MMU_ADDR LIST.current
    ; l.Current.Next = newItem
    #copyMem2Ptr NEW, PTR_CURRENT, Line_t.next
    bra _doneOK 
_normal
    ; MMU still points to #ENTER_ADDR LIST.current
    ; oldNext := l.Current.Next
    #copyPtr2Mem PTR_CURRENT, Line_t.next, OLD_NEXT
    #move16Bit OLD_NEXT, PTR_OLD_NEXT
    ; l.Current.Next = newItem    
    #copyMem2Ptr NEW, PTR_CURRENT, Line_t.next
    ; oldNext.Prev = newItem
    #SET_MMU_ADDR OLD_NEXT
    #copyMem2Ptr NEW, PTR_OLD_NEXT, Line_t.prev
    
    #SET_MMU_ADDR NEW
    ; newItem.Prev = l.Current
    #copyMem2Ptr LIST.current, PTR_NEW, Line_t.prev
    ; newItem.Next = oldNext
    #copyMem2Ptr OLD_NEXT, PTR_NEW, Line_t.next
_doneOK
    #inc16Bit LIST.length
    clc
    rts


SET_PTR  .dstruct FarPtr_t
; PUBLIC: Set LIST.current to value given in SET_PTR
setTo
    #copyMem2Mem SET_PTR, LIST.current
    rts


; PUBLIC: Set head as current element
rewind
    #copyMem2Mem LIST.head, LIST.current
    rts


; func (l *List) Prev() bool {
; 	if (l.Current.Flags & FLAG_IS_FIRST) != 0 {
; 		return true
; 	}
;
; 	l.Current = l.Current.Prev
;
;   return false
; }
;
; PUBLIC: Make previous element of this element the new current element
; Upon return the carry is set if the current element is already the 
; first element.
prev
    #SET_MMU_ADDR LIST.current                                         ; set MMU
    #move16Bit LIST.current, PTR_CURRENT                               ; initialize indirect address
    ; check flags. Are we at the beginning?
    ldy #Line_t.flags
    lda (PTR_CURRENT), y
    and #FLAG_IS_FIRST
    bne _done                                                        ; yes => we can't go left
    ; copy prev pointer to LIST.current
    #copyPtr2Mem PTR_CURRENT, Line_t.prev, LIST.current
    clc
    rts
_done
    sec
    rts

Move_t .struct 
    offsetL  .byte 0
    offsetH  .byte 0
    moveNext .byte BOOL_TRUE
.endstruct

MOVE_HELP .dstruct Move_t


; signed offset to move in a (hi) and x (lo). Negative value => move towards
; beginning, else move towards end. Carry flag is set if either beginning or end of 
; the list was reached and the flag is clear otherwise.
move
    ; set direction to backwards
    stz MOVE_HELP.moveNext
    ; store input data
    stx MOVE_HELP.offsetL
    sta MOVE_HELP.offsetH
    ; test if offset is negative
    lda MOVE_HELP.offsetH
    bpl _positive
    ; Sign is negative => change sign by computing the two's complement
    ; we are moving towards the beginning of the list
    #twosComplement16 MOVE_HELP
    bra _doMove
_positive
    ; set direction to forward, i.e. we move to the end of the list
    lda #BOOL_TRUE
    sta MOVE_HELP.moveNext
_doMove
    #cmp16BitImmediate 0, MOVE_HELP.offsetL
    beq _doneNotEnd
    lda MOVE_HELP.moveNext
    bne _forward
    jsr prev
    bcs _done
    bra _nextLoop
_forward
    jsr next
    bcs _done
_nextLoop
    #dec16Bit MOVE_HELP.offsetL
    bra _doMove
_doneNotEnd
    clc
_done
    rts


; func (l *List) Next() bool {
; 	if (l.Current.Flags & FLAG_IS_LAST) != 0 {
; 		return true
; 	}
;
; 	l.Current = l.Current.Next
;
;   return false
; }
;
; PUBLIC: Make next element of this element the new current element
; Upon return the carry is set if the current element is already the 
; last element.
next
    #SET_MMU_ADDR LIST.current                                         ; set MMU
    #move16Bit LIST.current, PTR_CURRENT                               ; initialize indirect address
    ; check flags. Are we at the end?
    ldy #Line_t.flags
    lda (PTR_CURRENT), y
    and #FLAG_IS_LAST
    bne _done                                                        ; yes => we can't go right
    ; copy next pointer to LIST.current
    #copyPtr2Mem PTR_CURRENT, Line_t.next, LIST.current
    clc
    rts
_done
    sec
    rts


; PUBLIC: This routine returns the length of the line which is represented
; by the current element.
getLineLength
    #SET_MMU_ADDR LIST.current
    #move16Bit LIST.current, PTR_CURRENT
    ldy #Line_t.len
    lda (PTR_CURRENT), y
    rts


; PUBLIC: This routine returns the flags of the line which is represented
; by the current element.
getFlags
    #SET_MMU_ADDR LIST.current
    #move16Bit LIST.current, PTR_CURRENT
    ldy #Line_t.flags
    lda (PTR_CURRENT), y
    rts


; PUBLIC: This routine copies the data of the line to which LIST.current points
; to the line buffer. It changes the MMU config.
readCurrentLine
    #SET_MMU_ADDR LIST.current
    #move16Bit LIST.current, PTR_CURRENT
    #move16Bit LIST.current, MEM_PTR3
    #add16BitImmediate Line_t.block1, MEM_PTR3
    ldy #Line_t.len
    lda (PTR_CURRENT), y
    sta LINE_BUFFER.len
    jsr calcBlkCopyParams
    jsr cpStruct2LineBuffer
    stz LINE_BUFFER.dirty
    rts


NUM_BLOCKS .byte 0
; frees all subblocks of the current line
freeCurrentLine
    #SET_MMU_ADDR LIST.current
    #move16Bit LIST.current, MEM_PTR3
    ldy #Line_t.numBlocks
    lda (MEM_PTR3), y
    sta NUM_BLOCKS
    ; set MEM_PTR3 to address where Line_t.block1 is located
    #add16BitImmediate Line_t.block1, MEM_PTR3
    ldx #0
_loop
    cpx NUM_BLOCKS
    beq _done
    #CALL_X_PROT memory.freePtr
    inx
    #add16BitImmediate size(FarPtr_t), MEM_PTR3
    bra _loop
_done    
    rts


calcPtrSlotAddress
    ; get number of used blocks
    ldy #Line_t.numBlocks
    lda (PTR_CURRENT), y
; expects the number of the FarPtr in the Line_t in the accu and that PTR_CURRENT 
; points to the line item in the correct MMU page. Upon return MEM_PTR3 is set to
; the start address of the corresponding FarPtr.
calcPtrSlotAddressInt
    sta $DE02
    stz $DE03
    #load16BitImmediate size(FarPtr_t), $DE00
    ; $DE10/11 now contains numBlocks * 3 
    #move16Bit $DE10, MEM_PTR3
    ; add  offset for block1
    #add16BitImmediate Line_t.block1, MEM_PTR3
    ; add base address of whole FarPtr
    #add16Bit PTR_CURRENT, MEM_PTR3
    rts    


; length in Accu. Result in FULL_BLOCKS, BYTES_IN_LAST_BLOCK and BLOCKS_NEEDED
calcBlkCopyParams
    ; divide length by BLOCK_SIZE => $DE14 contains number of block in page
    sta $DE06
    stz $DE07
    #load16BitImmediate BLOCK_SIZE, $DE04    
    lda $DE14
    sta FULL_BLOCKS
    sta BLOCKS_NEEDED
    lda $DE16
    sta BYTES_IN_LAST_BLOCK
    ; check if we need an additional block which is not used in full. The sta did not change the zero flag.
    beq _noInc
    inc BLOCKS_NEEDED
_noInc
    rts


DATA_LEN            .byte 0
FULL_BLOCKS         .byte 0
BYTES_IN_LAST_BLOCK .byte 0
BLOCKS_NEEDED       .byte 0
BLOCKS_TO_PROCESS   .byte 0, 0
;
; PUBLIC: Change data of current element to the value given in LINE_BUFFER
; carry is set if this routine fails.
setCurrentLine
    lda LINE_BUFFER.len
    cmp #NUM_SUB_BLOCKS * BLOCK_SIZE
    beq _goOn
    bcc _goOn
    jmp _done
_goOn
    sta DATA_LEN
    jsr calcBlkCopyParams
    #SET_MMU_ADDR LIST.current
    #move16Bit LIST.current, PTR_CURRENT
    ; calculate BLOCKS_NEEDED - l.current.numBlocks
    sec
    lda BLOCKS_NEEDED
    ldy #Line_t.numBlocks
    sbc (PTR_CURRENT), y    
    bne _goOn2
    ; we already have the correct number of blocks
    jmp _doCopy
_goOn2
    ; we have more blocks than we need => Let's free some blocks
    bmi _freeBlocks
_allocBlocks
    ; we have less blocks than we need => Allocate some blocks
    sta BLOCKS_TO_PROCESS
    ; do we still have enough memory?
    #cmp16Bit BLOCKS_TO_PROCESS, memory.MEM_STATE.numFreeBlocks
    ; exactly the number we need is available
    beq _doAlloc
    bcc _doAlloc
    ; Not enough blocks left. Carry is set.
    jmp  _done
_doAlloc
    jsr calcPtrSlotAddress
    ; now MEM_PTR3 points to the first free FarPtr slot.
    ldx #0
_allocLoop
    ; we still have enough blocks for this
    #CALL_X_PROT memory.allocPtr
    #add16BitImmediate size(FarPtr_t), MEM_PTR3
    inx
    cpx BLOCKS_TO_PROCESS
    bne _allocLoop
    bra _doCopy
_freeBlocks
    ; change sign
    clc
    eor #$FF
    adc #1
    sta BLOCKS_TO_PROCESS
    
    ; calculate current.numBlocks - BLOCKS_TO_PROCESS
    ldy #Line_t.numBlocks
    lda (PTR_CURRENT), y
    sec
    sbc BLOCKS_TO_PROCESS
    ; accu now contains the position of the first slot to be freed    
    jsr calcPtrSlotAddressInt
    ; Now MEM_PTR3 points to the first FarPtr that is to be freed
    ldx #0
_freeLoop
    #CALL_X_PROT memory.freePtr
    #add16BitImmediate size(FarPtr_t), MEM_PTR3
    inx
    cpx BLOCKS_TO_PROCESS
    bne _freeLoop    
_doCopy
    lda BLOCKS_NEEDED
    ldy #Line_t.numBlocks
    sta (PTR_CURRENT), y

    ; set MEM_PTR3 to address of first FarPtr in line
    #move16Bit PTR_CURRENT, MEM_PTR3
    #add16BitImmediate Line_t.block1, MEM_PTR3

    jsr cpLineBuffer2Struct
    
    ; switch MMU back to page of list item
    #SET_MMU_ADDR LIST.current
    ; set length
    lda DATA_LEN
    ldy #Line_t.len
    sta (PTR_CURRENT), y

    stz LINE_BUFFER.dirty
    clc
_done
    rts   

DIRECTION .byte 0

; MEM_PTR3 has to point to current list element and the MMU has to be set to the
; page which holds the data of this element. DIRECTION == 0 => Copy struct to line
; buffer. DIRECTION != 0 => Copy from line buffer to struct
cpLineBuffer2Struct
    lda #1
    sta DIRECTION
    bra cpStart 
cpStruct2LineBuffer
    stz DIRECTION
cpStart
    ldx #0
_copy
    lda FULL_BLOCKS
    beq _lastBlockOnly
    ; read pointer of data block
    lda (MEM_PTR3)
    sta PTR_TEMP
    ldy #1
    lda (MEM_PTR3),y
    sta PTR_TEMP+1
    ; set MMU to page of data block
    #SET_MMU_ZP MEM_PTR3    

    ldy #0
_copyBlock
    lda DIRECTION
    bne _reverse1
    lda (PTR_TEMP), y
    sta LINE_BUFFER.buffer, x
    bra _skip1
_reverse1
    lda LINE_BUFFER.buffer, x
    sta (PTR_TEMP), y
_skip1
    iny
    inx
    cpy #BLOCK_SIZE
    bne _copyBlock
    ; set MMU to page of list item
    #SET_MMU_ADDR LIST.current
    ; set MEM_PTR3 to next FarPtr
    #add16BitImmediate size(FarPtr_t), MEM_PTR3
    dec FULL_BLOCKS
    bra _copy

    ; here the MMU is configured to bank in the page which contains LIST.current
_lastBlockOnly
    lda BYTES_IN_LAST_BLOCK
    beq _done

    ; read pointer of data block
    lda (MEM_PTR3)
    sta PTR_TEMP
    ldy #1
    lda (MEM_PTR3),y
    sta PTR_TEMP+1
    ; set MMU to page of data block
    #SET_MMU_ZP MEM_PTR3    

    ldy #0
_loop
    lda DIRECTION
    bne _reverse2
    lda (PTR_TEMP), y
    sta LINE_BUFFER.buffer, x
    bra _skip2
_reverse2
    lda LINE_BUFFER.buffer, x
    sta (PTR_TEMP), y    
_skip2
    iny
    inx
    cpy BYTES_IN_LAST_BLOCK
    bne _loop
_done
    rts


SearchParam_t .struct 
    searchDown .byte BOOL_TRUE
    callback   .word 0
    bkpPtr     .dstruct FarPtr_t
.endstruct

SEARCH_PARAMS .dstruct SearchParam_t

searchCallback
    jmp (SEARCH_PARAMS.callback)


dummyCallback
    rts

; PUBLIC: Searches for a given string in the specified direction. The string to search
; is assumed to be in line.SEARCH_BUFFER.
;
; carry is set if string was found. If nothing was found LIST.current is reset to the
; original value. X register contains the start position that was found.
searchStr
    stx SEARCH_PARAMS.callback
    sta SEARCH_PARAMS.callback + 1
    sty SEARCH_PARAMS.searchDown
    ; save current position in list
    #copyMem2Mem LIST.current, SEARCH_PARAMS.bkpPtr
    ; check whether the callback is valid and if it is not set a dummy callback
    #cmp16BitImmediate 0, SEARCH_PARAMS.callback
    bne _loop
    #load16BitImmediate dummyCallback, SEARCH_PARAMS.callback
_loop
    ; move into desired direction
    lda SEARCH_PARAMS.searchDown
    bne _down
    jsr prev
    bra _skip
_down
    jsr next
_skip
    bcs _notFound
    ; signal that we have moved the current position
    jsr searchCallback
    jsr readCurrentLine
    lda SEARCH_PARAMS.searchDown
    bne _fromStart
    jsr search.TextFromEnd
    bra _checkFound
_fromStart
    jsr search.TextFromStart
_checkFound
    bcc _loop
    rts
_notFound
    ; restore original position if nothing was found
    #copyMem2Mem SEARCH_PARAMS.bkpPtr, LIST.current
    clc
    rts


; PUBLIC: Free all memory used by the list
destroy
    jsr rewind
    ; delete all elements but the last
_loop
    jsr remove
    bcc _loop

    ; free the remaining element
    jsr freeCurrentLine
    #load16BitImmediate LIST.current, MEM_PTR3
    ; free Line
    jsr memory.freePtr

    rts


; PUBLIC: create a new document with one line which is empty. 
; If this routine fails the carry is set upon return.
create
    #load16BitImmediate LIST.current, MEM_PTR3
    jsr memory.allocPtr
    bcs _error
    #copyMem2Mem LIST.current, LIST.head
    #load16BitImmediate 1, LIST.length

    #SET_MMU_ADDR LIST.current                                       ; set MMU
    #move16Bit LIST.current, MEM_PTR3                                ; initialize indirect address

    jsr line.init

    ; initialize LinePtr_t.flags
    lda #FLAG_IS_FIRST | FLAG_IS_LAST
    ; set flags
    ldy #Line_t.flags
    sta (MEM_PTR3), y   

    clc
_error
    rts


.endnamespace