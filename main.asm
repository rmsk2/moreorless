* = $0300
.cpu "w65c02"


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
.include "bin_search.asm"
.include "memory.asm"
.include "linked_list.asm"
.include "line.asm"
.include "search.asm"
.include "editor.asm"
.include "diskio.asm"
.include "io_help.asm"
.include "conv.asm"

PROG_NAME .text "MOREORLESS 1.4.9"
SPACER_COL .text ", Col "
SPACER .text " - "
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
LINE_END_CHAR_TEXT .text "Line end character (LF is default, press c for CR): "

FILE_ALLOWED .text "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz 0123456789_-./:#+~()!&@[]"

CRLF = $0D

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

    ; initialize key handling code
    #load16BitImmediate COMMANDS, KEY_SEARCH_PTR
    lda NUM_COMMANDS
    sta BIN_STATE.numEntries

    jsr enterDrive
    jsr enterLineEnding

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

; a key code is a word. The hi byte specifies the state of the meta keys
; and the lo byte the ascii code of the key press

; Fixed commands which are processed seperately
MEM_SET_SEARCH   .dstruct KeyEntry_t, $002F, setSearchString
MEM_SEARCH_DOWN  .dstruct KeyEntry_t, $0073, searchDown
MEM_SEARCH_UP    .dstruct KeyEntry_t, $0853, searchUp
MEM_EXIT         .dstruct KeyEntry_t, $0071, endProg

NUM_COMMANDS .byte 11
COMMANDS
; Non search commands. These have to be sorted by ascending key codes otherwise
; the binary search fails.
CMD_CRSR_LEFT    .dstruct KeyEntry_t, $0002, procCrsrLeft2
CMD_CRSR_RIGHT   .dstruct KeyEntry_t, $0006, procCrsrRight2
CMD_CRSR_DOWN    .dstruct KeyEntry_t, $000E, procCrsrDown2
CMD_CRSR_UP      .dstruct KeyEntry_t, $0010, procCrsrUp2
CMD_PAGE_UP      .dstruct KeyEntry_t, $0020, pageDown
CMD_PAGE_DOWN    .dstruct KeyEntry_t, $0062, pageUp
CMD_GOTO_LINE    .dstruct KeyEntry_t, $0067, gotoLine
CMD_UNSET_SEACRH .dstruct KeyEntry_t, $0075, unsetSearch
CMD_HOME_60_ROW  .dstruct KeyEntry_t, $0081, start80x60
CMD_HOME_30_ROW  .dstruct KeyEntry_t, $0083, start80x30
CMD_TO_EDITOR    .dstruct KeyEntry_t, $02E5, toEditor

CMD_VEC .word 0
jmpToHandler
    jmp (CMD_VEC)

DEFAULT_VEC .word nothing
jmpToDefHandler
    jmp (DEFAULT_VEC)

nothing
    rts

processKeyEvent
    sta ASCII_TEMP
    ldx TRACKING.metaState
    ; the three search operations have to be the first which are checked
    ; this serves the purpose of determining whether a search is in progress.
    cpx MEM_SET_SEARCH.keyComb + 1
    bne _checkSearchDown
    cmp MEM_SET_SEARCH.keyComb
    bne _checkSearchDown
    jsr setSearchString
    sec
    rts
_checkSearchDown
    cpx MEM_SEARCH_DOWN.keyComb + 1
    bne _checkSearchUp
    cmp MEM_SEARCH_DOWN.keyComb
    bne _checkSearchUp
    jsr searchDown
    sec
    rts
_checkSearchUp
    cpx MEM_SEARCH_UP.keyComb + 1
    bne _noSearch
    cmp MEM_SEARCH_UP.keyComb
    bne _noSearch
    jsr searchUp
    sec
    rts  
_noSearch
    ; the user interrupts the search operation. This is recorded
    ; by clearing editor.STATE.searchInProgress.
    stz editor.STATE.searchInProgress
    cpx MEM_EXIT.keyComb + 1
    bne _checkCommands
    cmp MEM_EXIT.keyComb
    bne _checkCommands
    ; handle shutdown properly
    jsr endProg
    clc
    rts
