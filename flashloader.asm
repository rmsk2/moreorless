; MMU reg    8K RAM block address space
; 8          0            0000 - 1FFF
; 9          1            2000 - 3FFF
; 10         2            4000 - 5FFF
; 11         3            6000 - 7FFF
; 12         4            8000 - 9FFF
; 13         5            A000 - BFFF
; 14         6            C000 - DFFF
; 15         7            E000 - FFFF
;
; LOAD_ADDRESS can be the start address of any 8K block in the 64K base memory

LOAD_ADDRESS   = $A000
SOURCE_ADDRESS = $8000
TARGET_ADDRESS = $6000
MMU_SOURCE     = (SOURCE_ADDRESS / $2000) + 8
MMU_TARGET     = (TARGET_ADDRESS / $2000) + 8

* = LOAD_ADDRESS
.cpu "w65c02"

; Start address of your program
PAYLOAD_START = $0300
; Number of 8K blocks to copy from flash
NUM_8K_BLOCKS = 4

; This is the kernel header. It must begin at LOAD_ADDRESS
KUPHeader
.byte $F2                                  ; signature
.byte $56                                  ; signature
.byte NUM_8K_BLOCKS                        ; length of program in consecutive 8K flash blocks
.byte LOAD_ADDRESS / $2000                 ; block in 16 bit address space to which the first block is mapped
.word loader                               ; start address of program
.byte $01, $00, $00, $00                   ; reserved. All examples I looked at had a $01 in the first position
.text "mless"                              ; name of the program used for starting
.byte $00                                  ; zero termination for "mless"
.text "<drv:file>"                         ; parameter description
.byte $00                                  ; zero termination for parameter description
.text "A simple text editor"               ; Comment shown in lsf
.byte $00                                  ; zero termination for comment


.include "zeropage.asm"


STRUCT_INDEX = TXT_PTR1
COUNT_PAGE = TXT_PTR1 + 1
END_PAGE = TXT_PTR2
COUNT_BLOCK = TXT_PTR2 + 1

PTR_STRUCT = MEM_PTR3

BlockSpec_t .struct s, t, sp, ep
    sourceBlock .byte \s               ; source of block to copy, i.e. a block number (>= 64) in flash memory
    targetBlock .byte \t               ; target of block to copy, i.e. a block in RAM (0 <= block <= 7)
    startPage   .byte \sp              ; the page number (one page = 256 bytes) where the copy operation should be copied 
    endPage     .byte \ep              ; the page number where the copy operation should stop. There are 32 pages in an 8K block
.endstruct

load16BitImmediate .macro  val, addr 
    lda #<\val
    sta \addr
    lda #>\val
    sta \addr+1
.endmacro


; Please add an entry for each 8K data block which you want to copy from flash
BLOCK1 .dstruct BlockSpec_t, $00, 0, 3, 32  ; copy flash block $17 (block number 64 + $17) to RAM block 0. Start at offset $0300
BLOCK2 .dstruct BlockSpec_t, $00, 1, 0, 32  ; copy flash block $18 (block number 64 + $18) to RAM block 1. Start at offset $0000
BLOCK3 .dstruct BlockSpec_t, $00, 2, 0, 32  ; copy flash block $19 (block number 64 + $19) to RAM block 2. Start at offset $0000
BLOCK4 .dstruct BlockSpec_t, $00, 3, 0, 32  ; copy flash block $1A (block number 64 + $1A) to RAM block 3. Start at offset $0000

loader
    ; setup MMU
    lda #%10110011                         ; set active and edit LUT to three and allow editing
    sta 0
    lda #%00000000                         ; enable io pages and set active page to 0
    sta 1

    jsr relocate

    ; set struct base address
    #load16BitImmediate COPY_TAB, PTR_STRUCT
    stz STRUCT_INDEX
    stz COUNT_BLOCK
_loop8K
    ldy STRUCT_INDEX
    ; map source flashblock
    lda (PTR_STRUCT), y    
    sta MMU_SOURCE
    ; map target RAM block
    iny
    lda (PTR_STRUCT), y
    sta MMU_TARGET
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
    ; set pointers for copy operation to their base addresses
    #load16BitImmediate SOURCE_ADDRESS, PTR_SOURCE
    #load16BitImmediate TARGET_ADDRESS, PTR_TARGET
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
    lda #MMU_TARGET - 8
    sta MMU_TARGET
    lda #MMU_SOURCE - 8
    sta MMU_SOURCE
    jmp PAYLOAD_START


copyStruct
    lda #NUM_8K_BLOCKS
    asl
    asl
    sta NUM_BYTES
    ldy #0
_loop
    lda BLOCK1, y
    sta COPY_TAB, y
    iny
    cpy NUM_BYTES
    bne _loop
    rts


updateBlocks
    lda #NUM_8K_BLOCKS
    asl
    asl
    sta NUM_BYTES
    ldy #0
    lda 13
_loop
    sta COPY_TAB, y
    iny
    iny
    iny
    iny
    cpy NUM_BYTES
    beq _end
    ina
    bra _loop
_end
    rts

relocate
    jsr copyStruct
    jsr updateBlocks
    rts

; pad the binary out to 768 = $0300 bytes
END_PROG
    .fill LOAD_ADDRESS + PAYLOAD_START - END_PROG - 1
    .byte 0