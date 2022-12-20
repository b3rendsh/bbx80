; ------------------------------------------------------------------------------
; BASIC v1.0
; 
; This module contains a BBC BASIC Z80 wrapper for the BBX80 modules:
; + commands that are OS dependent (cmos).
; + commands that are hardware dependent (patch)
; + commands not implemented (sorry).
; + jump table and pointers to customize and extend BASIC.
; ------------------------------------------------------------------------------

		INCLUDE	"BBX80.INC"
		INCLUDE	"BASIC.INC"

		SECTION	BASIC

		PUBLIC	OSINIT
		PUBLIC	COLOUR
		PUBLIC	CLRSCN
		PUBLIC	PUTIME
		PUBLIC	GETIME
		PUBLIC	PUTCSR
		PUBLIC	GETCSR
		PUBLIC	CLG
		PUBLIC	GCOL
		PUBLIC	DRAW
		PUBLIC	MOVE
		PUBLIC	SORRY
		PUBLIC	CSAVE
		PUBLIC	CLOAD
		PUBLIC	TAPE_ERR

		EXTERN	EXTERR
		EXTERN	ESCAPE
		EXTERN	KEYWDS
		EXTERN	KEYWDL
		EXTERN	CMDTAB
		EXTERN	FUNTBL
		EXTERN	EXPRI
		EXTERN	XEQ
		EXTERN	COMMA
		EXTERN	BRAKET
		EXTERN	CLEAR
		EXTERN	WARM
		EXTERN	PAGE
		EXTERN	SETTOP
		EXTERN	TOP

		EXTERN	bbx80Init
		EXTERN	bbxGetLine
		EXTERN	bbxDspChar
		EXTERN	bbxDspPrompt
		EXTERN	bbxCls
		EXTERN	bbxSetTime
		EXTERN	bbxGetTime
		EXTERN	bbxSetCursor
		EXTERN	bbxGetCursor
		EXTERN	bbxKeysOff
		EXTERN	bbxKeysOn
	
		EXTERN	bbxDrawLine
		EXTERN	bbxSetColor
		EXTERN	bbxGetPixel
		EXTERN	bbxPlotPixel
		
		EXTERN	bbxComLoad
		EXTERN	bbxComSave

		EXTERN	bbxBUFPTR
		EXTERN	bbxTXTCOLOR
		EXTERN	bbxGCOLOR
		EXTERN	bbxGCURPOS

		EXTERN	BYE_3FB1
		EXTERN	BSAVE_1A90
		EXTERN	BLOAD_1C4B
		EXTERN	GETKEY_3330

; --------------------------
; *** OS Commands (cmos) ***
; --------------------------

; ------------------------------------------------------------------------------
; OSINIT - Initialise RAM mapping etc.
; Outputs: DE = initial value of HIMEM (top of RAM)
;          HL = initial value of PAGE (user program)
;          Z-flag reset indicates AUTO-RUN.
; ------------------------------------------------------------------------------
OSINIT:		; Init Branch
		LD	HL,VAR_START		; Source
		LD	DE,VAR_RAM		; Destination
		LD	BC,VAR_END-VAR_START	; Number of bytes to copy (calculated by assembler)
		LDIR				; Copy initial pointer table to RAM

		CALL	bbx80Init		; Init host and console
		XOR	A			; Set Z-flag (no autorun)
		RET

; --------------------------------------------------------
; OSRDCH - Read from the current input stream (keyboard).
; Outputs: A = character
; --------------------------------------------------------
JP_OSRDCH:	PUSH	HL
        	SBC	HL,HL           ;HL=0
        	CALL	OSKEY
        	POP	HL
        	RET	C
        	JR	JP_OSRDCH

; -----------------------------------------------------------------
; PROMPT - Display the prompt 
; It can no longer be assumed that OSWRCH follows right after this.
; -----------------------------------------------------------------
JP_PROMPT:	EQU	bbxDspPrompt

; --------------------------------------------------------
; OSWRCH - Write a character to console output.
; Inputs: A = character.
; --------------------------------------------------------

JP_OSWRCH:	EQU	bbxDspChar	

; --------------------------------------------------------
; OSLINE - Read/edit a complete line, terminated by CR.
;  Inputs: HL addresses destination buffer (L=0)
; Outputs: Buffer filled, terminated by CR.
;          A=0 
; --------------------------------------------------------

JP_OSLINE:	LD	(bbxBUFPTR),HL
		CALL	bbxGetLine
		XOR	A
		RET

