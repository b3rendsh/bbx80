; ------------------------------------------------------------------------------
; BASIC v1.1
; 
; This module contains a BBC BASIC Z80 wrapper for the BBX80 modules:
; + commands that are OS dependent (cmos).
; + commands that are hardware dependent (patch)
; + commands not implemented (sorry).
; + jump table and pointers to customize and extend BASIC.
; + generic BASIC I/O functions
; ------------------------------------------------------------------------------

		SECTION	BASIC

		INCLUDE	"bbx80.inc"
		INCLUDE "console.inc"

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
		PUBLIC	CLOAD
		PUBLIC	CSAVE
		PUBLIC	UPPRC
		PUBLIC	SKIPSP
		PUBLIC	HUH
		PUBLIC	HEX
		PUBLIC	ABORT
		PUBLIC	VAR1_START

		; basic
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
		EXTERN	CLS
		EXTERN	ERRLIN

		; bbx80
		EXTERN	bbxCOMDS
		EXTERN	bbx80Init
		EXTERN	bbxCls
		EXTERN	bbxGetKey
		EXTERN	bbxGetLine
		EXTERN	bbxDspChar
		EXTERN	bbxDspPrompt
		EXTERN	bbxSetCursor
		EXTERN	bbxGetCursor
		EXTERN	bbxKeysOff
		EXTERN	bbxKeysOn
		EXTERN	bbxSetColor
		EXTERN	bbxHostSave
		EXTERN	bbxHostLoad
		
		EXTERN	TXTCOLOR
		EXTERN	GCOLOR
		EXTERN	GCURPOS
		EXTERN	SECONDS

		; optional modules
		GLOBAL	bbxSetTime
		GLOBAL	bbxGetTime
		GLOBAL	bbxGetDateTime
		GLOBAL	bbxSetDateTime

		GLOBAL	bbxClg
		GLOBAL	bbxDrawLine
		GLOBAL	bbxGetPixel
		GLOBAL	bbxPlotPixel
		GLOBAL	bbxSetGfxColor
		GLOBAL	bbxDspMode

		GLOBAL	bbxDosOpen
		GLOBAL	bbxDosBget
		GLOBAL	bbxDosBput
		GLOBAL	bbxDosStat
		GLOBAL	bbxDosGetext
		GLOBAL	bbxDosGetPtr
		GLOBAL	bbxDosPutPtr
		GLOBAL	bbxDosShut
		GLOBAL	bbxDosReset
		GLOBAL	bbxDosCall
		GLOBAL	bbxDosDot
		GLOBAL	bbxDosDir
		GLOBAL	bbxDosExecIn

		GLOBAL	bbxComLoad
		GLOBAL	bbxComSave

		GLOBAL	bbxPsgEnvelope
		GLOBAL	bbxPsgSound

		GLOBAL	bbxAdval


; --------------------------
; *** OS Commands (cmos) ***
; --------------------------

; --------------------------------------------------------
; OSRDCH - Read from the current input stream (keyboard).
; Outputs: A = character
; Destroys: A,F
; --------------------------------------------------------
BAS_OSRDCH:	
IFDEF INCDOS
		LD	A,(FLAGS)
		RRA				; *EXEC Active ?
		JP	C,bbxDosExecIn
ENDIF
		PUSH	HL
        	SBC	HL,HL           	; HL=0
        	CALL	OSKEY
        	POP	HL
        	RET	C
        	JR	BAS_OSRDCH

; --------------------------------------------------------
; OSWRCH - Write a character to console output.
; Inputs: A = character.
; Destroys: Nothing
; --------------------------------------------------------
BAS_OSWRCH:	PUSH	AF
		PUSH	DE
		PUSH	HL
		LD	E,A
		CALL	TEST
		LD	A,E
		CALL	EDPUT
		POP	HL
		POP	DE
		POP	AF
		RET

