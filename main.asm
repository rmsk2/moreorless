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
.include "basic_support.asm"
.include "copy_cut.asm"

TXT_STARS .text "****************"
PROG_NAME .text "MOREORLESS 2.0.3"
AUTHOR_TEXT .text "Written by Martin Grap (@mgr42) in 2024", $0D
GITHUB_URL .text "See also https://github.com/rmsk2/moreorless", $0D, $0D
SPACER_COL .text ", Col "
SPACER .text " - "
FILE_ERROR .text "File read error. Please try again!", $0d, $0d
DONE_TXT .text $0d, "moreoreless has stopped. Please reset your machine if you see this", $0d
LINES_TXT    .text " Lines | "
OF_TEXT .text " of "
BLOCK_FREE_TXT    .text " KB free | "
TXT_RAM_EXPANSION .text "RAM expansion: "
FOUND_TXT .text "Present | "
NOT_FOUND_TXT .text "NOT Present | "
MSG_FILE_LOAD .text "Enter name of file to load. Press return to start with an empty document", $0D
ENTER_FILE_TXT .text "File: "
LOADING_FILE_TXT .text "Loading file ... "
ENTER_DRIVE .text "Enter drive number (0, 1 or 2): "
ENTER_NEW_LINE .text "Goto Line: "
ENTER_SRCH_STR .text "Search string: "
SRCH_TEXT .text "SRCH"
LINE_END_CHAR_TEXT .text "Select line end character (press c for CR, press any other key for LF): "
ENTER_FILE_NAME .text "File name: "
ENTER_BASIC_NAME .text "BASIC file name: "
SAVING_FILE .text "Saving file ... "
TXT_ERROR .text "error"
TXT_EXIT_WARN .text "There are unsaved changes. Enter a non empty string to exit anyway: "

; these have to remain in this sequence
FILE_ALLOWED .text "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz 0123456789_-./:#+~()!&@[]"
TXT_ALLOWED  .text "=$%^\|*';?,{}<>"""

ENTER_REPLACE_STR .text "Replace string: "

CRLF = $0D

main
    jsr setup.mmu
    jsr clut.init
    jsr initEvents
    jsr txtio.init80x60
    jsr txtio.cursorOn

    jsr memory.init
    jsr clip.init
    jsr line.init_module
    jsr editor.init
    jsr basic.init
    jsr search.init

    lda editor.STATE.col
    sta CURSOR_STATE.col 
    jsr txtio.clear

    ; initialize key handling code
    jsr toEditor

    #printString TXT_STARS, len(TXT_STARS)
    lda #$20
    jsr txtio.charOut
    #printString PROG_NAME, len(PROG_NAME)
    lda #$20
    jsr txtio.charOut
    #printString TXT_STARS, len(TXT_STARS)
    jsr txtio.newLine
    jsr txtio.newLine
    #printString AUTHOR_TEXT, len(AUTHOR_TEXT)
    #printString GITHUB_URL, len(GITHUB_URL)
    jsr txtio.newLine
    jsr txtio.newLine

    jsr enterDrive
    jsr enterLineEnding

_restart
    jsr keyrepeat.init
    jsr enterFileName
    bcc _l2
    bra _newDocument
_l2
    jsr txtio.newLine
    jsr txtio.newLine
    #printString LOADING_FILE_TXT, len(LOADING_FILE_TXT)
    jsr editor.loadFile
    bcc _l1
    #printString FILE_ERROR, len(FILE_ERROR)
    jmp _restart
_l1
    lda #BOOL_TRUE
    sta editor.STATE.fileNameSet
    bra _showMain
_newDocument
    jsr list.create
    bcs _reset
_showMain
    jsr start80x60
    jsr keyrepeat.init
    #load16bitImmediate processKeyEvent, keyrepeat.FOCUS_VECTOR
    jsr keyrepeat.keyEventLoop

    jsr txtio.init80x60
    jsr txtio.clear
    #printString DONE_TXT, len(DONE_TXT)
_reset
    jsr exitToBasic
    ; I guess we never get here ....
    jsr sys64738
    rts


processKeyEvent
    sta ASCII_TEMP
    ldx TRACKING.metaState
    cpx MEM_EXIT.keyComb + 1
    bne _checkCommands
    cmp MEM_EXIT.keyComb
    bne _checkCommands
    ; handle shutdown properly
    jsr endProg
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


