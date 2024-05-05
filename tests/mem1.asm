* = $0800
.cpu "w65c02"

jmp main

SOURCE .word 0
LENGTH .word 0
TARGET .word 0
VALUE  .byte 0

.include "zeropage.asm"
.include "setup.asm"
.include "arith16.asm"
.include "memory.asm"

main
    ; set block to defined value
    #move16Bit SOURCE, memory.MEM_SET.startAddress
    #move16Bit LENGTH, memory.MEM_SET.length
    lda VALUE
    sta memory.MEM_SET.valToSet
    ;
    ; move modified block
    jsr memory.memSet
    #move16Bit SOURCE, memory.MEM_CPY.startAddress
    #move16Bit TARGET, memory.MEM_CPY.targetAddress
    #move16Bit LENGTH, memory.MEM_CPY.length
    jsr memory.memCpy
    brk