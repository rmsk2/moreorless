* = $0800
.cpu "w65c02"

jmp main

STATE    .word memory.MEM_STATE    ; 3
PTR1     .dstruct FarPtr_t         ; 5
PTR2     .dstruct FarPtr_t         ; 8
LLEN     .word $FFFF               ; 11
PTR3     .dstruct FarPtr_t         ; 13


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"
.include "line.asm"
.include "search.asm"
.include "linked_list.asm"

line_1 .text "this is line 2"
line_2 .text "line 2 this is, really!"
line_3 .text "this is line one and things are longer and longer"

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
    bcc _l2
    rts
_l2
    jsr list.insertBefore
    bcc _l3
    rts
_l3
    jsr list.insertBefore
    bcc _l4
    rts
_l4
    jsr list.prev
    bcc _l5
    rts
_l5
    #copyMem2Mem list.LIST.current, PTR2

    #memCopy line_2, LINE_BUFFER.buffer, len(line_2)
    lda #len(line_2)
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcs _done

    jsr list.prev
    bcs _done

    #copyMem2Mem list.LIST.current, PTR3

    #memCopy line_3, LINE_BUFFER.buffer, len(line_3)
    lda #len(line_3)
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcs _done

    #move16Bit list.LIST.length, LLEN

    jsr list.prev
    ; here we expect that the carry is set
    bcc _done

    clc
    brk    
_done
    sec
    brk