_checkCommands
    jsr binsearch.searchEntry
    bcc _default
    iny
    iny
    lda (KEY_SEARCH_PTR), y
    sta CMD_VEC
    iny
    lda (KEY_SEARCH_PTR), y
    sta CMD_VEC + 1
    jsr jmpToHandler
    sec
    rts
_default
    lda ASCII_TEMP
    jsr jmpToDefHandler
    sec
    rts


.include "change_pos_ops.asm"


endProg
    jsr printScreen
    rts

FOUND_POS .byte 0
; y contains direction
searchBoth
    ; is a search pattern set?
    lda editor.STATE.searchPatternSet
    beq _done
    phy
    jsr signalStartSearch
    ply
    ; is a search in progress, i.e. has the user only executed seach operations
    ; /sS and nothing else? If yes we have to move to the next character before
    ; starting the search.
    lda editor.STATE.searchInProgress
    bne _moveFirst
    ; no search in progress => search from unmodified current cursor position.
    lda CURSOR_STATE.xPos
    jsr searchFromPos
    bcc _done
    bcs _found
_moveFirst
    ; search is in progress, move one char to left or right before starting next search
    cpy #BOOL_FALSE
    bne _forward
    ; we search backward. When doing a backward search we a have an edge case where
    ; the cursor is on position zero in a given line. In this case we can directly 
    ; jump to the previous line.
    lda CURSOR_STATE.xPos
    ; are we a beginning of line? If yes simply goto next line
    beq _nextLine
    ; we are not at position zero => move to previous char and search from there
    dea    
    bra _searchInLineGeneric
_forward
    ; we search forward. Here the edge case occurs when we are at the maximum position,
    ; i.e. at position 79. In this case we can directly move to the next line.
    ; are we at maximum x position?
    lda CURSOR_STATE.xPos
    cmp #search.MAX_CHARS_TO_CONSIDER-1
    bne _searchInLineForward
    ; we are at the end of the line => simply goto next line
_nextLine
    jsr searchOffset
    bcc _done
    bcs _found
_searchInLineForward
    ; We are not at the end of the line => move one char to the right and search in current line
    ina
_searchInLineGeneric
    jsr searchFromPos
    bcc _done
_found
    stx FOUND_POS
    jsr printScreen        
    lda #0
    sta CURSOR_STATE.yPos
    lda FOUND_POS
    sta CURSOR_STATE.xPos
    jsr txtio.cursorSet
    jsr updateProgData
    lda #1
    sta editor.STATE.searchInProgress
_done
    jsr signalEndSearch
    rts


unsetSearch
    lda #BOOL_FALSE
    sta editor.STATE.searchPatternSet
    jsr toProg
    jsr printFixedProgData
    jsr progUpdateInt
    jsr toData
    rts


searchUp
    ldy #BOOL_FALSE
    jmp searchBoth

searchDown
    ldy #BOOL_TRUE
    jmp searchBoth


MINUS_YMAX .word 0
pageUp
    #move16Bit MINUS_YMAX, MOVE_OFFSET
    jsr moveOffset
    jsr updateProgData
    jsr printScreen
    rts


pageDown
    lda CURSOR_STATE.yMax
    sta MOVE_OFFSET
    stz MOVE_OFFSET + 1
    jsr moveOffset
    jsr updateProgData
    jsr printScreen
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
    #move16Bit keyrepeat.FOCUS_VECTOR, editor.STATE.inputVector
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
    #move16Bit editor.STATE.inputVector, keyrepeat.FOCUS_VECTOR
    jsr searchDown
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
    #move16Bit keyrepeat.FOCUS_VECTOR, editor.STATE.inputVector
    #load16BitImmediate processLineNumberEntry, keyrepeat.FOCUS_VECTOR
    rts


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
    #move16Bit conv.ATOW, MOVE_OFFSET
    #sub16Bit editor.STATE.curLine, MOVE_OFFSET
    jsr moveOffset
_done
    jsr updateProgData
    jsr printScreen
    #move16Bit editor.STATE.inputVector, keyrepeat.FOCUS_VECTOR
_notDone
    sec    
    rts 