CMD_VEC .word 0
jmpToHandler
    jmp (CMD_VEC)

DEFAULT_VEC .word nothing
jmpToDefHandler
    jmp (DEFAULT_VEC)

nothing
    rts


; a key code is a word. The hi byte specifies the state of the meta keys
; and the lo byte the ascii code of the key press
MEM_EXIT         .dstruct KeyEntry_t, $02F8, endProg               ; ALT + x


; There can be up to 64 commands at the moment
NUM_EDITOR_COMMANDS = 37
EDITOR_COMMANDS
; Non search commands. These have to be sorted by ascending key codes otherwise
; the binary search fails.
EDT_LINE_START   .dstruct KeyEntry_t, $0001, toLineStart           ; HOME
EDT_CRSR_LEFT    .dstruct KeyEntry_t, $0002, procCrsrLeft2
EDT_CRSR_RIGHT   .dstruct KeyEntry_t, $0006, procCrsrRight2
EDT_DELETE       .dstruct KeyEntry_t, $0008, deleteChar            ; delete
EDT_TAB          .dstruct KeyEntry_t, $0009, insertTab             ; Tab
EDT_LINE_SPLIT   .dstruct KeyEntry_t, $000D, splitLines            ; Return
EDT_CRSR_DOWN    .dstruct KeyEntry_t, $000E, procCrsrDown2
EDT_CRSR_UP      .dstruct KeyEntry_t, $0010, procCrsrUp2
EDT_HOME_60_ROW  .dstruct KeyEntry_t, $0081, start80x60            ; F1
MEM_SEARCH_DOWN  .dstruct KeyEntry_t, $0083, searchDown            ; F3
EDT_REPLACE      .dstruct KeyEntry_t, $0085, replaceString         ; F5
MEM_SEARCH_UP    .dstruct KeyEntry_t, $0087, searchUp              ; F7
EDT_WORD_LEFT    .dstruct KeyEntry_t, $0102, toPrevWord            ; CTRL + CrsrLeft 
EDT_COPY_TXT     .dstruct KeyEntry_t, $0103, copyInLine            ; CTRL + c
EDT_WORD_RIGHT   .dstruct KeyEntry_t, $0106, toNextWord            ; CTRL + CrsrRight
EDT_LONG_TAB     .dstruct KeyEntry_t, $0109, insertTabTab          ; CTRL + Tab
EDT_MV_SCR_DOWN  .dstruct KeyEntry_t, $010E, moveWindowDown        ; CTRL + CrsrDown
EDT_MV_SCR_UP    .dstruct KeyEntry_t, $0110, moveWindowUp          ; CTRL + CrsrUp
EDT_PASTE_TXT    .dstruct KeyEntry_t, $0116, pasteInLine           ; CTRL + v
EDT_CUT_TXT      .dstruct KeyEntry_t, $0118, cutInLine             ; CTRL + x
EDT_BASIC_RENUM  .dstruct KeyEntry_t, $02E2, basicAutoNum          ; ALT + b
EDT_CLEAR_CLIP   .dstruct KeyEntry_t, $02EB, clearClip             ; ALT + k
EDT_SAVE_DOC_AS  .dstruct KeyEntry_t, $02F3, saveDocumentAs        ; ALT + s
EDT_PAGE_UP      .dstruct KeyEntry_t, $040E, pageDown              ; FNX + down
EDT_PAGE_DOWN    .dstruct KeyEntry_t, $0410, pageUp                ; FNX + up
EDT_COPY_LINE    .dstruct KeyEntry_t, $0463, copyLines             ; FNX + c
MEM_SET_SEARCH   .dstruct KeyEntry_t, $0466, setSearchString       ; FNX + f
EDT_GOTO_LINE    .dstruct KeyEntry_t, $0467, gotoLine              ; FNX + g
EDT_SET_MARK     .dstruct KeyEntry_t, $046D, setMark               ; FNX + m
EDT_SET_REPL     .dstruct KeyEntry_t, $0472, setReplaceString      ; FNX + r
EDT_SAVE_DOC     .dstruct KeyEntry_t, $0473, saveFile              ; FNX + s
EDT_UNSET_SEACRH .dstruct KeyEntry_t, $0475, unsetSearch           ; FNX + u
EDT_PASTE_LINES  .dstruct KeyEntry_t, $0476, pasteIntoDocument     ; FNX + v
EDT_CUT_LINES    .dstruct KeyEntry_t, $0478, cutFromDocument       ; FNX + x
EDT_LINE_END     .dstruct KeyEntry_t, $0805, toLineEnd             ; Shift + HOME
EDT_HOME_30_ROW  .dstruct KeyEntry_t, $0882, start80x30            ; F2
EDT_COLOUR_CYCLE .dstruct KeyEntry_t, $0884, colourCycle           ; F4


