* = $0300
.cpu "w65c02"

USE_C64_KEYBOARD = 0
KEY_VAL = 1

jmp main
; put some data structures in zero page
.include "zp_data.asm"

.include "api.asm"
.include "zeropage.asm"
.include "setup.asm"
.include "clut.asm"
.include "arith16.asm"
.include "txtio.asm"
.include "khelp.asm"
.include "key_repeat.asm"


TXT_MSG .text "Press keys to see key code. Press Shift + Run/Stop to end.", $0d, $0d

main
    jsr setup.mmu
    jsr clut.init
    jsr initEvents
    jsr txtio.init80x60
    jsr txtio.cursorOn

    lda #$12
    sta CURSOR_STATE.col 
    jsr txtio.clear

    #printString TXT_MSG, len(TXT_MSG)

_restart
    jsr keyrepeat.init
    #load16BitImmediate processKeyEvent, keyrepeat.FOCUS_VECTOR
    jsr keyrepeat.keyEventLoop

    jsr exitToBasic
    ; I guess we never get here ....
    jsr sys64738
    rts


processKeyEvent
    sta ASCII_TEMP

    jsr txtio.home
    #printString TXT_MSG, len(TXT_MSG)

    lda TRACKING.metaState
    jsr txtio.printByte
    lda ASCII_TEMP
    jsr txtio.printByte
    jsr txtio.newLine    
    ldx TRACKING.metaState
    lda ASCII_TEMP
    cpx #$08
    bne _goOn
    cmp #$1b
    bne _goOn
    ; leave program
    clc
    rts
_goOn
    sec
    rts