enterLineEnding
    #printString LINE_END_CHAR_TEXT, len(LINE_END_CHAR_TEXT)
    jsr waitForKey
    cmp #99
    bne _done
    lda #$0D
    sta LINE_END_CHAR
    lda #$0A
    sta ALT_LINE_END_CHAR
    lda #99
    bra _out
_done
    lda #108
_out
    jsr txtio.charOut
    jsr txtio.newLine
    jsr txtio.newLine
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

DATA_CURSOR .byte 0
toProg
    lda CURSOR_STATE.xPos
    sta DATA_CURSOR
    #load16BitImmediate CURSOR_STATE_DATA, TXT_PTR2
    #load16BitImmediate CURSOR_STATE_PROG, TXT_PTR1
    jsr txtio.switch    
    rts


BLANKS_80 .text "                                                                                "
CURRENT_LINE .text "Ln "
INFO_LINE .byte 0
BLOCK_FREE .word 0
FIXED_TEMP .byte 0
printFixedProgData
    jsr txtio.home
    jsr txtio.reverseColor
    #printString BLANKS_80, len(BLANKS_80)
    lda #1
    sta INFO_LINE

    lda #len(PROG_NAME) + len(SPACER)
    clc
    adc TXT_FILE.nameLen
    cmp #79
    bcs _progNameOnly
    sta FIXED_TEMP
    sec
    lda #78
    sbc FIXED_TEMP
    lsr
    clc
    adc #2
    bra _centered
    ; program name and file name together do not fit in a line
_progNameOnly
    lda #33
    stz INFO_LINE
_centered    
    sta CURSOR_STATE.xPos
    stz CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #printString PROG_NAME, len(PROG_NAME)
    lda INFO_LINE
    beq _noFileName
    #printString SPACER, len(SPACER)
    #printStringLenMem FILE_NAME, TXT_FILE.nameLen
_noFileName
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
    #printString BLANKS_80, 15
    lda #len(CURRENT_LINE)
    sta CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    #move16Bit editor.STATE.curLine, txtio.WORD_TEMP
    jsr txtio.printWordDecimal
    #printString SPACER_COL, len(SPACER_COL)
    lda DATA_CURSOR
    ina
    sta txtio.WORD_TEMP
    stz txtio.WORD_TEMP + 1
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

; There can be up to 64 commands at the moment
NUM_EDITOR_COMMANDS = 13
EDITOR_COMMANDS
; Non search commands. These have to be sorted by ascending key codes otherwise
; the binary search fails.
; HOME
EDT_LINE_START   .dstruct KeyEntry_t, $0001, toLineStart
EDT_CRSR_LEFT    .dstruct KeyEntry_t, $0002, procCrsrLeft2
EDT_CRSR_RIGHT   .dstruct KeyEntry_t, $0006, procCrsrRight2
EDT_DELETE       .dstruct KeyEntry_t, $0008, deleteChar
EDT_CRSR_DOWN    .dstruct KeyEntry_t, $000E, procCrsrDown2
EDT_CRSR_UP      .dstruct KeyEntry_t, $0010, procCrsrUp2
; F1
EDT_HOME_60_ROW  .dstruct KeyEntry_t, $0081, start80x60
; F3
EDT_HOME_30_ROW  .dstruct KeyEntry_t, $0083, start80x30
; FNX + down
EDT_PAGE_UP      .dstruct KeyEntry_t, $040E, pageDown
; FNX + up
EDT_PAGE_DOWN    .dstruct KeyEntry_t, $0410, pageUp
; FNX + g
EDT_GOTO_LINE    .dstruct KeyEntry_t, $0467, gotoLine
; FNX + u
EDT_UNSET_SEACRH .dstruct KeyEntry_t, $0475, unsetSearch
; SHift + HOME
EDT_LINE_END     .dstruct KeyEntry_t, $0805, toLineEnd


toEditor
    ; FNX + f
    #load16BitImmediate $0466, MEM_SET_SEARCH.keyComb
    ; F5
    #load16BitImmediate $0085, MEM_SEARCH_DOWN.keyComb
    ; F7
    #load16BitImmediate $0087, MEM_SEARCH_UP.keyComb
    ; ALT + x
    #load16BitImmediate $02F8, MEM_EXIT.keyComb
    #load16BitImmediate EDITOR_COMMANDS, KEY_SEARCH_PTR
    lda #NUM_EDITOR_COMMANDS
    sta BIN_STATE.numEntries
    #load16BitImmediate insertCharacter, DEFAULT_VEC
    rts


