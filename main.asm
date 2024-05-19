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

START_TXT1 .text "Use cursor keys to control cursor", $0d
START_TXT5 .text "Use F1 to show file", $0d
FILE_ERROR .text "File read error. Please reset computer.", $0d
LIST_CREATE_ERROR .text "Unable to create list. Please reset computer.", $0d
DONE_TXT .text $0d, "Done!", $0d
LINES_READ_TXT .text "Lines read: $"
BLOCK_FREE_TXT .text "Blocks free: $"
NO_RAM_EXP .text "No RAM expansion found"
LOADING_FILE_TXT .text "Loading file ... "

CRLF = $0D
KEY_EXIT = $71
KEY_CLEAR = 12
SHOW_FILE = $81
CRSR_UP = $10
CRSR_DOWN = $0E
CRSR_LEFT = $02
CRSR_RIGHT = $06
PAGE_DOWN = $62
PAGE_UP = $20

Y_OFFSET = 10

main
    jsr setup.mmu
    jsr clut.init
    ; #load16BitImmediate $c000 + Y_OFFSET*80, CURSOR_STATE.vramOffset
    ; lda #80
    ; sta CURSOR_STATE.xMax
    ; lda #40
    ; sta CURSOR_STATE.yMax
    ; lda #Y_OFFSET
    ; sta CURSOR_STATE.yOffset
    ; jsr txtio.setMode80x60

    jsr txtio.init80x60
    jsr txtio.cursorOn
    jsr keyrepeat.init
    jsr initEvents

    jsr memory.init
    jsr line.init_module
    jsr editor.init

    lda editor.STATE.col
    sta CURSOR_STATE.col 
    jsr txtio.clear

    #printString LOADING_FILE_TXT, len(LOADING_FILE_TXT)
    jsr editor.loadFile
    bcc _l1
    #printString FILE_ERROR, len(FILE_ERROR)
    jmp endlessLoop
_l1
    #printString DONE_TXT + 1, len(DONE_TXT) - 1
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
    
    lda memory.MEM_STATE.ramExpFound
    bne _withRamExp
    #printString NO_RAM_EXP, len(NO_RAM_EXP)

_withRamExp
    ldx #24
_loopNewLine
    jsr txtio.newLine
    dex
    bpl _loopNewLine

    #printString START_TXT1, len(START_TXT1)
    #printString START_TXT5, len(START_TXT5)    

    #load16bitImmediate processKeyEvent, keyrepeat.FOCUS_VECTOR
    jsr keyrepeat.keyEventLoop
    
    jsr restoreEvents
    jsr txtio.clear
    jsr txtio.init80x60
    #printString DONE_TXT, len(DONE_TXT)
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
    bne _checkF1
    jsr pageUp
    jsr printScreen
    sec
    rts
_checkF1
    cmp #SHOW_FILE
    beq _show
    jmp _nothing
_show
    jsr list.rewind
    #load16BitImmediate 1, editor.STATE.curLine
    jsr printScreen
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
    rts