EDPUT:		LD	HL,FLAGS
		BIT	3,(HL)			; Edit mode?
		JP	Z,bbxDspChar
		CP	' '			; Printable char?
		RET	C
		LD	HL,(EDPTR)	
		LD	(HL),A			; Store char in edit buffer
		INC	L
		RET	Z
		LD	(EDPTR),HL
		RET

; --------------------------------------------------------
; OSLINE - Read/edit a complete line, terminated by CR.
;   Inputs: HL addresses destination buffer (L=0).
;  Outputs: Buffer filled, terminated by CR.
;           A=0.
; Destroys: A,B,C,D,E,H,L,F
; --------------------------------------------------------
BAS_OSLINE:	LD	A,(FLAGS)
		BIT	3,A			; Edit mode?
		JR	Z,OSLIN1
		RES	3,A
		LD	(FLAGS),A
		LD	HL,(EDPTR)
OSLIN1:		LD	A,CR
		LD	(HL),A
		CALL	bbxGetLine		; Returns CR or something else if ESC is pressed
		CP	CR
		JP	NZ,ABORT
		LD	DE,(ERRLIN)
		XOR	A
		LD	L,A
		LD	(EDPTR),HL
		CP	D
		RET	NZ
		CP	E
		RET	NZ
		LD	DE,EDITST
		LD	B,4
CMPARE:		EX	DE,HL
		LD	A,(DE)
		CALL	UPPRC			; Make upper case
		CP	(HL)
		LD	A,0
		EX	DE,HL
		RET	NZ
		INC	HL
		INC	DE
		LD	A,(HL)
		CP	'.'
		JR	Z,ABBR
		DJNZ	CMPARE
ABBR:		XOR	A
		LD	B,A
		LD	C,L
		LD	L,A
		LD	DE,LISTST
		EX	DE,HL
		LDIR
		LD	HL,FLAGS
		SET	3,(HL)
		RET

EDITST:		DEFM	"EDIT"
LISTST:		DEFM	"LIST"

; --------------------------------------------------------
; OSCLI - Process an "operating system" command
; --------------------------------------------------------
BAS_OSCLI:	CALL	SKIPSP
		CP	CR
		RET	Z
		CP	'|'
		RET	Z
		CP	'.'
		JP	Z,bbxDosDot		; *.
		EX	DE,HL
		LD	HL,(PT_COMDS)
OSCLI0:		LD	A,(DE)
		CALL	UPPRC
		CP	(HL)
		JR	Z,OSCLI2
		JR	C,HUH			; commands must be in alphabetical order
OSCLI1:		BIT	7,(HL)
		INC	HL
		JR	Z,OSCLI1
		INC	HL
		INC	HL
		JR	OSCLI0

OSCLI2:		PUSH	DE
OSCLI3:		INC	DE
		INC	HL
		LD	A,(DE)
		CALL	UPPRC
		CP	'.'			; Abbreviated?
		JR	Z,OSCLI4
		XOR	(HL)
		JR	Z,OSCLI3
		CP	80H
		JR	Z,OSCLI4
		POP	DE
		JR	OSCLI1

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
		JR	SKIPSP

; --------------------------------------------------------
; Bad command
; --------------------------------------------------------
HUH:		LD	A,254
		CALL	EXTERR
		DEFM	"Bad command"
		DEFB	0 

; --------------------------------------------------------
; Skip space(s)
; --------------------------------------------------------
SKIPSP:		LD	A,(HL)
		CP	' '
		RET	NZ
		INC	HL
		JR	SKIPSP

; --------------------------------------------------------
; Make upper case
; --------------------------------------------------------
UPPRC:		AND	7FH
		CP	'`'
		RET	C
		AND	5FH		; Convert to upper case
		RET

; --------------------------------------------------------
; HEX - Read a hex string and convert to binary.
;   Inputs: HL = text pointer
;  Outputs: HL = updated text pointer
;           DE = value
;            A = terminator (spaces skipped)
; Destroys: A,D,E,H,L,F
; --------------------------------------------------------
IFDEF INCDOS
HEX:		LD	DE,0		;INITIALISE
		CALL	SKIPSP
