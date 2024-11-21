; put some well used data structures into zero page
KeyTracking_t .struct
    numMeasureTimersInFlight .byte 0
    numRepeatTimersInFlight  .byte 0
    keyUpDownCount           .byte 0
    lastKeyPressed           .byte 0
    lastKeyReleased          .byte 0
    metaState                .byte 0
.endstruct

TimerHelp_t .struct 
    interval .byte 0
    cookie   .byte 0
.endstruct

; put some well used data structures into the zero page
;
; * = $40
.virtual $40
.if KEY_VAL == 0
; length 6 bytes
BIN_STATE  .dstruct BinState_t
.endif
; length 6 bytes
TRACKING   .dstruct KeyTracking_t
; length 2 bytes
TIMER_HELP .dstruct TimerHelp_t
; $4E
.endvirtual