; --------------------------------------------------------
; OSSAVE - Save an area of memory to a file.
; Inputs: HL = addresses filename (term CR)
;         DE = start address of data to save
;         BC = length of data to save (bytes)
; --------------------------------------------------------
JP_OSSAVE:	EXX
		PUSH	BC
		PUSH	DE
		PUSH	HL
		EXX
		CALL	BSAVE_1A90
		JR	POP_EXX

; --------------------------------------------------------
; OSLOAD - Load an area of memory from a file.
;  Inputs: HL addresses filename (term CR)
;           DE = address at which to load
;           BC = maximum allowed size (bytes)
; Outputs: Carry reset indicates no room for file.
; --------------------------------------------------------
JP_OSLOAD:	EXX
		PUSH	BC
		PUSH	DE
		PUSH	HL
		EXX
		CALL	BLOAD_1C4B
		SCF			; the part of the file up to max size is loaded.

POP_EXX:	EXX
		POP	HL
		POP	DE
		POP	BC
		EXX
		RET

TAPE_ERR:	LD	A,202		; "Device fault"
		CALL	EXTERR
		DEFM	"Tape error"
		DB	0
		
; --------------------------------------------------------
; OSCLI - Process an "operating system" command
; minimized the code: no check for spaces, caps or abbr.
; --------------------------------------------------------
JP_OSCLI:	EX	DE,HL
		LD	HL,(PT_COMDS)
OSCLI0:		LD	A,(DE)
		CP	(HL)
		JR	Z,OSCLI2
		JR	C,HUH		; commands must be in alphabetical order
OSCLI1:		BIT	7,(HL)
		INC	HL
		JR	Z,OSCLI1
		INC	HL
		INC	HL
		JR	OSCLI0
;
OSCLI2:		PUSH	DE
OSCLI3:		INC	DE
		INC	HL
		LD	A,(DE)
		XOR	(HL)
		JR	Z,OSCLI3
		CP	80H
		JR	Z,OSCLI4
		POP	DE
		JR	OSCLI1
;
OSCLI4:		POP	AF
		INC	DE
OSCLI5:		BIT	7,(HL)
		INC	HL
		JR	Z,OSCLI5
		LD	A,(HL)
		INC	HL
		LD	H,(HL)
		LD	L,A
		PUSH	HL
		EX	DE,HL
		RET

HUH:		LD	A,254
		CALL	EXTERR
		DEFM	"Bad command"
		DEFB	0 

; --------------------------------------------------------
; OSKEY - Read key with time-limit. ESC not implemented.
; Main function is carried out in user patch.
;  Inputs: HL = time limit (centiseconds)
; Outputs: Carry reset if time-out
;          If carry set A = character
; --------------------------------------------------------
JP_OSKEY:	DEC	HL 
		LD	A,H
		OR	L
		RET	Z
		CALL	GETKEY_3330
		JR	Z,JP_OSKEY
		CP	ESC
		SCF
		RET	NZ
ESCSET:		PUSH	HL
		LD	HL,FLAGS
		SET	7,(HL)		; Set escape flag
		POP	HL
		RET

; --------------------------------------------------------
; TRAP - Test ESCAPE flag and abort if set
;        every 20th call, test for keypress.
;
; LTRAP - Test ESCAPE flag and abort if set.
; --------------------------------------------------------
JP_TRAP:	LD	HL,TRPCNT
		DEC	(HL)
		CALL	Z,TEST20	; Test keyboard
JP_LTRAP:	LD	A,(FLAGS)	; Escape flags
		OR	A		; Test
		RET	P
		LD	HL,FLAGS	; Acknowledge escape and abort
		RES	7,(HL)
		JP	ESCAPE	

; --------------------------------------------------------
; TEST - Sample for ESC key. If pressed set flag and return
; --------------------------------------------------------
TEST20:		LD	(HL),20
		CALL	GETKEY_3330
		RET	NC
		CP	ESC
		JR	Z,ESCSET
		RET

; ------------------------------
; *** OS Custom Commands ***
; ------------------------------

; --------------------------------------------------------
; CLOAD - Load an area of memory from the serial port.
;  Inputs:  HL = address at which to load
;           DE = maximum allowed size (bytes)
; --------------------------------------------------------
CLOAD:		LD	DE,(PAGE)
		LD	HL,-256
		ADD	HL,SP
		SBC	HL,DE		;FIND AVAILABLE SPACE
		EX	DE,HL
		CALL	bbxComLoad
		CALL	CLEAR
		JP	WARM 
