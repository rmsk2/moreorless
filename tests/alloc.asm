* = $0800
.cpu "w65c02"

jmp main

STATE    .word memory.MEM_STATE         ; 3
NUM_ITER .byte 0                        ; 5

PTR1 .dstruct FarPtr_t                  ; 6
PTR2 .dstruct FarPtr_t                  ; 9
PTR3 .dstruct FarPtr_t                  ; 12
PTR4 .dstruct FarPtr_t                  ; 15
PTR5 .dstruct FarPtr_t                  ; 18
PTR6 .dstruct FarPtr_t                  ; 21
PTR7 .dstruct FarPtr_t                  ; 24
PTR8 .dstruct FarPtr_t                  ; 27

.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"


main
    jsr setup.mmu
    jsr memory.init

    #load16BitImmediate PTR1, MEM_PTR3
    ldx #0
_loop
    phx
    jsr memory.allocPtr
    bcs _doneError
    plx
    #add16BitImmediate size(FarPtr_t), MEM_PTR3
    inx
    cpx NUM_ITER
    bne _loop
    clc
    bra _done 
_doneError
    plx
_done
    ; carry is set if an error occured
    brk