toEditor
    #load16BitImmediate EDITOR_COMMANDS, KEY_SEARCH_PTR
    lda #NUM_EDITOR_COMMANDS
    sta BIN_STATE.numEntries
    #load16BitImmediate insertCharacter, DEFAULT_VEC
    rts


.include "change_pos_ops.asm"


REPL_POS .byte 0
replaceString
    lda editor.STATE.searchPatternSet
    beq _done
    lda CURSOR_STATE.xPos
    sta REPL_POS
    jsr search.CheckAtPos
    bcc _done
    lda REPL_POS
    jsr search.Replace
    bcs _done

    jsr markDocumentAsDirty
    lda #BOOL_TRUE
    sta LINE_BUFFER.dirty

    jsr txtio.leftMost
    #ovwrWithLineBuffer

    lda REPL_POS
    cmp LINE_BUFFER.len
    bcc _setPos
    lda LINE_BUFFER.len
    cmp #search.MAX_CHARS_TO_CONSIDER
    bcc _setPos
    lda #search.MAX_CHARS_TO_CONSIDER - 1
_setPos
    jsr moveToPos
_done
    rts


setMark
    #move16Bit editor.STATE.curLine, editor.STATE.mark.line
    lda CURSOR_STATE.xPos
    sta editor.STATE.mark.xPos
    lda CURSOR_STATE.yPos
    sta editor.STATE.mark.yPos
    lda #BOOL_TRUE
    sta editor.STATE.mark.isValid
    #copyMem2Mem list.LIST.current, editor.STATE.mark.element
    jsr showDocumentState
    rts


CUT_START_POS .byte 0
CUT_END_POS   .byte 0
; carry is set if processing should be terminated after the call to this routine
determineLineCopyCutParams
    ; is mark valid?
    lda editor.STATE.mark.isValid
    beq _quit
    ; are we in the same line as the mark?
    lda editor.STATE.mark.yPos
    cmp CURSOR_STATE.yPos
    bne _quit
    ; the mark is valid and we are on the same line as the mark    
    lda editor.STATE.mark.xPos
    cmp CURSOR_STATE.xPos
    bcs _markAfter
    ; mark is left of current pos
    lda editor.STATE.mark.xPos
    sta clip.LINE_CLIP.startPos
    sta CUT_START_POS
    lda CURSOR_STATE.xPos
    sta CUT_END_POS
    sec
    sbc editor.STATE.mark.xPos
    bra _finished
_markAfter
    ; mark is right of current pos
    lda CURSOR_STATE.xPos
    sta clip.LINE_CLIP.startPos
    sta CUT_START_POS
    lda editor.STATE.mark.xPos
    sta CUT_END_POS
    sec
    sbc clip.LINE_CLIP.startPos
_finished
    ina
    sta clip.LINE_CLIP.lenCopy
    ; verify that the determined values are plausible
    ; start position must not be beyond overall length of line
    lda clip.LINE_CLIP.startPos
    cmp LINE_BUFFER.len 
    bcs _quit
    ; end position must not be beyond overall length of line
    lda CUT_END_POS
    cmp LINE_BUFFER.len 
    bcs _quit
    rts
_quit
    sec
    rts


cutInLine
    jsr determineLineCopyCutParams
    bcs _done
    jsr clip.lineClipCut
    jsr markDocumentAsDirty
    stz editor.STATE.mark.isValid
    jsr toProg
    jsr printFixedProgData
    jsr toData
    jsr txtio.leftMost
    #ovwrWithLineBuffer
    lda CUT_START_POS
    sta editor.STATE.navigateCol
    jsr moveToNavigatePos
    jsr updateProgData
