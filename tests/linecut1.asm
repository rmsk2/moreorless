* = $0800
.cpu "w65c02"

jmp main

TEST_LINE     .fill 80                   ; 3
TEST_LINE_LEN .byte 0                    ; 83
START_POS     .byte 0                    ; 84
LEN_COPY      .byte 0                    ; 85
ADDR_LINE_BUF .word LINE_BUFFER.buffer   ; 86
LINE_BUF_LEN  .byte 0                    ; 88
LIST_START    .dstruct FarPtr_t          ; 89

.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"
.include "search.asm"
.include "line.asm"
.include "linked_list.asm"
.include "copy_cut.asm"

main
    jsr setup.mmu
    jsr memory.init
    jsr line.init_module
    jsr clip.init

    jsr list.create
    bcs _done

    #copyMem2Mem list.LIST.current, LIST_START

    ldy #0
_copyLoop
    lda TEST_LINE, y
    sta LINE_BUFFER.buffer, y
    iny
    cpy TEST_LINE_LEN
    bne _copyLoop
    ; save to list element
    lda TEST_LINE_LEN
    sta LINE_BUFFER.len
    jsr list.setCurrentLine
    bcs _done    

    ; set parameter for cutting from line
    lda START_POS
    sta clip.LINE_CLIP.startPos
    lda LEN_COPY
    sta clip.LINE_CLIP.lenCopy
    jsr clip.lineClipCut
    ; copy len of modified buffer
    lda LINE_BUFFER.len
    sta LINE_BUF_LEN
_done
    brk
