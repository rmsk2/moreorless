* = $0300
.cpu "w65c02"

jmp main

.include "api.asm"
.include "zeropage.asm"
.include "setup.asm"
.include "clut.asm"
.include "arith16.asm"
.include "txtio.asm"
.include "khelp.asm"
.include "key_repeat.asm"
.include "memory.asm"
.include "linked_list.asm"
.include "line.asm"
.include "search.asm"
.include "editor.asm"
.include "diskio.asm"
.include "io_help.asm"
.include "conv.asm"

PROG_NAME .text "MOREORLESS v1.1"
FILE_ERROR .text "File read error. Please try again!", $0d, $0d
DONE_TXT .text $0d, "Done!", $0d
LINES_TXT    .text " Lines | "
OF_TEXT .text " of "
BLOCK_FREE_TXT    .text " KB free | "
TXT_RAM_EXPANSION .text "RAM expansion: "
FOUND_TXT .text "Present | "
NOT_FOUND_TXT .text "NOT Present | "
ENTER_FILE_TXT .text "File (enter to reset): "
LOADING_FILE_TXT .text "Loading file ... "
ENTER_DRIVE .text "Enter drive number (0, 1 or 2): "
ENTER_NEW_LINE .text "Goto Line: "
ENTER_SRCH_STR .text "Search string: "
SRCH_TEXT .text "SRCH"

FILE_ALLOWED .text "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz 0123456789_-./:#+~()!&@[]"

CRLF = $0D
KEY_EXIT = $71
KEY_CLEAR = 12
SHOW_FILE = $81
SHOW_FILE_80x30 = $83
CRSR_UP = $10
CRSR_DOWN = $0E
CRSR_LEFT = $02
CRSR_RIGHT = $06
PAGE_DOWN = $62
GOTO_LINE = $67
PAGE_UP = $20
SET_SEARCH = 47
UNSET_SEARCH = 117
SEARCH_DOWN = 115
SEARCH_UP = 83

main
    jsr setup.mmu
    jsr clut.init
    jsr initEvents
    jsr txtio.init80x60
    jsr txtio.cursorOn

    jsr memory.init
    jsr line.init_module
    jsr editor.init

    lda editor.STATE.col
    sta CURSOR_STATE.col 
    jsr txtio.clear

    jsr enterDrive

_restart
    jsr keyrepeat.init
    jsr enterFileName
    bcc _l2
    jmp _reset
_l2
    jsr txtio.newLine
    jsr txtio.newLine
    #printString LOADING_FILE_TXT, len(LOADING_FILE_TXT)
    jsr editor.loadFile
    bcc _l1
    #printString FILE_ERROR, len(FILE_ERROR)
    jmp _restart
_l1
    jsr start80x60
    jsr keyrepeat.init
    #load16bitImmediate processKeyEvent, keyrepeat.FOCUS_VECTOR
    jsr keyrepeat.keyEventLoop

    jsr restoreEvents
    jsr txtio.clear
    jsr txtio.init80x60
    #printString DONE_TXT, len(DONE_TXT)
_reset    
    jsr sys64738
    ; I guess we never get here ....
    rts


LINE_COUNT .byte 0

processKeyEvent
    cmp #KEY_EXIT
    bne _checkUp
    clc
    rts
_checkUp
    cmp #CRSR_UP
    bne _checkDown
    jsr procCrsrUp
    sec
    rts
_checkDown
    cmp #CRSR_DOWN
    bne _checkLeft
    jsr procCrsrDown
    sec
    rts
_checkLeft
    cmp #CRSR_LEFT
    bne _checkRight
    jsr procCrsrLeft
    sec
    rts
_checkRight
    cmp #CRSR_RIGHT
    bne _checkPgDown
    jsr procCrsrRight
    sec
    rts
_checkPgDown
    cmp #PAGE_UP
    bne _checkPgUp
    jsr pageDown
    jsr printScreen
    sec
    rts
_checkPgUp
    cmp #PAGE_DOWN
    bne _checkSetSearch
    jsr pageUp
    jsr printScreen
    sec
    rts
_checkSetSearch
    cmp #SET_SEARCH
    bne _checkSearchDown
    jsr setSearchString
    sec
    rts
_checkSearchDown
    cmp #SEARCH_DOWN
    bne _checkSearchUp
    jsr searchDown
    sec
    rts
_checkSearchUp
    cmp #SEARCH_UP
    bne _checkUnsetSearch
    jsr searchUp
    sec
    rts    
