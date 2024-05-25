* = $0800
.cpu "w65c02"

jmp main

res1 .word 0              ; 3
res2 .word 0              ; 5
res3 .word 0              ; 7
res4 .word 0              ; 9
res5 .word 0              ; 11

.include "zeropage.asm"
.include "arith16.asm"
.include "conv.asm"

test1 .text "0"
test2 .text "1"
test3 .text "23"
test4 .text "65525"
test5 .text "65535"

main
    #load16BitImmediate test1, CONV_PTR1
    lda #len(test1)
    jsr conv.atouw
    #move16Bit conv.ATOW, res1

    #load16BitImmediate test2, CONV_PTR1
    lda #len(test2)
    jsr conv.atouw
    #move16Bit conv.ATOW, res2

    #load16BitImmediate test3, CONV_PTR1
    lda #len(test3)
    jsr conv.atouw
    #move16Bit conv.ATOW, res3

    #load16BitImmediate test4, CONV_PTR1
    lda #len(test4)
    jsr conv.atouw
    #move16Bit conv.ATOW, res4

    #load16BitImmediate test5, CONV_PTR1
    lda #len(test5)
    jsr conv.atouw
    #move16Bit conv.ATOW, res5
    brk