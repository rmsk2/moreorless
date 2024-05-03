setup .namespace

mmu
    ; setup MMU, this seems to be neccessary when running as a PGZ
    lda #%10110011                         ; set active and edit LUT to three and allow editing
    sta 0
    lda #%00000000                         ; enable io pages and set active page to 0
    sta 1

    ; map BASIC ROM out and RAM in
    lda #4
    sta 8+4
    lda #5
    sta 8+5
    rts

; 8  0: 0000 - 1FFF
; 9  1: 2000 - 3FFF
; 10 2: 4000 - 5FFF
; 11 3: 6000 - 7FFF
; 12 4: 8000 - 9FFF
; 13 5: A000 - BFFF
; 14 6: C000 - DFFF
; 15 7: E000 - FFFF
;
; RAM expansion 
; 0x100000 - 0x13FFFF

BANK =  $81

TEMP_CHECK  .byte 0
TEMP_CHECK2 .byte 0
TEMP_MMU    .byte 0

; carry is set if no RAM expansion is detected
checkForRamExpansion
    ; save current data at $A100
    lda $A100
    sta TEMP_CHECK

    ; save MMU state
    lda 13
    sta TEMP_MMU

    ; switch to upper memory
    lda #BANK
    sta 13

    lda TEMP_CHECK
    ; make sure value is different from the one at $A100
    ina
    sta TEMP_CHECK2
    ; store in high memory
    sta $A100
    ; load from high memory
    lda $A100    
    cmp TEMP_CHECK2
    bne _error

    ; restore MMU state
    lda TEMP_MMU    
    sta 13

    ; load from low memory
    lda $A100
    cmp TEMP_CHECK
    bne _error2
    clc
    rts
_error
    ; restore MMU state
    lda TEMP_MMU    
    sta 13
_error2
    sec
    rts

.endnamespace