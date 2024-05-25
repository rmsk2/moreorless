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
.include "editor.asm"
.include "diskio.asm"
.include "io_help.asm"
.include "conv.asm"

PROG_NAME .text "MOREORLESS"
FILE_ERROR .text "File read error. Please try again!", $0d, $0d
DONE_TXT .text $0d, "Done!", $0d
LINES_TXT    .text " Lines | "
OF_TEXT .text " of "
BLOCK_FREE_TXT    .text " KB free |"
TXT_RAM_EXPANSION .text "RAM expansion: "
FOUND_TXT .text "Present | "
NOT_FOUND_TXT .text "NOT Present | "
ENTER_FILE_TXT .text "File (enter to reset): "
LOADING_FILE_TXT .text "Loading file ... "
ENTER_DRIVE .text "Enter drive number (0, 1 or 2): "

FILE_ALLOWED .text "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./:#+~()!&@[]"

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
PAGE_UP = $20

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
    bne _checkF3
    jsr pageUp
    jsr printScreen
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
    lda #35
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

    jsr txtio.reverseColor

    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString CURRENT_LINE, len(CURRENT_LINE)
    rts


updateProgData
    jsr toProg
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
    jsr toData
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