toLineEnd
    jsr moveToLineEnd
    rts


toLineStart
    lda #0
    jsr moveToPos
    rts


SCREEN_LEN .byte 0
insertCharacter
    sta ASCII_TEMP
    ; do not allow adding a character if the line length is already at
    ; maximum or bigger
    lda LINE_BUFFER.len
    cmp #search.MAX_CHARS_TO_CONSIDER
    bcs _done
    ; we will have changed the document
    lda #1
    sta editor.STATE.dirty
    ; insert character into LINE_BUFFER
    #load16BitImmediate LINE_BUFFER.buffer, MEM_PTR1
    lda #LINE_BUFFER_LEN
    sta memory.INS_PARAM.maxLength
    ldy LINE_BUFFER.len
    lda CURSOR_STATE.xPos 
    ldx ASCII_TEMP
    jsr memory.insertCharacterGrow
    bcs _done    
    lda memory.INS_PARAM.curLength
    sta LINE_BUFFER.len
    ; mark line as dirty
    lda #1
    sta LINE_BUFFER.dirty

    #saveIoState

    ; update text matrix
    #toTxtMatrix
    #move16Bit CURSOR_STATE.videoRamPtr, MEM_PTR1
    lda #search.MAX_CHARS_TO_CONSIDER
    sec
    sbc CURSOR_STATE.xPos
    tay
    sty SCREEN_LEN
    lda #0
    ldx ASCII_TEMP
    jsr memory.insertCharacterDrop
    
    ; update colour matrix
    #toColorMatrix
    ldy SCREEN_LEN
    ldx editor.STATE.col
    lda #0
    jsr memory.insertCharacterDrop
    
    #restoreIoState
    ; Only move cursor if we are not at the end of a line
    lda CURSOR_STATE.xPos
    cmp #search.MAX_CHARS_TO_CONSIDER-1
    beq _done
    jsr procCrsrRight2
_done
    rts


deleteChar
    lda CURSOR_STATE.xPos
    bne _deleteSingleChar
    jmp mergeLines
_deleteSingleChar
    #saveIoState

    ; do nothing if line length is zero
    lda LINE_BUFFER.len
    beq _done

    ; we will have changed the document
    lda #1
    sta editor.STATE.dirty

    ; delete character in line buffer
    #load16BitImmediate LINE_BUFFER.buffer, MEM_PTR1
    ldy LINE_BUFFER.len
    lda CURSOR_STATE.xPos
    dea
    jsr memory.vecShiftLeft
    ; adapt length and mark as dirty
    dec LINE_BUFFER.len
    lda #1
    sta LINE_BUFFER.dirty

    ; we delete the character left of the cursor => simply decrement current VRAM address
    #move16Bit CURSOR_STATE.videoRamPtr, MEM_PTR1
    #dec16Bit MEM_PTR1

    ; update text matrix
    #toTxtMatrix
    lda #search.MAX_CHARS_TO_CONSIDER
    sec
    sbc CURSOR_STATE.xPos
    tay
    iny
    sty SCREEN_LEN
    lda #0
    jsr memory.vecShiftLeft
    ; check if we have to move in a character which was previously
    ; invisible due to the line length limit.
    lda LINE_BUFFER.len
    cmp #search.MAX_CHARS_TO_CONSIDER
    bcc _updateColour
    ; length is here now at least 80, i.e. it was at least 81 before before the
    ; deletion => move in a new character
    ldx #search.MAX_CHARS_TO_CONSIDER - 1
    lda LINE_BUFFER.buffer, x
    sta (MEM_PTR1), y
_updateColour
    ; update colour matrix
    #toColorMatrix
    ldy SCREEN_LEN
    ldx editor.STATE.col
    lda #0
    jsr memory.vecShiftLeft
    lda editor.STATE.col
    sta (MEM_PTR1), y
    
    #restoreIoState

    ; Only move cursor if we are not at the beginning of a line
    lda CURSOR_STATE.xPos
    beq _done
    jsr procCrsrLeft2
_done
    rts