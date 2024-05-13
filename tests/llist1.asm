* = $0800
.cpu "w65c02"

jmp main

STATE    .word memory.MEM_STATE    ; 3
LBUFFER  .word LINE_BUFFER.buffer  ; 5
LBLEN    .word LINE_BUFFER.len     ; 7
TEST     .byte 0                   ; 9
PTR1     .dstruct FarPtr_t         ; 10
LLEN     .word $FFFF               ; 13


.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"
.include "line.asm"
.include "linked_list.asm"

main
    jsr setup.mmu
    jsr memory.init

    ; this is set by the arrange function => save it
    lda LINE_BUFFER.len
    sta TEST
    
    jsr line.init_module
    
    ; restore length
    lda TEST
    sta LINE_BUFFER.len

    jsr list.create
    bcs _done

    #copyMem2Mem list.LIST.current, PTR1
    jsr list.setCurrentLine
    bcs _done

    ; shorten line to 31 characters and one block. Free the others.
    lda #31
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcs _done

    ; Add to characters to line and allocate an additional block.
    lda #33
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcs _done

    ; clear line buffer, in order to detect wrong data copied in next step
    ldy #0
    lda #0
_loop
    sta LINE_BUFFER.buffer, y
    iny
    cpy #33
    bne _loop
    sta LINE_BUFFER.len

    ; copy data into line buffer
    jsr list.readCurrentLine

    #move16Bit list.LIST.length, LLEN
    clc    
_done
    brk