_done
    rts


copyInLine
    jsr determineLineCopyCutParams
    bcs _done
    jsr clip.lineClipCopy
    stz editor.STATE.mark.isValid
    jsr toProg
    jsr printFixedProgData
    jsr toData
_done
    rts


ORG_POS .byte 0
pasteInLine
    lda clip.LINE_CLIP.lenBuffer
    beq _done
    lda CURSOR_STATE.xPos
    sta ORG_POS
    jsr clip.lineClipPaste
    bcs _done
    jsr markDocumentAsDirty
    jsr txtio.leftMost
    #ovwrWithLineBuffer
    lda ORG_POS
    clc
    adc clip.LINE_CLIP.lenBuffer
    cmp #search.MAX_CHARS_TO_CONSIDER
    bne _setCursor
    lda #search.MAX_CHARS_TO_CONSIDER - 1
_setCursor    
    sta editor.STATE.navigateCol
    jsr moveToNavigatePos
    jsr updateProgData
_done
    rts


LINE_HELP .word 0
copyLines
    lda editor.STATE.mark.isValid
    bne _isValid
    jmp _done
_isValid
    #cmp16Bit editor.STATE.mark.line, editor.STATE.curLine
    bcc _markBefore
    #move16Bit editor.STATE.mark.line, LINE_HELP
    #sub16Bit editor.STATE.curLine, LINE_HELP
    #copyMem2Mem list.LIST.current, clip.CPCT_PARMS.start
    bra _doCopy
_markBefore
    #move16Bit editor.STATE.curLine, LINE_HELP
    #sub16Bit editor.STATE.mark.line, LINE_HELP
    #copyMem2Mem editor.STATE.mark.element, clip.CPCT_PARMS.start
_doCopy
    #inc16Bit LINE_HELP
    #move16Bit LINE_HELP, clip.CPCT_PARMS.len
    jsr clip.copySegment
    bcs _error
    stz editor.STATE.mark.isValid
    jsr toProg
    jsr printFixedProgData
    jsr toData
_done
    rts
_error
    jmp (OUT_OF_MEMORY)


clearClip
    jsr clip.clear
    jsr toProg
    jsr printFixedProgData
    jsr toData
    rts


FOUND_POS .byte 0
DIR_TEMP .byte 0
; y contains direction
searchBoth
    sty DIR_TEMP
    ; is a search pattern set?
    lda editor.STATE.searchPatternSet
    beq _done
    phy
    jsr signalStartSearch
    ply
    ; Are we at a position where the search string occurs?
    ; If yes we have to move to the next character before starting the search.
    lda CURSOR_STATE.xPos
    jsr search.CheckAtPos
    bcs _moveFirst
    
    lda CURSOR_STATE.xPos
    ldy DIR_TEMP
    jsr searchFromPos
    bcc _done
    bcs _found
_moveFirst
    ldy DIR_TEMP
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

    jsr toLeftLastLine
    #printString BLANKS_80, len(CURRENT_LINE) + 5

    jsr toLeftLastLine
    #printString ENTER_SRCH_STR, len(ENTER_SRCH_STR)

    #inputStringNonBlocking SEARCH_BUFFER.buffer, 64, FILE_ALLOWED + 26, len(FILE_ALLOWED) - 26 + len(TXT_ALLOWED)
    #move16Bit keyrepeat.FOCUS_VECTOR, editor.STATE.inputVector
    #load16BitImmediate processSearchString, keyrepeat.FOCUS_VECTOR
    rts


print80Blanks
    lda CURSOR_STATE.scrollOn
    pha
    stz CURSOR_STATE.scrollOn
    #printString BLANKS_80, len(BLANKS_80)
    pla
    sta CURSOR_STATE.scrollOn
    rts


processSearchString
    jsr txtio.getStringFocusFunc
    bcc _procEnd
    jmp _notDone
_procEnd
    sta SEARCH_BUFFER.len
    jsr txtio.cursorOn

    jsr toLeftLastLine
    jsr print80Blanks

    jsr toLeftLastLine
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