; --------------------------------------------------------
; CSAVE - Save an area of memory to the serial port.
;   Inputs: HL = start address of data to save
;           DE = length of data to save (bytes)
; --------------------------------------------------------
CSAVE:		CALL	SETTOP		;SET TOP
		LD	DE,(PAGE)
		LD	HL,(TOP)
		OR	A
		SBC	HL,DE
		EX	DE,HL
		CALL	bbxComSave
		JP	WARM


; --------------------------------------------------------
; Keyboard click sound on/off
; --------------------------------------------------------
KEYSON:		EQU	bbxKeysOn
KEYSOFF:	EQU	bbxKeysOff


; ------------------------------
; *** BASIC Commands (patch) ***
; ------------------------------

; ------------------------------------------------------------------------------
; COLOUR and GCOL
; Set the textcolor or graphics color
; ------------------------------------------------------------------------------
COLOUR:		LD	DE,bbxTXTCOLOR
		JR	setColor

GCOL:		LD	DE,bbxGCOLOR
setColor:	PUSH	DE			; EXPRI routine may destroy DE 
		CALL	EXPRI
		EXX
		POP	DE
		CALL	bbxSetColor
		JP	XEQ


; ------------------------------------------------------------------------------
; Plotting commands
; ------------------------------------------------------------------------------
JP_PLOT:	CALL	paramPlotXY
		CALL	bbxPlotPixel
		LD	(bbxGCURPOS),DE
		JP	XEQ

JP_POINT:	CALL	paramPlotXY
		CALL	bbxGetPixel
		JR	Z,_point1
		LD	A,1
_point1:	LD	L,A
		LD	H,0
		EXX
		XOR	A
		LD	C,A		;Integer marker
		LD	H,A
		LD	L,A
		JP	BRAKET

DRAW:		CALL	paramPlotXY	; D=y1, E=x1 (end)
		LD	HL,(bbxGCURPOS)	; H=y0, L=x0 (start)
		PUSH	DE
		CALL	bbxDrawLine
		POP	DE
		LD	(bbxGCURPOS),DE
		JP	XEQ

MOVE:		CALL	paramPlotXY
		LD	(bbxGCURPOS),DE
		JP	XEQ

paramPlotXY:	CALL	EXPRI
		EXX
		PUSH	HL
		CALL	COMMA
		CALL	EXPRI
		EXX
		LD	A,L
		CP	$C0
		JR	C,_moveY
		LD	A,$BF			; Max Y value
_moveY:		POP	DE
		LD	D,A
		RET
; -----------------------------------------------------------------------------

CLRSCN:		EQU	bbxCls
CLG:		EQU	bbxCls
PUTIME:		EQU	bbxSetTime
GETIME:		EQU	bbxGetTime
PUTCSR:		EQU	bbxSetCursor
GETCSR:		EQU	bbxGetCursor

; ----------------------------------------
; *** Commands not implemented (sorry) ***
; ----------------------------------------
SORRY:
JP_ENVEL:
JP_MODE:
JP_SOUND:
JP_ADVAL:
JP_GETIMS:
JP_PUTIMS: 
	        XOR     A
        	CALL    EXTERR
        	DEFM    "Sorry"
        	DEFB    0


; -------------------
; *** Static Data ***
; -------------------

; Initial values RAM variables 
; This table must exactly match with the VAR_RAM table below!
VAR_START:	DW	KEYWDS
		DW	KEYWDL
		DW	CMDTAB
		DW	FUNTBL
		DW	COMDS
		
		JP	JP_OSRDCH
		JP	JP_PROMPT
		JP	JP_OSWRCH
		JP	JP_OSLINE
		JP	JP_OSSAVE
		JP	JP_OSLOAD
		JP	JP_OSCLI
		JP	JP_OSKEY
		JP	JP_LTRAP
		JP	JP_TRAP

		DB	$C9,$00,$00	; OSOPEN
		DB	$C9,$00,$00	; OSSHUT
		DB	$C9,$00,$00	; OSBGET
		DB	$C9,$00,$00	; OSBPUT
		DB	$C9,$00,$00	; OSSTAT
		DB	$C9,$00,$00	; GETEXT
		DB	$C9,$00,$00	; GETPTR
		DB	$C9,$00,$00	; PUTPTR
		DB	$C9,$00,$00	; RESET
	 	DB	$C9,$00,$00	; OSCALL

		JP	JP_PLOT
		JP	JP_POINT

		JP	JP_ENVEL
		JP	JP_MODE
		JP	JP_SOUND
		JP	JP_ADVAL
		JP	JP_GETIMS
		JP	JP_PUTIMS

		DB	0		; FLAGS
		DB	0		; TRPCNT
VAR_END:

