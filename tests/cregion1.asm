* = $0800
.cpu "w65c02"

jmp main

START_POS .word 0     ; 3
COPY_LEN  .word 0     ; 5        


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"
.include "line.asm"
.include "search.asm"
.include "linked_list.asm"
.include "copy_cut.asm"


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
    jsr clip.init

    jsr list.create
    bcc _l1
    jmp _doneError
_l1
    ; set first line
    #memCopy line_1, LINE_BUFFER.buffer, len(line_1)
    lda #len(line_1)
    sta LINE_BUFFER.len
    jsr line.toLower
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
    #CALL_X_PROT line.toLower
    #CALL_X_PROT list.insertAfter
    bcc _l4
    jmp _doneError
_l4
    #CALL_X_PROT list.next    
    #CALL_X_PROT list.setCurrentLine
    bcc _l5
    jmp _doneError
_l5
    inx
    bra _loopLines

    
_doneAdding
    ; move to specified elements
    jsr list.rewind
    ldx START_POS
    lda START_POS + 1
    jsr list.move
    jsr list.readCurrentLine
    ; copy lines
    #copyMem2Mem list.LIST.current, clip.CPCT_PARMS.start
    #move16Bit COPY_LEN, clip.CPCT_PARMS.len
    jsr clip.copyRegion
    lda clip.COPY_REGION.copyOk
    beq _doneError
    clc
    brk
_doneError
    sec    
    brk