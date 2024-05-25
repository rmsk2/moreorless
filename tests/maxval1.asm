* = $0800
.cpu "w65c02"

jmp main

res1 .byte 0              ; 3
res2 .byte 0              ; 4
res3 .byte 0              ; 5
res4 .byte 0              ; 6
res5 .byte 0              ; 7

.include "zeropage.asm"
.include "arith16.asm"
.include "conv.asm"

test1 .text "0"
test2 .text "345"
test3 .text "100000"
test4 .text "65536"
test5 .text "65535"

main
    stz res1
    #load16BitImmediate test1, CONV_PTR1
    lda #len(test1)
    jsr conv.checkMaxWord
    bcc _l2
    inc res1
_l2
    stz res2
    #load16BitImmediate test2, CONV_PTR1
    lda #len(test2)
    jsr conv.checkMaxWord
    bcc _l3
    inc res2
_l3
    stz res3
    #load16BitImmediate test3, CONV_PTR1
    lda #len(test3)
    jsr conv.checkMaxWord
    bcc _l4
    inc res3
_l4
    stz res4
    #load16BitImmediate test4, CONV_PTR1
    lda #len(test4)
    jsr conv.checkMaxWord
    bcc _l5
    inc res4
_l5
    stz res5
    #load16BitImmediate test5, CONV_PTR1
    lda #len(test5)
    jsr conv.checkMaxWord
    bcc _l6
    inc res5
_l6    
    brk