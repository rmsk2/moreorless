* = $0800
.cpu "w65c02"

jmp main

OFFSET_START  .word 0                   ; 3 
OFFSET_MOVE   .word 0                   ; 5
END_POS       .dstruct FarPtr_t         ; 7
END_REACHED   .byte 0                   ; 10
LST_LEN       .word list.LIST.length    ; 11
HEAD          .dstruct FarPtr_t         ; 13


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"
.include "line.asm"
.include "linked_list.asm"


line_1 .text "1 this is the first line"
line_2 .text "2 this is the middle line and it is longer than the others by quite a bit. it still does not stop. it goes on and on and on ..."
line_3 .text "3 this is the third line and it should be bigger than 32 bytes"
line_4 .text "4 this is the fourth line and it should be bigger than 32 bytes"
line_5 .text "5 this is not the last line"
line_6 .text "6 this is also not the last line"
line_7 .text "7 this is the last line"

LINE_ARRAY .word line_2, line_3, line_4, line_5, line_6, line_7, 0
LEN_ARRAY .byte len(line_2), len(line_3), len(line_4), len(line_5), len(line_6), len(line_7)
LINE_COUNT .byte 0

main
    jsr setup.mmu
    jsr memory.init
    jsr line.init_module

    jsr list.create
    bcc _l1
    jmp _doneError
_l1
    ; set first line
    #memCopy line_1, LINE_BUFFER.buffer, len(line_1)
    lda #len(line_1)
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcc _addLines
    jmp _doneError

    ; add other lines
_addLines
    ldx #0
    stz LINE_COUNT
_loopLines
    ldy LINE_COUNT
    lda LINE_ARRAY, y
    sta memory.MEM_CPY.startAddress
    iny
    lda LINE_ARRAY, y
    sta memory.MEM_CPY.startAddress + 1
    iny
    sty LINE_COUNT
    #cmp16BitImmediate 0, memory.MEM_CPY.startAddress
    bne _continueAdding
    bra _doneAdding
_continueAdding
    #load16BitImmediate LINE_BUFFER.buffer, memory.MEM_CPY.targetAddress
    lda LEN_ARRAY, x
    sta LINE_BUFFER.len
    sta memory.MEM_CPY.length
    stz memory.MEM_CPY.length + 1
    jsr memory.memCpy
    #CALL_X_PROT list.insertAfter
    bcs _doneError
    #CALL_X_PROT list.next
    #CALL_X_PROT list.setCurrentLine
    bcs _doneError
    inx
    bra _loopLines

    ; do movement
_doneAdding
    #copyMem2Mem list.LIST.head, HEAD
    jsr list.rewind
    ldx OFFSET_START
    lda OFFSET_START + 1
    jsr list.move

    stz END_REACHED
    ldx OFFSET_MOVE
    lda OFFSET_MOVE + 1
    jsr list.move    
    bcc _copyElemPtr
    inc END_REACHED
_copyElemPtr
    #copyMem2Mem list.LIST.current, END_POS
    clc    
    brk    
_doneError
    sec    
    brk