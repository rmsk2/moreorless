FLAG_IS_FIRST = 1
FLAG_IS_LAST = 2

List_t .struct 
    head    .dstruct FarPtr_t
    current .dstruct FarPtr_t
    length  .word 0
.endstruct


list .namespace

NEW      .dstruct FarPtr_t
OLD_PREV .dstruct FarPtr_t
OLD_NEXT .dstruct FarPtr_t
TEMP     .dstruct FarPtr_t

LIST .dstruct List_t

remove
    rts

insertBefore
    rts

MASK_TEMP  .byte 0
ORIG_FLAGS .byte 0

; func (l *List) InsertAfter() {
; 	newItem := NewLine(0)

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

; 	l.Length++
; }

; Append a new empty line after the current item
; If this routine fails the carry is set upon return.
insertAfter
    #load16BitImmediate NEW, MEM_PTR3
    ; allocate a new Line_t struct
    jsr memory.allocPtr
    bcc _allocOk
    jmp _done
_allocOk
    #ENTER_ADDR NEW    
    jsr line.init

    #move16Bit LIST.current, PTR_CURRENT
    #move16Bit NEW, PTR_NEW

    #ENTER_ADDR LIST.current
    ; copy flags
    ldy #Line_t.flags
    lda (PTR_CURRENT), y
    sta ORIG_FLAGS

    ; test flags of current
    lda ORIG_FLAGS
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

    #ENTER_ADDR NEW
    ; newItem.Flags = newItem.Flags | FLAG_IS_LAST
    ldy #Line_t.flags
    lda #FLAG_IS_LAST
    sta (PTR_NEW), y
    ; newItem.Prev = l.Current
    #copyMem2Ptr LIST.current, PTR_NEW, Line_t.prev

    #ENTER_ADDR LIST.current
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
    #ENTER_ADDR OLD_NEXT
    #copyMem2Ptr NEW, PTR_OLD_NEXT, Line_t.prev
    
    #ENTER_ADDR NEW
    ; newItem.Prev = l.Current
    #copyMem2Ptr LIST.current, PTR_NEW, Line_t.prev
    ; newItem.Next = oldNext
    #copyMem2Ptr OLD_NEXT, PTR_NEW, Line_t.next
_doneOK
    #inc16Bit LIST.length
    clc
_done
    rts


rewind
    #copyMem2Mem LIST.head, LIST.current
    rts


; move one item to the left
prev
    #ENTER_ADDR LIST.current                                         ; set MMU
    #move16Bit LIST.current, PTR_CURRENT                               ; initialize indirect address
    ; check flags. Are we at the beginning?
    ldy #Line_t.flags
    lda (PTR_CURRENT), y
    and #FLAG_IS_FIRST
    bne _done                                                        ; yes => we can't go left
    ; copy prev pointer to LIST.current
    #copyPtr2Mem PTR_CURRENT, Line_t.prev, LIST.current
_done
    #LEAVE_ADDR LIST.current                                         ; set MMU
    rts


; move one item to the right
next
    #ENTER_ADDR LIST.current                                         ; set MMU
    #move16Bit LIST.current, PTR_CURRENT                               ; initialize indirect address
    ; check flags. Are we at the end?
    ldy #Line_t.flags
    lda (PTR_CURRENT), y
    and #FLAG_IS_LAST
    bne _done                                                        ; yes => we can't go right
    ; copy next pointer to LIST.current
    #copyPtr2Mem PTR_CURRENT, Line_t.next, LIST.current
_done
    #LEAVE_ADDR LIST.current
    rts


copyCurrentLine
    rts


setCurrentLine
    rts   


; create a new document with one line which is empty. If this routine fails
; the carry is set upon return.
create
    #load16BitImmediate LIST.current, MEM_PTR3
    jsr memory.allocPtr
    bcs _error
    #copyMem2Mem LIST.current, LIST.head
    #load16BitImmediate 1, LIST.length

    #ENTER_ADDR LIST.current                                         ; set MMU
    #move16Bit LIST.current, MEM_PTR3                                ; initialize indirect address

    jsr line.init

    ; initialize LinePtr_t.flags
    lda #FLAG_IS_FIRST | FLAG_IS_LAST
    ; set flags
    ldy #Line_t.flags
    sta (MEM_PTR3), y   


    #LEAVE_ADDR LIST.current
    clc
_error
    rts


.endnamespace