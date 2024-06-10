

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
    #changeLine list.next
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
    lda LINE_BUFFER.len
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
    #changeLine list.next
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
    lda LINE_BUFFER.len
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
    #changeLine list.prev                                 ; carry can not be set
    #dec16Bit editor.STATE.curLine
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
    #changeLine list.next                                 ; carry can not be set
    #inc16Bit editor.STATE.curLine
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
    #changeLine list.move
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
; y contains direction, carry is set if something was found
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
    #changeLine list.searchStr
    bcs _found
    #move16Bit SEARCH_LINE_TEMP, editor.STATE.curLine
    clc
    rts
_found
    stx editor.STATE.navigateCol
    rts


SearchState_t .struct 
    startCol         .byte 0
    searchDirection  .byte 0
.endstruct

SEARCH_STATE .dstruct SearchState_t
; y contains direction, accu contains start pos in current line
; carry is set if something was found
searchFromPos
    ; save parameters
    sta SEARCH_STATE.startCol
    sty SEARCH_STATE.searchDirection
    cpy #0
    bne _forward
    jsr search.TextBackward
    bra _checkFound
_forward
    jsr search.TextForward
_checkFound
    bcs _done
    ldy SEARCH_STATE.searchDirection
    jmp searchOffset
_done
    ; we found the search string in the current line =Y We are done for now
    stx editor.STATE.navigateCol
    rts


LINE_COUNT .byte 0
printScreen
    stz LINE_COUNT
    jsr txtio.clear
    jsr txtio.home
    #copyMem2Mem list.LIST.current, editor.STATE.ptrScratch
    stz CURSOR_STATE.scrollOn
_loopLines
    #printLineBuffer
    jsr txtio.newLine
    #changeLine list.next
    bcs _done
    inc LINE_COUNT
    lda LINE_COUNT
    cmp CURSOR_STATE.yMax
    bne _loopLines
_done
    #copyMem2Mem editor.STATE.ptrScratch, list.LIST.current
    ; restore start state this must not be guarded by the
    ; corresponding macros
    jsr list.readCurrentLine
    inc CURSOR_STATE.scrollOn
    jsr txtio.home
    jsr moveToNavigatePos
    rts


start80x30
    #changeLine list.rewind
    #load16BitImmediate 1, editor.STATE.curLine
    jsr setup80x30
    jsr txtio.setMode80x30
    jsr txtio.cursorOn
    stz editor.STATE.navigateCol
    jsr printScreen
    jsr updateProgData
    rts


start80x60
    #changeLine list.rewind
    #load16BitImmediate 1, editor.STATE.curLine
    jsr setup80x60
    jsr txtio.setMode80x60
    jsr txtio.cursorOn
    stz editor.STATE.navigateCol
    jsr printScreen
    jsr updateProgData
    rts


moveToLineEnd
    lda LINE_BUFFER.len
; accu holds desired column to which to move the cursor
moveToPos
    cmp #0    
    beq _setPos
    cmp #search.MAX_CHARS_TO_CONSIDER
    beq _setPos
    bcc _setPos
    lda #search.MAX_CHARS_TO_CONSIDER - 1
_setPos
    sta CURSOR_STATE.xPos
    sta editor.STATE.navigateCol
    jsr txtio.cursorSet
    rts

; This routine is intended to redraw the screen in its current state.
; This is achieved by assuming that the current element in the linked
; list can be found on the screen in the line specified by the y-position
; of the cursor.
;
; So in order to redraw the screen the list pointer has to be moved
; ypos elements backwards, the screen is redrawn with that line as a start 
; position and finally the current element is moved back to original position,
; i.e. ypos elements forward.
;
; accu contains the current y-position in the view of the line under
; consideration. x has to contain the column to which the cursor
; is to be moved.
REFRESH_TEMP_Y .byte 0
REFRESH_TEMP_X .byte 0
refreshView
    sta REFRESH_TEMP_Y
    stx REFRESH_TEMP_X
    cmp #0
    bne _fullRedraw
    jsr redrawAll
    lda REFRESH_TEMP_X
    jsr moveToPos
    rts
_fullRedraw
    eor #$FF
    sta MOVE_OFFSET
    lda #$FF
    sta MOVE_OFFSET + 1
    #add16BitImmediate 1, MOVE_OFFSET
    jsr moveOffset
    jsr redrawAll
    lda MOVE_OFFSET
    eor #$FF
    sta MOVE_OFFSET
    lda MOVE_OFFSET + 1
    eor #$FF
    sta MOVE_OFFSET + 1
    #add16BitImmediate 1, MOVE_OFFSET
    jsr moveOffset
    lda REFRESH_TEMP_Y
    sta CURSOR_STATE.yPos
    lda REFRESH_TEMP_X
    jsr moveToPos
    rts


redrawAll
    jsr toProg
    jsr printFixedProgData
    jsr toData
    jsr printScreen
    jsr updateProgData
    rts


LEN1_HELP    .word 0
OLD_LEN      .byte 0
VIEW_POS     .byte 0
IS_LAST_LINE .byte 0
; Merge the line where the cursor is with the line above by appending the contents of 
; line x+1 to line x and after that delete line x+1. Line x becomes the new current 
; line.
mergeLines
    lda CURSOR_STATE.yPos
    sta VIEW_POS
    ; line 1 can not merge with the one above it, as there is none above it
    #cmp16BitImmediate 1, editor.STATE.curLine
    bne _goOn
    jmp _done
_goOn
    jsr list.getFlags
    sta IS_LAST_LINE
    ; we are at least in line 2
    ; save length of current line as 16 bit value
    lda LINE_BUFFER.len
    sta LEN1_HELP
    stz LEN1_HELP + 1
    #changeLine list.prev
    ; check if the merged lines are longer than 80 characters. If they are
    ; we do nothing
    clc
    lda LINE_BUFFER.len
    sta OLD_LEN
    adc LEN1_HELP
    sta LEN1_HELP
    lda LEN1_HELP + 1
    adc #0
    sta LEN1_HELP + 1
    #changeLine list.next
    #cmp16BitImmediate search.MAX_CHARS_TO_CONSIDER, LEN1_HELP
    bcs _doMerge
    ; do nothing, change back to current line
    jmp _done
_doMerge
    ; the combined length of the line is <= 80
    ; we will have changed the document
    jsr markDocumentAsDirty

    #memCopy LINE_BUFFER, SCRATCH_BUFFER, size(LineBuffer_t)
    #changeLine list.remove
    lda IS_LAST_LINE
    and #FLAG_IS_LAST
    bne _appendData
    ; we have not removed the last line, so we have to move one element up
    #changeLine list.prev
_appendData
    ; we are now at the correct combined line
    ldx #0
    ldy LINE_BUFFER.len
_appendLoop
    cpx SCRATCH_BUFFER.len
    beq _appendDone
    lda SCRATCH_BUFFER.buffer, x
    sta LINE_BUFFER.buffer, y
    inx
    iny
    bra _appendLoop
_appendDone    
    clc
    lda SCRATCH_BUFFER.len
    adc LINE_BUFFER.len
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    stz LINE_BUFFER.dirty
    #dec16Bit editor.STATE.curLine
    lda VIEW_POS
    beq _noDecrement
    dea
_noDecrement
    ldx OLD_LEN
    jsr refreshView
_done
    rts


; ******************************************************************************************
; ********************** stuff that changes the current list position **********************
; ******************************************************************************************
