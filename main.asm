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
.include "read_line.asm"

START_TXT1 .text "Use cursor keys to control cursor", $0d
START_TXT4 .text "Use backspace to delete character left of cursor", $0d
START_TXT3 .text "Use Ctrl-l to clear screen, Ctrl+c or RUN/STOP to quit", $0d
START_TXT5 .text "Use F1 to test text entry box", $0d
START_TXT2 .text "Other keys are printed raw", $0d
FILE_ERROR .text "File read error. Please reset computer.", $0d
LIST_CREATE_ERROR .text "Unable to create list. Please reset computer.", $0d
DONE_TXT .text $0d, "Done!", $0d

CRLF = $0D
KEY_EXIT = 3
KEY_CLEAR = 12
KEY_ENTRY_TEST = $81
CRSR_UP = $10
CRSR_DOWN = $0E
CRSR_LEFT = $02
CRSR_RIGHT = $06

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

    jsr editor.loadFile
    bcc _l1
    #printString FILE_ERROR, len(FILE_ERROR)
    jmp endlessLoop
_l1       
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
    #printString START_TXT4, len(START_TXT4)
    #printString START_TXT3, len(START_TXT3)
    #printString START_TXT5, len(START_TXT5)    
    #printString START_TXT2, len(START_TXT2)

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

NO_RAM_EXP .text "No RAM expansion found"


processKeyEvent
    cmp #KEY_EXIT
    bne _checkUp
    clc
    rts
_checkUp
    cmp #CRSR_UP
    bne _checkDown
    jsr txtio.up
    sec
    rts
_checkDown
    cmp #CRSR_DOWN
    bne _checkLeft
    jsr txtio.down
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
    bne _checkClear
    jsr txtio.right
    sec
    rts
_checkClear
    cmp #KEY_CLEAR
    bne _checkCR
    jsr txtio.clear
    jsr txtio.home
    sec
    rts
_checkCR
    cmp #CRLF
    bne _checkBackspace
    jsr txtio.newLine
    sec
    rts
_checkBackspace
    cmp #BACK_SPACE
    bne _checkF1
    jsr txtio.backSpace
    sec
    rts
_checkF1
    cmp #KEY_ENTRY_TEST
    bne _print
    ; print "Enter string: "
    #printString ENTER_TXT, len(ENTER_TXT)
    jsr txtio.reverseColor
    #inputStringNonBlocking ENTRY_RESULT, len(ENTRY_RESULT), ALLOWED_CHARS_1, len(ALLOWED_CHARS_1)
    #load16BitImmediate processTextEntry, keyrepeat.FOCUS_VECTOR
    sec
    rts
_print
    jsr txtio.charOut
    sec
    rts


ALLOWED_CHARS_1 .text "abcdefghijklmnopqrstuvwxyz "
ENTRY_RESULT .text "                "
OUT_LEN .byte 0
ENTER_TXT .text "Enter text: "
OUT_LEN_TXT .text "Number of characters: $"

processTextEntry
    jsr txtio.getStringFocusFunc
    bcs _notDone
    sta OUT_LEN
    jsr txtio.reverseColor

    ; print "Number of characters: $"
    jsr txtio.newLine
    #printString OUT_LEN_TXT, len(OUT_LEN_TXT)

    ; print text length in hex
    lda OUT_LEN    
    jsr txtio.printByte
    jsr txtio.newLine    
    
    ; print text the user entered
    #printStringLenMem ENTRY_RESULT, OUT_LEN
    jsr txtio.newLine

    #load16bitImmediate processKeyEvent, keyrepeat.FOCUS_VECTOR
    jsr txtio.cursorOn
_notDone
    sec    
    rts