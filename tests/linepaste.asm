* = $0800
.cpu "w65c02"

jmp main

TEST_LINE     .fill 80                   ; 3
TEST_LINE_LEN .byte 0                    ; 83
INSERT_POS    .byte 0                    ; 84
LEN_COPY      .byte 0                    ; 85
ADDR_LINE_BUF .word LINE_BUFFER.buffer   ; 86
LINE_BUF_LEN  .byte 0                    ; 88
LIST_START    .dstruct FarPtr_t          ; 89
TEST_CLIP_LEN .byte 0                    ; 92
TEST_CLIP     .fill 80                   ; 93


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

    ; fill line
    ldy #0
_copyLoop
    lda TEST_LINE, y
    sta LINE_BUFFER.buffer, y
    iny
    cpy TEST_LINE_LEN
    bne _copyLoop
    ; save to list element
    sty LINE_BUFFER.len
    jsr list.setCurrentLine
    bcs _done    

    ; fill clipboard
    ldy #0
_copyLoop2
    lda TEST_CLIP, y
    sta clip.LINE_CLIP.buffer, y
    iny
    cpy TEST_CLIP_LEN
    bne _copyLoop2
    sty clip.LINE_CLIP.lenBuffer

    ; set parameter for pasting into line
    lda INSERT_POS
    jsr clip.lineClipPaste
    ; copy len of modified buffer
    lda LINE_BUFFER.len
    sta LINE_BUF_LEN
_done
    brk