_checkUnsetSearch
    cmp #UNSET_SEARCH
    bne _checkGotoLine
    lda #BOOL_FALSE
    sta editor.STATE.searchPatternSet
    jsr toProg
    jsr printFixedProgData
    jsr progUpdateInt
    jsr toData
    sec
    rts    
_checkGotoLine
    cmp #GOTO_LINE
    bne _checkF3
    jsr gotoLine
    sec
    rts
_checkF3
    cmp #SHOW_FILE_80x30
    bne _checkF1
    jsr start80x30
    sec
    rts
_checkF1
    cmp #SHOW_FILE
    beq _show
    jmp _nothing
_show    
    jsr start80x60
    sec
    rts
_nothing
    sec
    rts


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


callbackUp
    #dec16Bit editor.STATE.curLine
    rts


callbackDown
    #inc16Bit editor.STATE.curLine
    rts


signalStartSearch
    #saveIoState
    #toTxtMatrix
    lda #$2a
    sta $C000
    #restoreIoState
    rts


signalEndSearch
    #saveIoState
    #toTxtMatrix
    lda #$20
    sta $C000
    #restoreIoState
    rts


SEARCH_LINE_TEMP .word 0
searchUp
    lda editor.STATE.searchPatternSet
    beq _done
    #move16Bit editor.STATE.curLine, SEARCH_LINE_TEMP
    jsr signalStartSearch
    ldx #<callbackUp
    lda #>callbackUp
    ldy #BOOL_FALSE
    jsr list.searchStr
    bcs _updateView
    #move16Bit SEARCH_LINE_TEMP, editor.STATE.curLine
    bra _done
_updateView
    jsr printScreen
    jsr updateProgData    
_done
    jsr signalEndSearch
    rts


searchDown
    lda editor.STATE.searchPatternSet
    beq _done
    #move16Bit editor.STATE.curLine, SEARCH_LINE_TEMP
    jsr signalStartSearch
    ldx #<callbackDown
    lda #>callbackDown
    ldy #BOOL_TRUE
    jsr list.searchStr
    bcs _updateView
    #move16Bit SEARCH_LINE_TEMP, editor.STATE.curLine
    bra _done
_updateView
    jsr printScreen
    jsr updateProgData    
_done
    jsr signalEndSearch
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


pageDown
    ldx CURSOR_STATE.yMax
    lda #0
    jsr list.move
    bcs _endReached
    #add16BitByte CURSOR_STATE.yMax, editor.STATE.curLine
    bra _end
_endReached
    #move16Bit list.LIST.length, editor.STATE.curLine
_end
    jsr updateProgData
    rts


setSearchString
    jsr toProg

    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString BLANKS_80, len(CURRENT_LINE) + 5

    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString ENTER_SRCH_STR, len(ENTER_SRCH_STR)

    #inputStringNonBlocking SEARCH_BUFFER, 64, FILE_ALLOWED + 26, len(FILE_ALLOWED) - 26
    #load16BitImmediate processSearchString, keyrepeat.FOCUS_VECTOR
    rts


processSearchString
    jsr txtio.getStringFocusFunc
    bcc _procEnd
    jmp _notDone
_procEnd
    sta SEARCH_BUFFER.len
    jsr txtio.cursorOn

    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    lda CURSOR_STATE.scrollOn
    pha
    stz CURSOR_STATE.scrollOn
    #printString BLANKS_80, len(BLANKS_80)
    pla
    sta CURSOR_STATE.scrollOn

    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString CURRENT_LINE, len(CURRENT_LINE)

    lda #BOOL_TRUE
    sta editor.STATE.searchPatternSet

    lda SEARCH_BUFFER.len
    bne _patternSet
    lda #BOOL_FALSE
    sta editor.STATE.searchPatternSet
_patternSet
    jsr printFixedProgData
    jsr toData
_done
    jsr updateProgData
    #load16bitImmediate processKeyEvent, keyrepeat.FOCUS_VECTOR
_notDone
    sec    
    rts 



LINE_NUMBER .text "     "
LINE_LEN .byte 0
gotoLine
    jsr toProg

    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString BLANKS_80, len(CURRENT_LINE) + 5

    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString ENTER_NEW_LINE, len(ENTER_NEW_LINE)

    #inputStringNonBlocking LINE_NUMBER, 5, txtio.PRBYTE.hex_chars, 10
    #load16BitImmediate processLineNumberEntry, keyrepeat.FOCUS_VECTOR
    rts


TEMP2 .word 0
processLineNumberEntry
    jsr txtio.getStringFocusFunc
    bcc _procEnd
    jmp _notDone