HEX1:		LD	A,(HL)
		CALL	UPPRC
		CP	'0'
		JR	C,SKIPSP
		CP	'9'+1
		JR	C,HEX2
		CP	'A'
		JR	C,SKIPSP
		CP	'F'+1
		JR	NC,SKIPSP
		SUB	7
HEX2:		AND	0FH
		EX	DE,HL
		ADD	HL,HL
		ADD	HL,HL
		ADD	HL,HL
		ADD	HL,HL
		EX	DE,HL
		OR	E
		LD	E,A
		INC	HL
		JR	HEX1
ELSE
HEX:		EQU	STUB
ENDIF

; --------------------------------------------------------
; OSKEY - Read key with time-limit. test for ESCape.
; Main function is carried out in user patch.
;  Inputs: HL = time limit (counter)
; Outputs: Carry reset if time-out
;          If carry set A = character
; --------------------------------------------------------
BAS_OSKEY:	PUSH	HL
		LD	HL,INKEY
		LD	A,(HL)
		LD	(HL),0
		POP	HL
		OR	A
		SCF
		RET	NZ
GETKEY:		CALL	bbxGetKey
		OR	A
		JR	NZ,TEST4ESC
		LD	A,H
		OR	L
		RET	Z
		DEC	HL 
		JR	GETKEY
TEST4ESC:	CP	ESC
		SCF
		RET	NZ
ESCSET:		PUSH	HL
		LD	HL,FLAGS
		BIT	6,(HL)		;ESC DISABLED?
		JR	NZ,ESCDIS
		SET	7,(HL)		;SET ESCAPE FLAG
ESCDIS:		POP	HL
		RET

; --------------------------------------------------------
; TRAP - Test ESCAPE flag and abort if set
;        every 20th call, test for keypress.
; Destroys: A,H,L,F
;
; LTRAP - Test ESCAPE flag and abort if set.
; Destroys: A,F
; --------------------------------------------------------
BAS_TRAP:	LD	HL,TRPCNT
		DEC	(HL)
		CALL	Z,TEST20	; Test keyboard
BAS_LTRAP:	LD	A,(FLAGS)	; Escape flags
		OR	A		; Test
		RET	P
ABORT:		LD	HL,FLAGS	; Acknowledge escape and abort
		RES	7,(HL)
		JP	ESCAPE	

; --------------------------------------------------------
; TEST - Sample for ESC key. If pressed set flag and return
; Destroys: A,F
; --------------------------------------------------------
TEST20:		LD	(HL),20
TEST:		PUSH	DE
		CALL	bbxGetKey
		POP	DE
		OR	A
		RET	Z
		CP	KSCROLL		; Pause display?
		JR	Z,PAUSE
		CP	ESC
		JR	Z,ESCSET
		LD	(INKEY),A
		RET

PAUSE:		CALL	bbxGetKey
		CP	ESC		; Escape also ends pause
		JR	Z,ESCSET
		CP	KCONT		; Continue?
		JR	NZ,PAUSE
		RET
; --------------------------
; *** Custom OS Commands ***
; --------------------------

; --------------------------------------------------------
; CLOAD - Load an area of memory from the serial port.
; HL = address at which to load
; DE = maximum allowed size (bytes)
; --------------------------------------------------------
CLOAD:		LD	DE,(PAGE)
		LD	HL,-256
		ADD	HL,SP
		SBC	HL,DE		; Find available space
		EX	DE,HL
		CALL	bbxComLoad
		CALL	CLEAR
		JP	WARM 
; --------------------------------------------------------
; CSAVE - Save an area of memory to the serial port.
; HL = start address of data to save
; DE = length of data to save (bytes)
; --------------------------------------------------------
CSAVE:		CALL	SETTOP		; Set TOP
		LD	DE,(PAGE)
		LD	HL,(TOP)
		OR	A
		SBC	HL,DE
		EX	DE,HL
		CALL	bbxComSave
		JP	WARM

