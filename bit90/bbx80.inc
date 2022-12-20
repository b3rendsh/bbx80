; ------------------------------------------------------------------------------
; BBX80 Include v1.0
;
; Definitions used in BBX80 modules
; ------------------------------------------------------------------------------

; Version
DEFL BBXVERSION = "V1.0"

; Video system
VIDEOHZ:	EQU	50		; 60 for NTSC / 50 for PAL systems (used in timers)

;RST Routines
R_dspCRLF:	EQU	$08
R_dspTell:	EQU	$10
R_dspChar:	EQU	$18
R_NMIstop:	EQU	$20
R_NMIstart:	EQU	$28

; I/O Ports (BIT90)
IOCOM0:		EQU	$44		; RS232 Data I/O
IOCOM1:		EQU	$45		; RS232 Command or Read status
IOCOM2:		EQU	$46		; RS232 Select Baud Rate

IORAM0:		EQU	$4E		; Expansion RAM off 
IORAM1:		EQU	$4F		; Expansion RAM on

IOROM0:		EQU	$80		; Select Coleco ROM 
IOROM1:		EQU	$88		; Select BASIC ROM 

IOVDP0:		EQU	$BE		; TMS9929A R/W data
IOVDP1:		EQU	$BF		; TMS9929A Control

IOTAP0:		EQU	$FB		; Audio out to tape
IOTAP1:		EQU	$FF		; Audio in from tape

IOPSG0:		EQU	$FF		; SN74689AN Sound control 

IOKEY0:		EQU	$F8		; Keyboard
IOKEY1:		EQU	$CF		; Keyboard

; ASCII Control Characters
BELL:		EQU	$07
BS:		EQU	$08
CR:		EQU	$0D
LF:		EQU	$0A
ESC:		EQU	$1B

