
* = $0800
.cpu "w65c02"

jmp main

CLIP_LEN     .word 0             ; 3
CLIP_HEAD    .dstruct FarPtr_t   ; 5
; 8

.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"
.include "line.asm"
.include "search.asm"
.include "linked_list.asm"
.include "copy_cut.asm"

main
    jsr setup.mmu
    jsr memory.init
    jsr list.create

    jsr clip.createClipFromMemory
    php
    #move16Bit clip.CLIP.length, CLIP_LEN
    #copyMem2Mem clip.CLIP.head, CLIP_HEAD
    plp
    brk