; ------------------------------
; *** BASIC Commands (patch) ***
; ------------------------------

; ------------------------------------------------------------------------------
; COLOUR
; Set the textcolor or graphics color
; ------------------------------------------------------------------------------
COLOUR:		CALL	EXPRI
		EXX
		LD	DE,TXTCOLOR
		CALL	bbxSetColor
		JP	XEQ

; ------------------------------------------------------------------------------
; Graphics commands
; ------------------------------------------------------------------------------

IFDEF INCVDP
GCOL:		CALL	EXPRI
		EXX
		LD	DE,GCOLOR
		CALL	bbxSetGfxColor
		JP	XEQ

BAS_PLOT:	CALL	paramPlotXY
		CALL	bbxPlotPixel
		LD	(GCURPOS),DE
		JP	XEQ

BAS_POINT:	CALL	paramPlotXY
		CALL	bbxGetPixel
		JR	Z,_point1
		LD	A,1
_point1:	LD	L,A
		LD	H,0
		EXX
		XOR	A
		LD	C,A			;Integer marker
		LD	H,A
		LD	L,A
		JP	BRAKET

DRAW:		CALL	paramPlotXY		; D=y1, E=x1 (end)
		LD	HL,(GCURPOS)		; H=y0, L=x0 (start)
		PUSH	DE
		CALL	bbxDrawLine
		POP	DE
		LD	(GCURPOS),DE
		JP	XEQ

MOVE:		CALL	paramPlotXY
		LD	(GCURPOS),DE
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

ELSE
GCOL:		EQU	SORRY
BAS_PLOT:	EQU	SORRY
BAS_POINT:	EQU	SORRY
DRAW:		EQU	SORRY
MOVE:		EQU	SORRY
bbxDspMode:	EQU	SORRY
bbxClg:		EQU	SORRY

ENDIF

; -----------------------------------------------------------------------------
; Label translatations
; -----------------------------------------------------------------------------

OSINIT:		EQU	bbx80Init
CLRSCN:		EQU	bbxCls
IFNDEF BIT90
CLG:		CALL	bbxClg
		JP	XEQ
ELSE
CLG:		EQU	CLS
ENDIF
PUTIME:		EQU	bbxSetTime
GETIME:		EQU	bbxGetTime
PUTCSR:		EQU	bbxSetCursor
GETCSR:		EQU	bbxGetCursor

; ----------------------------------------
; *** Commands not implemented (sorry) ***
; ----------------------------------------
SORRY:	        XOR     A
        	CALL    EXTERR
        	DEFM    "Sorry"
        	DEFB    0

STUB:		RET

IFNDEF INCRTC
bbxSetTime:	LD	(SECONDS),HL
        	LD	(SECONDS+2),DE
		RET
bbxGetTime:	LD	HL,(SECONDS)
		LD	DE,(SECONDS+2)
		RET
bbxGetDateTime:	EQU	SORRY
bbxSetDateTime:	EQU	SORRY
ENDIF

IFNDEF INCGPIO
bbxAdval:	EQU	SORRY
ENDIF

IFNDEF INCDOS
bbxDosOpen:	EQU	STUB
bbxDosShut:	EQU	STUB
bbxDosBget:	EQU	STUB
bbxDosBput:	EQU	STUB
bbxDosStat:	EQU	STUB
bbxDosGetext:	EQU	STUB
bbxDosGetPtr:	EQU	STUB
bbxDosPutPtr:	EQU	STUB
bbxDosReset:	EQU	STUB
bbxDosCall:	EQU	STUB
bbxDosDot:	EQU	STUB
bbxDosDir:	EQU	STUB
bbxDosExecIn:	EQU	STUB
ENDIF

IFNDEF INCSER
bbxComSave:	EQU	STUB
bbxComLoad:	EQU	STUB
ENDIF

