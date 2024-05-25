* = $0800
.cpu "w65c02"

jmp main

STATE    .word memory.MEM_STATE    ; 3
PTR1     .dstruct FarPtr_t         ; 5


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"
.include "line.asm"
.include "linked_list.asm"

line_1 .text "This is line 1"

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
    jsr list.insertAfter
    bcc _l3
    rts
_l3
    jsr list.insertAfter
    bcc _l4
    rts
_l4
    jsr list.next
    bcc _l5
    rts
_l5
    jsr list.next
    bcs _done

    jsr list.next
    bcc _done

    jsr list.prev
    bcs _done

    jsr list.prev
    bcs _done

    jsr list.prev
    bcc _done

    #copyMem2Mem list.LIST.current, PTR1

    clc
    brk   
_done
    sec
    brk