FLAG_IS_FIRST = 1
FLAG_IS_LAST = 2

List_t .struct 
    head    .dstruct FarPtr_t
    current .dstruct FarPtr_t
    length  .word 0
.endstruct


list .namespace

NEW      .dstruct FarPtr_t
OLD_SUCC .dstruct FarPtr_t
TEMP3 .dstruct FarPtr_t

LIST .dstruct List_t

remove
    rts

insertBefore
    rts

MASK_TEMP  .byte 0
ORIG_FLAGS .byte 0
; Append a new empty line after the current item
; If this routine fails the carry is set upon return.
insertAfter
    #load16BitImmediate NEW, MEM_PTR3
    ; allocate a new Line_t struct
    jsr memory.allocPtr
    bcc _allocOk
    jmp _done
_allocOk
    ; set MMU
    #ENTER_ADDR NEW    
    jsr line.init
    #LEAVE_ADDR NEW    

    #move16Bit LIST.current, PTR_CURRENT
    #move16Bit NEW, PTR_NEW

    ; ToDo: A lot!!

    ; increment length
    clc
_done
    rts


; move one item to the left
moveLeft    
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
moveRight
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