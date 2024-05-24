; ------------------------------------------------------------------------------
; BBX80 Include v1.1
;
; Definitions used in BBX80 and BASIC modules
; ------------------------------------------------------------------------------

; Version
DEFL BASVERSION = "V3.0"
DEFL BBXVERSION = "V1.1"

; BASIC Directives
DEFINE	TITLESCREEN	; Credits in title screen
DEFINE	BBX80		; BBX80 modifications in the BASIC code

;Modules
DEFINE	INCDOS		; Include DOS (CP/M) functions

IFDEF BBX80A
DEFL BBXEDITION = "BBX80A VT100 Edition"
ENDIF

IFDEF BBX80B
DEFL BBXEDITION = "BBX80B Basic Edition"
DEFINE	INCVDP		; Include graphics module
ENDIF

IFDEF BBX80C
DEFL BBXEDITION = "BBX80C Advanced Edition"
DEFINE	INCVDP		; Include graphics module
DEFINE	INCRTC		; Include realtime clock / timer module
DEFINE	VT510		; VT510 extensions e.g.show/hide cursor 
ENDIF

IFDEF BBX80Z
DEFL BBXEDITION = "BBX80Z Ultimate Edition"
DEFINE	INCVDP		; Include graphics module
DEFINE	INCRTC		; Include realtime clock / timer module
;DEFINE	INCPSG		; Include sound module
;DEFINE	INCSER		; Include serial file transfer module
;DEFINE	INCGPIO		; Include GPIO module (e.g. joystick ports)

ENDIF

; System settings
COLUMNS:	EQU	80		; Screen width
SPEED:		EQU	$2000		; Processor speed indicator ($2000 for Z180/20Mhz)

; When at last column wait for line wrap until next char is printed unless in input mode
; set for vt100 compatibility
DEFINE WRAPWAIT

; Use PIGFX video adapter for graphics commands:
; https://github.com/fbergama/pigfx
;DEFINE PIGFX

; Use TMS9918A video adapter for graphics / text mode:
DEFINE TMS9918A
GCOLUMNS:	EQU	50		; Screen width in graphics mode
IOVDP0:		EQU	$40		; TMS9918A R/W data (Propeller graphics card)
IOVDP1:		EQU	$41		; TMS9918A Control (Propeller graphics card)


; CP/M Definitions
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
