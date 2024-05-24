; ------------------------------------------------------------------------------
; BBX80 Include v1.3
;
; Definitions used in BBX80 and BASIC modules
; ------------------------------------------------------------------------------

; Version
DEFL BASVERSION = "V3.0"
DEFL BBXVERSION = "V1.3"

; BASIC Directives
DEFINE	TITLESCREEN	; Credits in title screen
DEFINE	BBX80		; BBX80 modifications in the BASIC code

; Modules
;DEFINE	INCDOS		; Include DOS (CP/M) functions
DEFINE	INCVDP		; Include graphics module
;DEFINE	INCPSG		; Include sound module
DEFINE	INCSER		; Include serial file transfer module
DEFINE	INCRTC		; Include realtime clock / timer module
;DEFINE	INCGPIO		; Include GPIO module (e.g. joystick ports)


; System settings
VIDEOHZ:	EQU	50		; 60 for NTSC / 50 for PAL systems (used in timers)
COLUMNS:	EQU	50		; Screen width
SPEED:		EQU	$600		; Processor speed indicator (Z80/3.6Mhz)


;RST Routines
R_dspCRLF:	EQU	$08
R_dspTell:	EQU	$10
R_dspChar:	EQU	$18
R_IRQstop:	EQU	$20
R_IRQstart:	EQU	$28

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

; ------------------------------------------------------------------------------
; Global variables, defined in common/basic.asm

; BASIC routines 
GLOBAL	SORRY
GLOBAL	STUB

; BASIC variables
GLOBAL	PT_KEYWDS
GLOBAL	PT_KEYWDL
GLOBAL	PT_CMDTAB
GLOBAL	PT_FUNTBL
