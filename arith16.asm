BOOL_FALSE = 0
BOOL_TRUE = 1

; --------------------------------------------------
; load16BitImmediate loads the 16 bit value given in .val into the memory location given
; by .addr 
; --------------------------------------------------
load16BitImmediate .macro  val, addr 
    lda #<\val
    sta \addr
    lda #>\val
    sta \addr+1
.endmacro

; --------------------------------------------------
; move16Bit copies the 16 bit value stored at .memAddr1 to .memAddr2
; --------------------------------------------------
move16Bit .macro  memAddr1, memAddr2 
    ; copy lo byte
    lda \memAddr1
    sta \memAddr2
    ; copy hi byte
    lda \memAddr1+1
    sta \memAddr2+1
.endmacro

; --------------------------------------------------
; double16Bit multiplies the 16 bit value stored at .memAddr by 2
; --------------------------------------------------
double16Bit .macro  memAddr     
    asl \memAddr                     
    rol \memAddr+1
.endmacro

; --------------------------------------------------
; halve16Bit divides the 16 bit value stored at .memAddr by 2
; --------------------------------------------------
halve16Bit .macro  memAddr 
    lsr \memAddr+1
    ror \memAddr
.endmacro


; --------------------------------------------------
; sub16Bit subtracts the value stored at .memAddr1 from the value stored at the
; address .memAddr2. The result is stored in .memAddr2
; --------------------------------------------------
sub16Bit .macro  memAddr1, memAddr2 
    sec
    lda \memAddr2
    sbc \memAddr1
    sta \memAddr2
    lda \memAddr2+1
    sbc \memAddr1+1
    sta \memAddr2+1
.endmacro

; --------------------------------------------------
; sub16BitImmediate subtracts the value .value from the value stored at the
; address .memAddr2. The result is stored in .memAddr2
; --------------------------------------------------
sub16BitImmediate .macro value, memAddr2
    sec
    lda \memAddr2
    sbc #<\value
    sta \memAddr2
    lda \memAddr2+1
    sbc #>\value
    sta \memAddr2+1
.endmacro

; --------------------------------------------------
; add16Bit implements a 16 bit add of the values stored at memAddr1 and memAddr2 
; The result is stored in .memAddr2
; --------------------------------------------------
add16Bit .macro  memAddr1, memAddr2 
    clc
    ; add lo bytes
    lda \memAddr1
    adc \memAddr2
    sta \memAddr2
    ; add hi bytes
    lda \memAddr1+1
    adc \memAddr2+1
    sta \memAddr2+1
.endmacro

; --------------------------------------------------
; add16BitByte implements a 16 bit add of the byte stored at memAddr1 and the
; 16 bit value stored at memAddr2. The result is stored in .memAddr2
; --------------------------------------------------
add16BitByte .macro  memAddr1, memAddr2 
    clc
    ; add lo bytes
    lda \memAddr1
    adc \memAddr2
    sta \memAddr2
    ; add hi bytes
    lda #0
    adc \memAddr2+1
    sta \memAddr2+1
.endmacro

; --------------------------------------------------
; add16BitImmediate implements a 16 bit add of an immediate value to value stored at memAddr2 
; The result is stored in .memAddr2
; --------------------------------------------------
add16BitImmediate .macro  value, memAddr2 
    clc
    ; add lo bytes
    lda #<\value
    adc \memAddr2
    sta \memAddr2
    ; add hi bytes
    lda #>\value
    adc \memAddr2+1
    sta \memAddr2+1
.endmacro


; --------------------------------------------------
; inc16Bit implements a 16 bit increment of the 16 bit value stored at .memAddr 
; --------------------------------------------------
inc16Bit .macro  memAddr 
    clc
    lda #1
    adc \memAddr
    sta \memAddr
    bcc _noCarryInc
    inc \memAddr+1
_noCarryInc
.endmacro

; --------------------------------------------------
; dec16Bit implements a 16 bit decrement of the 16 bit value stored at .memAddr 
; --------------------------------------------------
dec16Bit .macro  memAddr
    lda \memAddr
    sec
    sbc #1
    sta \memAddr
    lda \memAddr+1
    sbc #0
    sta \memAddr+1
.endmacro


; --------------------------------------------------
; cmp16Bit compares the 16 bit values stored at memAddr1 and memAddr2 
; Z  flag is set in case these values are equal
; --------------------------------------------------
cmp16Bit .macro  memAddr1, memAddr2 
    lda \memAddr1+1
    cmp \memAddr2+1
    bne _unequal
    lda \memAddr1
    cmp \memAddr2
_unequal
.endmacro

