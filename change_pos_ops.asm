; ******************************************************************************************
; ********************** stuff that changes the current list position **********************
; ******************************************************************************************

CHECK_LINE_LEN .byte 0
procCrsrRight2
    lda CURSOR_STATE.xPos
    ina
    cmp CURSOR_STATE.xMax
    bcc _notAtRightEnd
    ;we are at the right end, i.e. in column 79
    lda CURSOR_STATE.yPos
    cmp CURSOR_STATE.yMaxMinus1
    beq _bottomRight
    ; Case 1.1: We are in the last column but not in the last row
    jsr list.next
    bcs _endReached
    #inc16Bit editor.STATE.curLine
    jsr txtio.right    
    bra _endReached
_bottomRight
    ; Case 1.2: We are in the last column and in the last row => we are at the bottom right corner
    ; goto beginning of line    
    stz CURSOR_STATE.xPos
    jsr txtio.cursorSet
    ; scroll down
    jmp procCrsrDown2
_notAtRightEnd
    ; we are at a column < 79
    sta CHECK_LINE_LEN
    jsr list.getLineLength
    cmp CHECK_LINE_LEN
    bcc _lineEndReached
    ; Case 2.1 we are not in the last column and we have not reached the right end of the line => we can move to the right
    jsr txtio.right
    bra _endReached
_lineEndReached
    lda CURSOR_STATE.yPos
    cmp CURSOR_STATE.yMaxMinus1
    beq _logicalBottomRight
    ; Case 2.2.1 We are the end of a line which is not the last row
    jsr list.next
    bcs _endReached
    #inc16Bit editor.STATE.curLine    
    jsr txtio.newLine
    bra _endReached
_logicalBottomRight
    ; Case 2.2.2 We are at the end of the last line and are in the last row
    jmp _bottomRight
_endReached
    jsr updateProgData
    lda CURSOR_STATE.xPos
    sta editor.STATE.navigateCol
    rts


procCrsrLeft2
    lda CURSOR_STATE.xPos
    beq _leftEnd
    ; we are somewhere in the line
    jsr txtio.left
    bra _done
_leftEnd
    ; we are at the left end of a line
    ; check whether we are in the first line of the document?
    #cmp16BitImmediate 1, editor.STATE.curLine
    beq _done
    ; we are not at the first line 
    jsr procCrsrUp2
    jsr list.getLineLength
    cmp CURSOR_STATE.xMax
    bcc _lineLenOK
    lda CURSOR_STATE.xMax
    dea
_lineLenOK
    sta CURSOR_STATE.xPos
    jsr txtio.cursorSet
_done
    lda CURSOR_STATE.xPos
    sta editor.STATE.navigateCol
    jsr updateProgData
    rts


moveToNavigatePos
    lda editor.STATE.navigateCol
    cmp LINE_BUFFER.len
    beq _oldPos
    bcc _oldPos
    lda LINE_BUFFER.len
    sta CURSOR_STATE.xPos
    jsr txtio.cursorSet
    bra _done
_oldPos
    sta CURSOR_STATE.xPos
    jsr txtio.cursorSet
_done
    rts


OLD_YPOS .byte 0
procCrsrUp2
    #cmp16BitImmediate 1, editor.STATE.curLine
    beq _done
    ; we can go up
    ; change line
    jsr list.prev                                 ; carry can not be set
    #dec16Bit editor.STATE.curLine
    jsr list.readCurrentLine
    lda CURSOR_STATE.yPos
    sta OLD_YPOS
    jsr txtio.up
    ; check whether we have scrolled up
    lda OLD_YPOS
    bne _notAtTop
    ; we are at the top line, we have scrolled
    jsr txtio.leftMost
    #printLineBuffer
_notAtTop
    jsr moveToNavigatePos
_done
    jsr updateProgData    
    rts


procCrsrDown2
    #cmp16Bit list.LIST.length, editor.STATE.curLine
    beq _done
    ; we can move down
    ; change line
    jsr list.next                                 ; carry can not be set
    #inc16Bit editor.STATE.curLine
    jsr list.readCurrentLine    
    lda CURSOR_STATE.yPos
    sta OLD_YPOS
    jsr txtio.down
    lda OLD_YPOS
    cmp CURSOR_STATE.yMaxMinus1
    bne _notAtBottom
    ; we are at the bottom line, we have scrolled
    jsr txtio.leftMost
    #printLineBuffer
_notAtBottom
    jsr moveToNavigatePos
_done
    jsr updateProgData
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
; y contains direction
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
    bcs _found
    #move16Bit SEARCH_LINE_TEMP, editor.STATE.curLine
    clc
    rts
_found
    stx editor.STATE.navigateCol
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
_done
    #copyMem2Mem editor.STATE.ptrScratch, list.LIST.current
    jsr list.readCurrentLine
    inc CURSOR_STATE.scrollOn
    jsr txtio.home
    jsr moveToNavigatePos
    rts


start80x30
    jsr list.rewind
    #load16BitImmediate 1, editor.STATE.curLine
    jsr setup80x30
    jsr txtio.setMode80x30
    jsr txtio.cursorOn
    stz editor.STATE.navigateCol
    jsr printScreen
    jsr updateProgData
    rts


start80x60
    jsr list.rewind
    #load16BitImmediate 1, editor.STATE.curLine
    jsr setup80x60
    jsr txtio.setMode80x60
    jsr txtio.cursorOn
    stz editor.STATE.navigateCol
    jsr printScreen
    jsr updateProgData
    rts

; ******************************************************************************************
; ********************** stuff that changes the current list position **********************
; ******************************************************************************************