_procEnd
    sta LINE_LEN
    jsr txtio.cursorOn

    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString BLANKS_80, len(CURRENT_LINE) + 7

    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString CURRENT_LINE, len(CURRENT_LINE)

    jsr progUpdateInt
    jsr toData

    #load16BitImmediate LINE_NUMBER, CONV_PTR1
    lda LINE_LEN
    jsr conv.checkMaxWord
    bcc _done
    jsr conv.atouw    
    #cmp16BitImmediate 0, conv.ATOW
    beq _done

    #cmp16Bit conv.ATOW, list.LIST.length
    beq _isAllowed
    bcs _done
_isAllowed
    #move16Bit conv.ATOW, TEMP2
    #sub16Bit editor.STATE.curLine, TEMP2
    ldx TEMP2
    lda TEMP2 + 1
    jsr list.move
    bcs _atEnd
    #add16Bit TEMP2, editor.STATE.curLine
    bra _done
_atEnd
    lda TEMP2 + 1
    bpl _forward
    #load16BitImmediate 1, editor.STATE.curLine
    bra _done
_forward
    #move16Bit list.LIST.length, editor.STATE.curLine
_done
    jsr updateProgData
    jsr printScreen
    #load16bitImmediate processKeyEvent, keyrepeat.FOCUS_VECTOR
_notDone
    sec    
    rts 


MINUS_YMAX .word 0
pageUp
    ldx MINUS_YMAX
    lda MINUS_YMAX + 1
    jsr list.move
    bcs _endReached
    #add16Bit MINUS_YMAX, editor.STATE.curLine
    bra _end
_endReached
    #load16BitImmediate 1, editor.STATE.curLine
_end
    jsr updateProgData
    rts


enterDrive
    #printString ENTER_DRIVE, len(ENTER_DRIVE)
    jsr waitForKey
    cmp #$30
    bne _c31
    beq _selected
_c31
    cmp #$31
    bne _c32
    beq _selected
_c32
    cmp #$32
    beq _selected
    jsr txtio.newLine
    jsr txtio.newLine
    jmp enterDrive

_selected
    jsr txtio.charOut
    sec 
    sbc #$30
    sta TXT_FILE.drive
    jsr txtio.newLine
    jsr txtio.newLine
    rts


enterFileName
    #printString ENTER_FILE_TXT, len(ENTER_FILE_TXT)
    jsr txtio.reverseColor
    #inputStringNonBlocking FILE_NAME, 79 - len(ENTER_FILE_TXT), FILE_ALLOWED, len(FILE_ALLOWED)
    #load16BitImmediate processFileNameEntry, keyrepeat.FOCUS_VECTOR
    jsr keyrepeat.keyEventLoop
    lda TXT_FILE.nameLen
    beq _reset 
    clc
    rts
_reset
    sec
    rts


processFileNameEntry
    jsr txtio.getStringFocusFunc
    bcs _notDone
    sta TXT_FILE.nameLen
    jsr txtio.reverseColor
    jsr txtio.cursorOn
    clc
    rts
_notDone
    sec    
    rts    


CURSOR_STATE_DATA .dstruct CursorState_t
CURSOR_STATE_PROG .dstruct CursorState_t

toData
    #load16BitImmediate CURSOR_STATE_PROG, TXT_PTR2
    #load16BitImmediate CURSOR_STATE_DATA, TXT_PTR1
    jsr txtio.switch
    rts


toProg
    #load16BitImmediate CURSOR_STATE_DATA, TXT_PTR2
    #load16BitImmediate CURSOR_STATE_PROG, TXT_PTR1
    jsr txtio.switch    
    rts


BLANKS_80 .text "                                                                                "
CURRENT_LINE .text "Current line: "
INFO_LINE .byte 0
BLOCK_FREE .word 0
printFixedProgData
    jsr txtio.home
    jsr txtio.reverseColor
    #printString BLANKS_80, len(BLANKS_80)

    stz CURSOR_STATE.yPos
    lda #33
    sta CURSOR_STATE.xPos
    jsr txtio.cursorSet
    #printString PROG_NAME, len(PROG_NAME)

    stz CURSOR_STATE.xPos
    sec
    lda CURSOR_STATE.yMax
    sbc #INFO_SIZE    
    sta CURSOR_STATE.yPos
    sta INFO_LINE
    jsr txtio.cursorSet
    #printString BLANKS_80, len(BLANKS_80)    

    stz CURSOR_STATE.xPos
    lda INFO_LINE
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet

    #printString TXT_RAM_EXPANSION, len(TXT_RAM_EXPANSION)
    lda memory.MEM_STATE.ramExpFound
    bne _withRamExp
    #printString NOT_FOUND_TXT, len(NOT_FOUND_TXT)
    bra _goOn