setReplaceString
    jsr toProg

    jsr toLeftLastLine
    #printString BLANKS_80, len(CURRENT_LINE) + 5

    jsr toLeftLastLine
    #printString ENTER_REPLACE_STR, len(ENTER_REPLACE_STR)

    #inputStringNonBlocking search.REPLACE_TXT, 62, FILE_ALLOWED, len(FILE_ALLOWED) + len(TXT_ALLOWED)
    #move16Bit keyrepeat.FOCUS_VECTOR, editor.STATE.inputVector
    #load16BitImmediate processReplaceString, keyrepeat.FOCUS_VECTOR
    rts


processReplaceString
    jsr txtio.getStringFocusFunc
    bcc _procEnd
    jmp _notDone
_procEnd
    sta search.REPLACE_TXT.len
    jsr txtio.cursorOn

    jsr toLeftLastLine
    jsr print80Blanks

    jsr printFixedProgData
    jsr toData
_done
    jsr updateProgData
    #move16Bit editor.STATE.inputVector, keyrepeat.FOCUS_VECTOR
_notDone
    sec    
    rts 


LEN_DUMMY = 9
DUMMY_TEXT .fill LEN_DUMMY
DUMMY_LEN .byte 0 
endProg
    lda editor.STATE.dirty
    beq _doneAndLeave

    jsr toProg

    jsr toLeftLastLine
    #printString BLANKS_80, len(CURRENT_LINE) + 5

    jsr toLeftLastLine
    #printString TXT_EXIT_WARN, len(TXT_EXIT_WARN)

    #inputStringNonBlocking DUMMY_TEXT, LEN_DUMMY, FILE_ALLOWED, len(FILE_ALLOWED)
    #move16Bit keyrepeat.FOCUS_VECTOR, editor.STATE.inputVector
    #load16BitImmediate processExitTest, keyrepeat.FOCUS_VECTOR
    sec
    rts
_doneAndLeave
    clc
    rts


processExitTest
    jsr txtio.getStringFocusFunc
    bcc _procEnd
    jmp _notDone
_procEnd
    sta DUMMY_LEN
    jsr txtio.cursorOn

    jsr toLeftLastLine
    jsr print80Blanks

    lda DUMMY_LEN
    beq _doNothing

    jsr exitToBasic
    ; I guess we never get here ....
    jsr sys64738
    rts

_doNothing
    jsr toData
    jsr updateProgData
    #move16Bit editor.STATE.inputVector, keyrepeat.FOCUS_VECTOR
_notDone
    sec    
    rts


LINE_NUMBER .text "     "
LINE_LEN .byte 0
gotoLine
    jsr toProg

    jsr toLeftLastLine
    #printString BLANKS_80, len(CURRENT_LINE) + 5

    jsr toLeftLastLine
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

    jsr toLeftLastLine
    #printString BLANKS_80, len(CURRENT_LINE) + 7

    jsr toLeftLastLine
    #printString CURRENT_LINE, len(CURRENT_LINE)

    jsr progUpdateInt
    jsr toData
    lda LINE_LEN
    beq _finish

    #load16BitImmediate LINE_NUMBER, CONV_PTR1
    lda LINE_LEN
    jsr conv.checkMaxWord
    bcc _finish
    jsr conv.atouw    
    #cmp16BitImmediate 0, conv.ATOW
    beq _finish

    #cmp16Bit conv.ATOW, list.LIST.length
    beq _isAllowed
    bcs _finish
_isAllowed
    #move16Bit conv.ATOW, MOVE_OFFSET
    #sub16Bit editor.STATE.curLine, MOVE_OFFSET
    jsr moveOffset
_done
    jsr updateProgData
    jsr printScreen
_finish
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
    #printString MSG_FILE_LOAD, len(MSG_FILE_LOAD)
    jsr txtio.newLine
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


toLeftLastLine
    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
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
    cmp #77
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
    jsr showDocumentState

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

    ; stz CURSOR_STATE.xPos
    ; lda CURSOR_STATE.yMaxMinus1
    ; sta CURSOR_STATE.yPos
    ; jsr txtio.cursorSet
    ; #printString CURRENT_LINE, len(CURRENT_LINE)
    rts


updateProgData
    jsr toProg
    jsr progUpdateInt
    jsr toData
    rts


