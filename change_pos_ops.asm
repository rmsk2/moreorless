; ******************************************************************************************
; ********************** stuff that changes the current list position **********************
; ******************************************************************************************

procCrsrRight
    ; turn scrolling off
    stz CURSOR_STATE.scrollOn
    stz txtio.HAS_LINE_CHANGED
    stz txtio.HAS_SCROLLED
    jsr txtio.right
    ; turn scrolling on
    inc CURSOR_STATE.scrollOn
    lda txtio.HAS_LINE_CHANGED
    ; if 0 line has not changed
    beq _doneRight
    lda txtio.HAS_SCROLLED
    ; if not zero we scroll one line down
    beq _lineDown
    jmp procCrsrDown
_lineDown    
    ; only line change
    jsr list.next
    bcs _endReached
    #inc16Bit editor.STATE.curLine
    jsr updateProgData
    bra _doneRight
_endReached
    ; go one line up again if end of file was reached
    dec CURSOR_STATE.yPos
    jsr txtio.cursorSet
_doneRight
    rts


procCrsrLeft
    stz txtio.HAS_LINE_CHANGED
    jsr txtio.left
    lda txtio.HAS_LINE_CHANGED
    beq _doneLeft
    jsr list.prev
    bcs _doneLeft
    #dec16Bit editor.STATE.curLine
    jsr updateProgData
_doneLeft
    rts


procCrsrUp
    jsr list.prev
    bcs _alreadyTop    
    #dec16Bit editor.STATE.curLine
    jsr updateProgData
    stz txtio.HAS_SCROLLED
    jsr txtio.up
    lda txtio.HAS_SCROLLED
    beq _alreadyTop
    jsr list.readCurrentLine
    jsr txtio.leftMost
    #printLineBuffer
    jsr txtio.leftMost    
_alreadyTop  
    rts


procCrsrDown
    jsr list.next
    bcs _alreadyBottom    
    #inc16Bit editor.STATE.curLine
    jsr updateProgData
    stz txtio.HAS_SCROLLED
    jsr txtio.down    
    lda txtio.HAS_SCROLLED
    beq _alreadyBottom
    jsr list.readCurrentLine
    jsr txtio.leftMost
    #printLineBuffer
    jsr txtio.leftMost    
_alreadyBottom
    rts


MOVE_OFFSET .word 0
moveOffset
    ldx MOVE_OFFSET
    lda MOVE_OFFSET + 1
    jsr list.move
    bcs _atEnd
    #add16Bit MOVE_OFFSET, editor.STATE.curLine
    bra _done
_atEnd
    lda MOVE_OFFSET + 1
    bpl _forward
    #load16BitImmediate 1, editor.STATE.curLine
    bra _done
_forward
    #move16Bit list.LIST.length, editor.STATE.curLine
_done
    rts


callbackUp
    #dec16Bit editor.STATE.curLine
    rts


callbackDown
    #inc16Bit editor.STATE.curLine
    rts


SEARCH_LINE_TEMP .word 0
searchOffset
    #move16Bit editor.STATE.curLine, SEARCH_LINE_TEMP    
    cpy #BOOL_FALSE
    bne _down
    ldx #<callbackUp
    lda #>callbackUp
    bra _search
_down
    ldx #<callbackDown
    lda #>callbackDown
_search
    jsr list.searchStr
    bcs _done
    #move16Bit SEARCH_LINE_TEMP, editor.STATE.curLine
    clc
_done
    rts


printScreen
    stz LINE_COUNT
    jsr txtio.clear
    jsr txtio.home
    #copyMem2Mem list.LIST.current, editor.STATE.ptrScratch
    stz CURSOR_STATE.scrollOn
_loopLines
    jsr list.readCurrentLine    
    #printLineBuffer
    jsr txtio.newLine
    jsr list.next
    bcs _done
    inc LINE_COUNT
    lda LINE_COUNT
    cmp CURSOR_STATE.yMax
    bne _loopLines
    jsr list.prev
_done
    inc CURSOR_STATE.scrollOn
    jsr txtio.home
    #copyMem2Mem editor.STATE.ptrScratch, list.LIST.current
    rts


start80x30
    jsr list.rewind
    #load16BitImmediate 1, editor.STATE.curLine
    jsr setup80x30
    jsr txtio.setMode80x30
    jsr txtio.cursorOn
    jsr printScreen
    jsr updateProgData
    rts


start80x60
    jsr list.rewind
    #load16BitImmediate 1, editor.STATE.curLine
    jsr setup80x60
    jsr txtio.setMode80x60
    jsr txtio.cursorOn
    jsr printScreen
    jsr updateProgData
    rts

; ******************************************************************************************
; ********************** stuff that changes the current list position **********************
; ******************************************************************************************