_withRamExp    
    #printString FOUND_TXT, len(FOUND_TXT)
_goOn    
    #move16Bit list.LIST.length, txtio.WORD_TEMP
    jsr txtio.printWordDecimal
    #printString LINES_TXT, len(LINES_TXT)

    #move16Bit memory.MEM_STATE.numFreeBlocks, txtio.WORD_TEMP
    #halve16Bit txtio.WORD_TEMP
    #halve16Bit txtio.WORD_TEMP
    #halve16Bit txtio.WORD_TEMP
    #halve16Bit txtio.WORD_TEMP
    #halve16Bit txtio.WORD_TEMP
    jsr txtio.printWordDecimal

    #printString OF_TEXT, len(OF_TEXT)

    #move16Bit memory.MEM_STATE.numBlocks, txtio.WORD_TEMP
    #halve16Bit txtio.WORD_TEMP
    #halve16Bit txtio.WORD_TEMP
    #halve16Bit txtio.WORD_TEMP
    #halve16Bit txtio.WORD_TEMP
    #halve16Bit txtio.WORD_TEMP
    jsr txtio.printWordDecimal

    #printString BLOCK_FREE_TXT, len(BLOCK_FREE_TXT)

    lda editor.STATE.searchPatternSet
    beq _noPattern
    #printString SRCH_TEXT, len(SRCH_TEXT)
_noPattern
    jsr txtio.reverseColor

    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString CURRENT_LINE, len(CURRENT_LINE)
    rts


updateProgData
    jsr toProg
    jsr progUpdateInt
    jsr toData
    rts


progUpdateInt
    lda #len(CURRENT_LINE)
    sta CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString BLANKS_80, 5
    lda #len(CURRENT_LINE)
    sta CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #move16Bit editor.STATE.curLine, txtio.WORD_TEMP
    jsr txtio.printWordDecimal
    rts

Y_OFFSET = 1
INFO_SIZE = 2

setup80x60
    #load16BitImmediate $c000 + Y_OFFSET*80, CURSOR_STATE.vramOffset
    lda #80
    sta CURSOR_STATE.xMax
    lda #60 - INFO_SIZE - 1
    sta CURSOR_STATE.yMax
    lda #Y_OFFSET
    sta CURSOR_STATE.yOffset
    jsr txtio.init
    jsr txtio.cursorOn

    lda CURSOR_STATE.yMax
    eor #$FF
    sta MINUS_YMAX
    lda #$FF
    sta MINUS_YMAX + 1
    #add16BitImmediate 1, MINUS_YMAX
    
    #load16BitImmediate CURSOR_STATE_DATA, TXT_PTR2
    jsr txtio.saveCursorState

    lda #80
    sta CURSOR_STATE.xMax
    lda #60
    sta CURSOR_STATE.yMax
    jsr txtio.initSegmentDefaults
    jsr txtio.init
    jsr txtio.cursorOff

    #load16BitImmediate CURSOR_STATE_PROG, TXT_PTR2
    jsr txtio.saveCursorState
    jsr txtio.clear
    jsr printFixedProgData

    jsr toData

    rts


setup80x30
    #load16BitImmediate $c000 + Y_OFFSET*80, CURSOR_STATE.vramOffset
    lda #80
    sta CURSOR_STATE.xMax
    lda #30 - INFO_SIZE - 1
    sta CURSOR_STATE.yMax
    lda #Y_OFFSET
    sta CURSOR_STATE.yOffset
    jsr txtio.init
    jsr txtio.cursorOn

    lda CURSOR_STATE.yMax
    eor #$FF
    sta MINUS_YMAX
    lda #$FF
    sta MINUS_YMAX + 1
    #add16BitImmediate 1, MINUS_YMAX

    #load16BitImmediate CURSOR_STATE_DATA, TXT_PTR2
    jsr txtio.saveCursorState
    
    lda #80
    sta CURSOR_STATE.xMax
    lda #30
    sta CURSOR_STATE.yMax
    jsr txtio.initSegmentDefaults
    jsr txtio.init
    jsr txtio.cursorOff

    #load16BitImmediate CURSOR_STATE_PROG, TXT_PTR2
    jsr txtio.saveCursorState
    jsr txtio.clear
    jsr printFixedProgData

    jsr toData

    rts