progUpdateInt
    jsr txtio.cursorOff
    stz CURSOR_STATE.xPos
    lda CURSOR_STATE.yMaxMinus1
    sta CURSOR_STATE.yPos
    jsr txtio.cursorSet
    ; #printString BLANKS_80, 78 - 15
    ; stz CURSOR_STATE.xPos
    ; lda CURSOR_STATE.yMaxMinus1
    ; sta CURSOR_STATE.yPos
    ; jsr txtio.cursorSet
    #printString CURRENT_LINE, len(CURRENT_LINE)
    #move16Bit editor.STATE.curLine, txtio.WORD_TEMP
    jsr txtio.printWordDecimal
    #printString SPACER_COL, len(SPACER_COL)
    lda DATA_CURSOR
    ina
    sta txtio.WORD_TEMP
    stz txtio.WORD_TEMP + 1
    jsr txtio.printWordDecimal
    lda LINE_BUFFER.len
    cmp #search.MAX_CHARS_TO_CONSIDER+1
    bcc _done
    lda #$2a
    jsr txtio.charOut
_done
    lda #$20
    ldy #0
_blanks
    jsr txtio.charOut
    iny
    cpy #10
    bne _blanks 
    jsr txtio.cursorOn
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


toLineEnd
    jsr moveToLineEnd
    rts


toLineStart
    lda #0
    jsr moveToPos
    rts


checkCursorEnd
    cpy LINE_BUFFER.len
    ; we are already at the end of the line
    beq _done
    cpy #search.MAX_CHARS_TO_CONSIDER - 1
    ; Zero flag is set if we are at the end of the screen
_done
    rts


searchNextWord
    ldy CURSOR_STATE.xPos
_loop
    jsr checkCursorEnd
    beq _done
    lda LINE_BUFFER.buffer, y
    cmp #$20
    bne _done
    iny
    bra _loop
_done
    rts


searchNextBlank
_loop
    jsr checkCursorEnd
    beq _done
    lda LINE_BUFFER.buffer, y
    cmp #$20
    beq _done
    iny
    bra _loop
_done
    rts


toNextWord
    jsr searchNextWord
    jsr searchNextBlank
    tya
    jsr moveToPos
    rts


searchPrevBlank
_loop
    cpy #0
    beq _done
    lda LINE_BUFFER.buffer, y
    cmp #$20
    beq _done
    dey
    bra _loop
_done
    rts


searchPrevWord
    ldy CURSOR_STATE.xPos
    beq _done
    cpy LINE_BUFFER.len
    bne _loop
    dey
_loop
    cpy #0
    beq _done
    lda LINE_BUFFER.buffer, y
    cmp #$20
    bne _done
    dey
    bra _loop
_done
    rts


toPrevWord
    jsr searchPrevWord
    jsr searchPrevBlank
    tya
    jsr moveToPos    
    rts


showDocumentState
    #saveIoState
    #toTxtMatrix
    lda editor.STATE.mark.isValid
    beq _invalid
    lda #$4D
    sta $C000 + 78
    bra _cont
_invalid
    lda #$20
    sta $C000 + 78
_cont
    lda editor.STATE.dirty
    bne _dirty
    lda #$20
    sta $C000 + 79
    bra _end
_dirty
    lda #$2a
    sta $C000 + 79
_end    
    #restoreIoState
    rts


markDocumentAsClean
    stz editor.STATE.dirty
    jsr showDocumentState
    rts


markDocumentAsDirty
    lda #1
    sta editor.STATE.dirty
    stz editor.STATE.mark.isValid
    jsr showDocumentState
    rts


insertTab
    lda #$20
    jsr insertCharacter
    lda #$20
    jsr insertCharacter
    rts


insertTabTab
    lda #$20
    jsr insertCharacter
    lda #$20
    jsr insertCharacter
    lda #$20
    jsr insertCharacter
    lda #$20
    jsr insertCharacter
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
    jsr markDocumentAsDirty
    ; insert character into LINE_BUFFER
    #load16BitImmediate LINE_BUFFER.buffer, MEM_PTR1
    lda #search.MAX_CHARS_TO_CONSIDER
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
    ldx ASCII_TEMP
    jsr memory.insertCharacterDrop
    
    ; update colour matrix
    #toColorMatrix
    ldy SCREEN_LEN
    ldx editor.STATE.col
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

    jsr markDocumentAsDirty

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


