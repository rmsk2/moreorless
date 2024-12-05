* = $A000
.cpu "w65c02"

KUPHeader
.byte $F2                                  ; signature
.byte $56                                  ; signature
.byte $01                                  ; length of program
.byte $05                                  ; block in 16 bit address space, 05 = $A000
.word loader                               ; start address
.byte $01, $00, $00, $00                   ; reserved. All examples I looked at had a $01 in this position
.text "mless"                              ; name of the program used for starting
.byte $00                                  ; zero termination for "mless"
.byte $00                                  ; no parameter description, i.e. an empty string
.text "A simple text editor"               ; Comment shown in lsf
.byte $00                                  ; zero termination for comment

.include "zeropage.asm"
STRUCT_INDEX = TXT_PTR1
COUNT_PAGE = TXT_PTR1 + 1
END_PAGE = TXT_PTR2
COUNT_BLOCK = TXT_PTR2 + 1

PTR_SOURCE = MEM_PTR1
PTR_TARGET = MEM_PTR2
PTR_STRUCT = MEM_PTR3

BlockSpec_t .struct s, t, sp, ep
    sourceBlock .byte \s
    targetBlock .byte \t
    startPage   .byte \sp
    endPage     .byte \ep
.endstruct

load16BitImmediate .macro  val, addr 
    lda #<\val
    sta \addr
    lda #>\val
    sta \addr+1
.endmacro

PAYLOAD_START = $0300
NUM_8K_BLOCKS = 3

BLOCK1 .dstruct BlockSpec_t, 64 + $18, 0, 3, 32
BLOCK2 .dstruct BlockSpec_t, 64 + $19, 1, 0, 32
BLOCK3 .dstruct BlockSpec_t, 64 + $1a, 2, 0, 32

; 8  0: 0000 - 1FFF
; 9  1: 2000 - 3FFF
; 10 2: 4000 - 5FFF
; 11 3: 6000 - 7FFF
; 12 4: 8000 - 9FFF
; 13 5: A000 - BFFF
; 14 6: C000 - DFFF
; 15 7: E000 - FFFF


loader
    ; setup MMU
    lda #%10110011                         ; set active and edit LUT to three and allow editing
    sta 0
    lda #%00000000                         ; enable io pages and set active page to 0
    sta 1
    ; set struct base address
    #load16BitImmediate BLOCK1, PTR_STRUCT
    stz STRUCT_INDEX
    stz COUNT_BLOCK
_loop8K
    ldy STRUCT_INDEX
    ; map source flashblock
    lda (PTR_STRUCT), y    
    sta 12
    ; map target RAM block
    iny
    lda (PTR_STRUCT), y
    sta 11
    ; store start page
    iny
    lda (PTR_STRUCT), y    
    sta COUNT_PAGE
    ; store end page
    iny
    lda (PTR_STRUCT), y
    sta END_PAGE
    ; go to start of next struct
    iny
    sty STRUCT_INDEX
    ; set pointers for copy operation to their base address
    #load16BitImmediate $8000, PTR_SOURCE
    #load16BitImmediate $6000, PTR_TARGET
    ; add start page offset to source
    lda COUNT_PAGE
    clc
    adc PTR_SOURCE + 1
    sta PTR_SOURCE + 1
    ; add start page offset to target
    lda COUNT_PAGE
    clc
    adc PTR_TARGET + 1
    sta PTR_TARGET + 1
_copyNextPage
    ldy #0
    ; copy 8K block
_copyPage
    ; copy single page
    lda (PTR_SOURCE), y
    sta (PTR_TARGET), y
    iny
    bne _copyPage
    ; update source and target addresses
    inc PTR_SOURCE + 1
    inc PTR_TARGET + 1
    ; increment page counter
    inc COUNT_PAGE
    lda COUNT_PAGE
    cmp END_PAGE
    bne _copyNextPage
    ; test if all 8k blocks have been copied
    inc COUNT_BLOCK
    lda COUNT_BLOCK
    cmp #NUM_8K_BLOCKS
    bne _loop8K
    ; restore MMU
    lda #3
    sta 11
    lda #4
    sta 12
    jmp PAYLOAD_START


END_PROG
    .fill $C000 - END_PROG - 1
    .byte 0