; OS Commands
COMDS:		DEFM	"BY"
		DEFB	'E'+80H
		DEFW	BYE_3FB1
		DEFM	"CLOA"
		DEFB	'D'+80H
		DEFW	CLOAD
		DEFM	"CSAV"
		DEFB	'E'+80H
		DEFW	CSAVE
		DEFM	"KEYSOF"
		DEFB	'F'+80H
		DEFW	KEYSOFF
		DEFM	"KEYSO"
		DEFB	'N'+80H
		DEFW	KEYSON
		DEFB	0FFH

; ------------------------------------------------------------------
; *** BASIC pointers, vectors and variables that are initialized ***
; ------------------------------------------------------------------

		SECTION	BBX80VAR

		PUBLIC 	PT_KEYWDS
		PUBLIC	PT_KEYWDL
		PUBLIC	PT_CMDTAB
		PUBLIC	PT_FUNTBL

		PUBLIC	OSRDCH
		PUBLIC	PROMPT
		PUBLIC	OSWRCH
		PUBLIC	OSLINE
		PUBLIC	OSSAVE
		PUBLIC	OSLOAD
		PUBLIC	OSCLI
		PUBLIC	OSKEY
		PUBLIC	LTRAP
		PUBLIC	TRAP

		PUBLIC	OSOPEN
		PUBLIC	OSSHUT
		PUBLIC	OSBGET
		PUBLIC	OSBPUT
		PUBLIC	OSSTAT
		PUBLIC	GETEXT
		PUBLIC	GETPTR
		PUBLIC	PUTPTR
		PUBLIC	RESET
		PUBLIC	OSCALL 

		PUBLIC	PLOT
		PUBLIC	POINT

		PUBLIC	ENVEL
		PUBLIC	MODE
		PUBLIC	SOUND
		PUBLIC	ADVAL
		PUBLIC	GETIMS
		PUBLIC	PUTIMS 

		EXTERN	KEYWDS
		EXTERN	KEYWDL
		EXTERN	CMDTAB
		EXTERN	FUNTBL


; This table must exactly match with the VAR_START to VAR_END table above!
VAR_RAM:

PT_KEYWDS:	DW	KEYWDS		; BASIC Keywords token table
PT_KEYWDL:	DW	KEYWDL		; BASIC Keywords table size
PT_CMDTAB:	DW	CMDTAB		; BASIC Commands jump table
PT_FUNTBL:	DW	FUNTBL		; BASIC Functions jump table 
PT_COMDS:	DW	COMDS		; OS Commands keywords+jump table (sort ascending on keyword)


; Commands that can be redefined in an add-on module without having to duplicate the token tables:

; OS Comamnds implemented
OSRDCH:		JP	JP_OSRDCH
PROMPT:		JP	JP_PROMPT
OSWRCH:		JP	JP_OSWRCH
OSLINE:		JP	JP_OSLINE
OSSAVE:		JP	JP_OSSAVE
OSLOAD:		JP	JP_OSLOAD
OSCLI:		JP	JP_OSCLI
OSKEY:		JP	JP_OSKEY
LTRAP:		JP	JP_LTRAP
TRAP:		JP	JP_TRAP

; OS Commands not implemented
OSOPEN:		DB	$C9,$00,$00	; JP	JP_OSOPEN
OSSHUT:		DB	$C9,$00,$00	; JP	JP_OSSHUT
OSBGET:		DB	$C9,$00,$00	; JP	JP_OSBGET
OSBPUT:		DB	$C9,$00,$00	; JP	JP_OSBPUT
OSSTAT:		DB	$C9,$00,$00	; JP	JP_OSSTAT
GETEXT:		DB	$C9,$00,$00	; JP	JP_GETEXT
GETPTR:		DB	$C9,$00,$00	; JP	JP_GETPTR
PUTPTR:		DB	$C9,$00,$00	; JP	JP_PUTPTR
RESET:		DB	$C9,$00,$00	; JP	JP_RESET
OSCALL: 	DB	$C9,$00,$00	; JP	JP_OSCALL

; BASIC Commands partially implemented
PLOT:		JP	JP_PLOT
POINT:		JP	JP_POINT

; BASIC Commands not implemented
ENVEL:		JP	JP_ENVEL
MODE:		JP	JP_MODE
SOUND:		JP	JP_SOUND
ADVAL:		JP	JP_ADVAL
GETIMS:		JP	JP_GETIMS
PUTIMS: 	JP	JP_PUTIMS

; BASIC Variables
FLAGS:		DB	0		; Flags for keyboard input i.e escape
TRPCNT:		DB	0		; Counter used in trap/ltrap routine