; --------------------------------------------------
; cmp16BitImmediate compares the 16 bit value stored at memAddr with
; the immediate value given in .value.
; 
; Z  flag is set in case these values are equal. Carry is set
; if .value is greater or equal than the value store at .memAddr
; --------------------------------------------------
cmp16BitImmediate .macro  value, memAddr 
    lda #>\value
    cmp \memAddr+1
    bne _unequal2
    lda #<\value
    cmp \memAddr
_unequal2
.endmacro


twosComplement16 .macro memAddr
    lda \memAddr
    eor #$FF
    sta \memAddr
    lda \memAddr+1
    eor #$FF
    sta \memAddr+1
    #add16BitImmediate 1, \memAddr
.endmacro


mul8x8BitCoproc .macro oper1, oper2, oper3
    lda \oper1
    sta $DE00
    stz $DE01
    lda \oper2
    sta $DE02
    stz $DE03
    #move16Bit $DE10, \oper3
.endmacro


copyPtrToStruct .macro ptr, mem, len
    ldy #0
_loop
    lda (\ptr), y
    sta \mem, y
    iny
    cpy #\len
    bne _loop
.endmacro


copyStructToPtr .macro mem, ptr, len
    ldy #0
_loop
    lda \mem, y
    sta (\ptr), y
    iny
    cpy #\len
    bne _loop   
.endmacro

ModN_t .struct
    arg1 .word 0
    arg2 .word 0
    temp_modn .word 0
    underflow_occurred .byte 0
.endstruct

; --------------------------------------------------
; This macro calculates A + X mod N. We have to use 16 bit arithmetic
; because in our main use case (mod 60 in BCD) for instance the intermediate
; result 59 + 59 = 118 does not fit in one byte (in BCD the maximum value
; of a byte is 99). 
; 
; It returns the result in the accu. Carry is set if an overflow occured.
; --------------------------------------------------
addModN2 .macro modulus, helper
    sta \helper.arg1
    stz \helper.arg1 +  1
    stx \helper.arg2
    stz \helper.arg2 + 1
    #add16Bit \helper.arg1, \helper.arg2    ; ARG2 = ARG1 + ARG2
    #cmp16BitImmediate \modulus, \helper.arg2      ; .modulus >= ARG2?
    beq _reduce                             ; .modulus == ARG2 => reduce and set carry upon return
    bcs _clearCarryNoReduce                 ; .modulus > ARG2 => do not reduce and clear carry upon return
_reduce
    #sub16BitImmediate \modulus, \helper.arg2      ; Reduce: ARG2 = ARG2 - .modulus
    sec                                    
_addDone
    lda \helper.arg2                               ; load result in accu
    rts
_clearCarryNoReduce
    clc
    bra _addDone
.endmacro

; --------------------------------------------------
; This macro calculates A - X mod N. We have to use 16 bit arithmetic
; because in our main use case (mod 60 in BCD) intermediate results
; may not fit in one byte, as the maximum value of a byte in BCD is 99.
; 
; It returns the result in the accu. Carry is set if an underflow occured.
; --------------------------------------------------
subModN2 .macro modulus, helper
    sta \helper.arg1
    stz \helper.arg1 + 1 
    stx \helper.arg2
    stz \helper.arg2 + 1

    ; determine if there will an underflow, i.e. dtermine if X > A
    stz \helper.underflow_occurred
    lda \helper.arg2
    cmp \helper.arg1
    beq _startCalc                      ; values are equal => No underflow, carry has to be clear
    bcc _startCalc                      ; ARG2 < ARG1 (i.e. X < A) => No underflow carry has to be clear
    inc \helper.underflow_occurred

_startCalc
    ; negate ARG2 mod modulus, i.e. calculate modulus - ARG2
    #load16BitImmediate \modulus, \helper.temp_modn
    #sub16Bit \helper.arg2, \helper.temp_modn

    ; add ARG1 to the negated value
    #move16Bit \helper.temp_modn, \helper.arg2
    #add16Bit \helper.arg1, \helper.arg2

    ; check if we have to reduce result
    #cmp16BitImmediate \modulus, \helper.arg2
    beq _reduceSub                     ; we just hit the modulus => we have to reduce result
    bcs _doneSubN                      ; .modulus >= ARG2 => with the above test we can be sure that .modulus > ARG2. No reduction neccessary.    
_reduceSub
    #sub16BitImmediate \modulus, \helper.arg2  ; reduce mod .modulus. ARG2 = ARG2 - .modulus
_doneSubN
    ; make sure that carry is set to correct value upon return
    clc
    lda \helper.underflow_occurred
    beq _finishSubN                    ; Did we precalculate that an underflow occurs?
    sec                                ; yes => set carry
_finishSubN
    lda \helper.arg2                   ; load result in acccu
.endmacro