IFNDEF INCPSG
bbxPsgEnvelope:	EQU	SORRY
bbxPsgSound:	EQU	SORRY
ENDIF

; --------------------------
; *** Static Data 1 of 2 ***
; --------------------------

		SECTION	STATIC1

; Initial values RAM variables 
; This table must exactly match with the VAR1_RAM table below!

VAR1_START:	; Tokens, keywords and jump tables
		DW	KEYWDS		; BASIC Keywords token table
		DW	KEYWDL		; BASIC Keywords table size
		DW	CMDTAB		; BASIC Commands jump table
		DW	FUNTBL		; BASIC Functions jump table 
		DW	bbxCOMDS	; OS Commands keywords+jump table (sort ascending on keyword)

		; Commands that can be redefined without having to duplicate the token tables:

		; OS Commands
		JP	BAS_OSRDCH
		JP	bbxDspPrompt
		JP	BAS_OSWRCH
		JP	BAS_OSLINE
		JP	bbxHostSave
		JP	bbxHostLoad
		JP	BAS_OSCLI
		JP	BAS_OSKEY
		JP	BAS_LTRAP
		JP	BAS_TRAP

		; DOS Commands
		JP	bbxDosOpen
		JP	bbxDosShut
		JP	bbxDosBget
		JP	bbxDosBput
		JP	bbxDosStat
		JP	bbxDosGetext
		JP	bbxDosGetPtr
		JP	bbxDosPutPtr
		JP	bbxDosReset
	 	JP	bbxDosCall

		; BASIC Commands
		JP	BAS_PLOT
		JP	BAS_POINT
		JP	bbxPsgEnvelope
		JP	bbxDspMode
		JP	bbxPsgSound
		JP	bbxAdval
		JP	bbxGetDateTime
		JP	bbxSetDateTime

		; Initialized BASIC Variables
		DB	0		; FLAGS		Bit 0:exec 1:spool 2:print 3:edit 4:input 5:- 6:esc off 7:esc
		DB	10		; TRPCNT	Counter used in trap/ltrap routine
		DB	0		; INKEY
		DW	0		; EDPTR

VAR1_END:	; The main BBX80 module contains more static data

; ------------------------------------------------------------------
; *** BASIC pointers, vectors and variables that are initialized ***
; ------------------------------------------------------------------

		SECTION	BASICVAR

		PUBLIC	VAR1_RAM

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

		PUBLIC	FLAGS
 
		EXTERN	KEYWDS
		EXTERN	KEYWDL
		EXTERN	CMDTAB
		EXTERN	FUNTBL


VAR1_RAM:

PT_KEYWDS:	DS	2
PT_KEYWDL:	DS	2
PT_CMDTAB:	DS	2
PT_FUNTBL:	DS	2
PT_COMDS:	DS	2

; OS Comamnds
OSRDCH:		DS	3
PROMPT:		DS	3
OSWRCH:		DS	3
OSLINE:		DS	3
OSSAVE:		DS	3
OSLOAD:		DS	3
OSCLI:		DS	3
OSKEY:		DS	3
LTRAP:		DS	3
TRAP:		DS	3

; DOS Commands
OSOPEN:		DS	3
OSSHUT:		DS	3
OSBGET:		DS	3
OSBPUT:		DS	3
OSSTAT:		DS	3
GETEXT:		DS	3
GETPTR:		DS	3
PUTPTR:		DS	3
RESET:		DS	3
OSCALL: 	DS	3

; BASIC Commands 
PLOT:		DS	3
POINT:		DS	3
ENVEL:		DS	3
MODE:		DS	3
SOUND:		DS	3
ADVAL:		DS	3
GETIMS:		DS	3
PUTIMS: 	DS	3

; BASIC Variables
FLAGS:		DS	1
TRPCNT:		DS	1		
INKEY:		DS	1
EDPTR:		DS	2

; The main BBX80 module contains more initialized variables
