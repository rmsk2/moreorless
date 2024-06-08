KeyEntry_t .struct val, vector
    keyComb .word \val
    addr    .word \vector
.endstruct

BinState_t .struct
    numEntries .byte 0
    l          .byte 0
    r          .byte 0
    m          .byte 0
    searchVal  .word 0
.endstruct


binsearch .namespace

; upon call KEY_SEARCH_PTR has to be set to the entries. A (lo, keycode) and X (hi, meta keys) 
; have to contain the value to search for. Upon exit if the carry is set an entry has been found
; and y contains the position of the found entry realtive to KEY_SEARCH_PTR
searchEntry
    sta BIN_STATE.searchVal
    stx BIN_STATE.searchVal + 1
    lda BIN_STATE.numEntries
    dea
    sta BIN_STATE.r
    stz BIN_STATE.l
_loop
    ; check if L > R => if yes the entry is not found
    lda BIN_STATE.l
    cmp BIN_STATE.r
    beq _goOn                          ; L = R is allowed
    bcs _notFound                      ; here L > R and we have not found our value
_goOn
    ; calc m = floor((L + R) / 2) 
    clc
    lda BIN_STATE.l
    adc BIN_STATE.r
    lsr
    sta BIN_STATE.m
    ; calc index (m * 4) of array element at m
    asl
    asl
    tay
    ; check A[m] == BIN_STATE.searchVal
    iny
    lda (KEY_SEARCH_PTR), y
    cmp BIN_STATE.searchVal + 1
    beq _checkSecond
    bne _next
_checkSecond
    dey
    lda (KEY_SEARCH_PTR), y
    cmp BIN_STATE.searchVal
    beq _found                         ; we have found the entry
_next
    bcs _bigger
    lda BIN_STATE.m
    ina
    sta BIN_STATE.l
    bra _loop
_bigger
    lda BIN_STATE.m
    dea
    sta BIN_STATE.r
    bra _loop
_found
    sec
    rts
_notFound
    clc
    rts



.endnamespace