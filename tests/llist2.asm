* = $0800
.cpu "w65c02"

jmp main

STATE    .word memory.MEM_STATE    ; 3
PTR1     .dstruct FarPtr_t         ; 5
PTR2     .dstruct FarPtr_t         ; 8
LLEN     .word $FFFF               ; 11


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"
.include "line.asm"
.include "search.asm"
.include "linked_list.asm"

line_1 .text "This is line 1"
line_2 .text "Line 2 this is, really!"

main
    jsr setup.mmu
    jsr memory.init
    jsr line.init_module

    jsr list.create
    bcc _l1
    jmp _done
_l1
    #copyMem2Mem list.LIST.current, PTR1

    #memCopy line_1, LINE_BUFFER.buffer, len(line_1)
    lda #len(line_1)
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcs _done

    jsr list.insertAfter
    bcs _done
    jsr list.next
    bcs _done

    #copyMem2Mem list.LIST.current, PTR2

    #memCopy line_2, LINE_BUFFER.buffer, len(line_2)
    lda #len(line_2)
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcs _done
    
    #move16Bit list.LIST.length, LLEN

    jsr list.next
    ; here we expect that the carry is set
    bcc _done

    clc
    brk    
_done
    sec
    brk