; ------------------------------------------------------------------------------
; BBX80 Include v1.0
;
; Definitions used in BBX80 and BASIC modules
; ------------------------------------------------------------------------------

; Version
DEFL BASVERSION = "V3.0"
DEFL BBXVERSION = "V1.0"
DEFL BBXEDITION = "MSX Edition"

; BASIC Directives
DEFINE	TITLESCREEN	; Credits in title screen
DEFINE	BBX80		; BBX80 modifications in the BASIC code

; Modules
DEFINE	INCDOS		; Include DOS (CP/M) functions
DEFINE	INCVDP		; Include graphics module
;DEFINE	INCPSG		; Include sound module
;DEFINE	INCSER		; Include serial file transfer module
;DEFINE	INCRTC		; Include realtime clock / timer module
;DEFINE	INCGPIO		; Include GPIO module (e.g. joystick ports)

; System settings
COLUMNS:	EQU	50		; Screen width
SPEED:		EQU	$600		; Processor speed indicator (Z80/3.6Mhz)

; Use TMS9918A video adapter
DEFINE TMS9918A
GCOLUMNS:	EQU	50		; Screen width in graphics mode
IOVDP0:		EQU	$98		; TMS9918A R/W data
IOVDP1:		EQU	$99		; TMS9918A Control

; CP/M Definitions
DEFINE MSXDOS				; Handle MSXDOS deviations from CP/M 2.2			
BDOS:		EQU	5
FCB:		EQU	5CH
DSKBUF:		EQU	80H
FCBSIZ:		EQU	128+36+2

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
