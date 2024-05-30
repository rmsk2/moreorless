* = $0800
.cpu "w65c02"

jmp main

STATE    .word memory.MEM_STATE    ; 3


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"
.include "line.asm"
.include "search.asm"
.include "linked_list.asm"

line_1 .text "this is the middle line and it is longer than the others by quite a bit. it still does not stop. it goes on and on and on ..."
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
    bcs _done

    #memCopy line_3, LINE_BUFFER.buffer, len(line_3)
    lda #len(line_3)
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcs _done

    jsr list.destroy

    clc
    brk    
_done
    sec
    brk