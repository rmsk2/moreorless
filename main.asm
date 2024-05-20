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

START_TXT1 .text "Use cursor keys, SPACE and b to navigate file. Press q to quit.", $0d
START_TXT5 .text $0d, "***** Use F1 to show file *****", $0d
FILE_ERROR .text "File read error. Please try again!", $0d, $0d
DONE_TXT .text $0d, "Done!", $0d
LINES_READ_TXT    .text "Lines read   : $"
BLOCK_FREE_TXT    .text "Blocks free  : $"
TXT_RAM_EXPANSION .text "RAM expansion: "
FOUND_TXT .text "Present", $0d, $0d
NOT_FOUND_TXT .text "NOT Present", $0d, $0d
ENTER_FILE_TXT .text "Enter filename: "
LOADING_FILE_TXT .text "Loading file ... "

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
    #printString DONE_TXT + 1, len(DONE_TXT) - 1
    jsr txtio.newLine
    #printString LINES_READ_TXT, len(LINES_READ_TXT)
    lda list.LIST.length + 1
    jsr txtio.printByte
    lda list.LIST.length
    jsr txtio.printByte
    jsr txtio.newLine
    #printString BLOCK_FREE_TXT, len(BLOCK_FREE_TXT)
    lda memory.MEM_STATE.numFreeBlocks + 1
    jsr txtio.printByte
    lda memory.MEM_STATE.numFreeBlocks
    jsr txtio.printByte
    jsr txtio.newLine
    
    #printString TXT_RAM_EXPANSION, len(TXT_RAM_EXPANSION)
    lda memory.MEM_STATE.ramExpFound
    bne _withRamExp
    #printString NOT_FOUND_TXT, len(NOT_FOUND_TXT)
    bra _help
_withRamExp    
    #printString FOUND_TXT, len(FOUND_TXT)
_help
    #printString START_TXT1, len(START_TXT1)
    #printString START_TXT5, len(START_TXT5)    
    
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

    
endlessLoop
    nop
    bra endlessLoop

LINE_COUNT .byte 0

processKeyEvent
    cmp #KEY_EXIT
    bne _checkUp
    clc
    rts
_checkUp
    cmp #CRSR_UP
    bne _checkDown
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
    sec
    rts
_checkDown
    cmp #CRSR_DOWN
    bne _checkLeft
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
    sec
    rts
_checkLeft
    cmp #CRSR_LEFT
    bne _checkRight
    jsr txtio.left
    sec
    rts
_checkRight
    cmp #CRSR_RIGHT
    bne _checkPgDown
    jsr txtio.right
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
    jsr list.rewind
    #load16BitImmediate 1, editor.STATE.curLine
    jsr setup80x30
    jsr txtio.setMode80x30
    jsr txtio.cursorOn
    jsr printScreen
    jsr updateProgData
    sec
    rts
_checkF1
    cmp #SHOW_FILE
    beq _show
    jmp _nothing
_show    
    jsr list.rewind
    #load16BitImmediate 1, editor.STATE.curLine
    jsr setup80x60
    jsr txtio.setMode80x60
    jsr txtio.cursorOn
    jsr printScreen
    jsr updateProgData
    sec
    rts
_nothing
    sec
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
    ldy #0
_loop
    #CALL_Y_PROT list.next
    bcs _done
    #inc16Bit editor.STATE.curLine
    iny
    cpy CURSOR_STATE.yMax
    bne _loop
_done
    jsr updateProgData
    rts


pageUp
    ldy #0
_loop    
    #CALL_Y_PROT list.prev
    bcs _done
    #dec16Bit editor.STATE.curLine
    iny
    cpy CURSOR_STATE.yMax
    bne _loop
_done
    jsr updateProgData
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

printFixedProgData
    jsr txtio.home
    jsr txtio.reverseColor
    #printString BLANKS_80, len(BLANKS_80)
    stz CURSOR_STATE.xPos
    sec
    lda CURSOR_STATE.yMax
    sbc #INFO_SIZE    
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString BLANKS_80, len(BLANKS_80)    
    jsr txtio.reverseColor
    #printString CURRENT_LINE, len(CURRENT_LINE)
    rts


updateProgData
    jsr toProg
    lda #len(CURRENT_LINE)
    sta CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #move16Bit editor.STATE.curLine, WORD_DATA
    jsr printWord
    jsr toData
    rts


WORD_DATA .word 0
printWord
    lda WORD_DATA + 1
    jsr txtio.printByte
    lda WORD_DATA
    jsr txtio.printByte
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