basicAutoNum
    jsr toProg

    ; clear last line
    jsr toLeftLastLine
    #printString BLANKS_80, len(CURRENT_LINE) + 5

    ; reset to position 0 in last line and print message
    jsr toLeftLastLine
    #printString ENTER_BASIC_NAME, len(ENTER_BASIC_NAME)

    ; setup callbacks for key presses
    #inputStringNonBlocking basic.BASIC_NAME, 78 - len(ENTER_BASIC_NAME), FILE_ALLOWED, len(FILE_ALLOWED)
    #move16Bit keyrepeat.FOCUS_VECTOR, editor.STATE.inputVector
    #load16BitImmediate doAutoNum, keyrepeat.FOCUS_VECTOR
    rts


doAutoNum
    jsr txtio.getStringFocusFunc
    bcc _procEnd
    jmp _notDone
_procEnd
    ; save length
    sta basic.BASIC_FILE.nameLen
    jsr txtio.cursorOn

    ; clear last line
    jsr toLeftLastLine
    jsr print80Blanks

    ; check if a file name was entered
    lda basic.BASIC_FILE.nameLen
    beq _doNothing

    ; print saving file message
    jsr toLeftLastLine
    #printString SAVING_FILE, len(SAVING_FILE)

    ; create outout file
    jsr basic.autoRenumber
    bcc _saveOK
    #printString TXT_ERROR, len(TXT_ERROR)
    jsr toData
    bra _finished
_saveOK
    jsr printFixedProgData
    ; jump to here if user entered an emtpy file name
_doNothing
    jsr toData
    jsr updateProgData
_finished
    ; reinitialize keyrepeat module. If we do not do this key repeat
    ; will stop working. I guess the reason is that quite a lot of messages
    ; are missed during file operations
    jsr keyrepeat.init
    ; restore key press callback
    #move16Bit editor.STATE.inputVector, keyrepeat.FOCUS_VECTOR
_notDone
    sec    
    rts    


saveFile
    lda editor.STATE.fileNameSet
    bne _dosave
    jmp saveDocumentAs
_dosave
    jsr toProg
saveFileInt
    jsr toLeftLastLine
    jsr print80Blanks

    lda TXT_FILE.nameLen
    beq _doNothing

    jsr toLeftLastLine
    #printString SAVING_FILE, len(SAVING_FILE)

    jsr editor.saveFile
    bcc _saveOK
    #printString TXT_ERROR, len(TXT_ERROR)
    jsr printFixedProgData
    jsr toData
    bra _done
_saveOK
    jsr printFixedProgData
    jsr keyrepeat.init
_doNothing
    jsr toData
    jsr updateProgData
_done
    rts


FILE_NAME_BUFFER .fill 78 - len(ENTER_FILE_NAME)
NAME_LEN_TEMP    .word 0
saveDocumentAs
    jsr toProg

    jsr toLeftLastLine
    #printString BLANKS_80, len(CURRENT_LINE) + 5

    jsr toLeftLastLine
    #printString ENTER_FILE_NAME, len(ENTER_FILE_NAME)

    #inputStringNonBlocking FILE_NAME_BUFFER, 78 - len(ENTER_FILE_NAME), FILE_ALLOWED, len(FILE_ALLOWED)
    #move16Bit keyrepeat.FOCUS_VECTOR, editor.STATE.inputVector
    #load16BitImmediate processSaveFile, keyrepeat.FOCUS_VECTOR
    rts


processSaveFile
    jsr txtio.getStringFocusFunc
    bcc _procEnd
    jmp _notDone
_procEnd
    sta NAME_LEN_TEMP
    jsr txtio.cursorOn

    lda NAME_LEN_TEMP
    beq _finish
    #memCopyAddr FILE_NAME_BUFFER, FILE_NAME, NAME_LEN_TEMP
    lda NAME_LEN_TEMP
    sta TXT_FILE.nameLen
    lda #BOOL_TRUE
    sta editor.STATE.fileNameSet
    jsr saveFileInt
    bra _end
_finish
    jsr toLeftLastLine
    jsr print80Blanks
    jsr toData
    jsr updateProgData
_end
    #move16Bit editor.STATE.inputVector, keyrepeat.FOCUS_VECTOR
_notDone
    sec    
    rts