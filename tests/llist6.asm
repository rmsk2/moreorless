* = $0800
.cpu "w65c02"

jmp main

STATE       .word memory.MEM_STATE    ; 3
HEAD_PTR    .dstruct FarPtr_t         ; 5
LLEN        .word $FFFF               ; 8
END_PTR     .dstruct FarPtr_t         ; 10
LLEN2       .word $FFFF               ; 13
CURRENT_PTR .dstruct FarPtr_t         ; 15


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"
.include "line.asm"
.include "linked_list.asm"

line_1 .text "this is the middle line and it is longer than the others by quite a bit"
line_2 .text "this is the first line"
line_3 .text "this is the last line"

main
    jsr setup.mmu
    jsr memory.init
    jsr line.init_module

    jsr list.create
    bcc _l1
    jmp _done
_l1
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
    jsr list.insertAfter
    bcc _l4
    rts
_l4
    jsr list.prev
    bcc _l5
    rts
_l5
    #memCopy line_2, LINE_BUFFER.buffer, len(line_2)
    lda #len(line_2)
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcc _l6
    rts
_l6
    jsr list.next
    bcc _l7
    rts
_l7
    jsr list.next
    bcc _l8
    rts
_l8
    #copyMem2Mem list.LIST.current, END_PTR

    #memCopy line_3, LINE_BUFFER.buffer, len(line_3)
    lda #len(line_3)
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcs _done

    #move16Bit list.LIST.length, LLEN

    jsr list.prev
    bcs _done

    jsr list.remove
    bcs _done

    #copyMem2Mem list.LIST.head, HEAD_PTR
    #copyMem2Mem list.LIST.current, CURRENT_PTR

    #move16Bit list.LIST.length, LLEN2

    jsr list.next
    bcc _done

    clc
    rts    
_done
    sec
    brk