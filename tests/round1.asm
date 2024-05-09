* = $0800
.cpu "w65c02"

jmp main

STATE    .word memory.MEM_STATE         ; 3
NUM_ITER .byte 0                        ; 5

PTR1 .dstruct FarPtr_t
PTR2 .dstruct FarPtr_t
PTR3 .dstruct FarPtr_t
PTR4 .dstruct FarPtr_t
PTR5 .dstruct FarPtr_t
PTR6 .dstruct FarPtr_t
PTR7 .dstruct FarPtr_t
PTR8 .dstruct FarPtr_t

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
    bra _free 
_doneError
    plx
_done
    ; carry is set if an error occured
    brk
_free
    #load16BitImmediate PTR2, MEM_PTR3
    jsr memory.freePtr
    #load16BitImmediate PTR4, MEM_PTR3
    jsr memory.freePtr
    #load16BitImmediate PTR6, MEM_PTR3
    jsr memory.freePtr
    #load16BitImmediate PTR8, MEM_PTR3
    jsr memory.freePtr
    brk