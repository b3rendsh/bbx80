; ------------------------------------------------------------------------------
; BBX80 Console v1.0
; Copyright (C) 2023 H.J. Berends
;
; You can freely use, distribute or modify this program.
; It is provided freely and "as it is" in the hope that it will be useful, 
; but without any warranty of any kind, either expressed or implied.
; ------------------------------------------------------------------------------
; This module contains routines for the ANSI Terminal CP/M Edition.
; Some code was inspired by other BBC BASIC implementations.
; ------------------------------------------------------------------------------

		INCLUDE	"BBX80.INC"
	
		SECTION BBX80CON

		PUBLIC	bbxCls
	        PUBLIC  bbxSetCursor
		PUBLIC	bbxGetCursor
		PUBLIC	bbxDspChar
		PUBLIC	bbxDspPrompt
		PUBLIC	bbxGetLine
		PUBLIC	bbxSetColor
		PUBLIC	bbxGetKey

		PUBLIC	initConsole
		PUBLIC	dspStringA
		PUBLIC	dspStringB
		PUBLIC	dspString0
		PUBLIC	dspTell

		EXTERN	bbxNMIenable
		EXTERN	bbxNMIdisable

		EXTERN	OSRDCH
		EXTERN	FLAGS

		EXTERN	dosGetKey
		EXTERN	dosOutChar

; ------------------------------------------------------------------------------
; Command: CLS / CLG
; Clear screen and move cursor to pos 0,0
; Destroys: A,D,E,H,L,F
; ------------------------------------------------------------------------------
bbxCls:		CALL	dspEscape
		DB	"[H",0		; Home
		CALL	dspEscape
		DB	"[2J",0		; Clear Screen
		LD	DE,$0000	; curpos 0,0
		LD	(bbxCURPOS),DE
		RET

; -------------------------------------------
; PUTCSR - Move cursor to specified position.
;   Inputs: DE = horizontal position (LHS=0)
;           HL = vertical position (TOP=0)
; Destroys: A,D,E,H,L,F
; -------------------------------------------
bbxSetCursor:	PUSH	BC
		LD	A,ESC
		CALL	screenWrite
		LD	A,'['
		CALL	screenWrite
		LD	A,L
		LD	(bbxCURPOSY),A
		INC	A			; BASIC curpos starts at 0 and VT100 at 1
		CALL	dspNumA
		LD	A,';'
		CALL	screenWrite
		LD	A,E
		LD	(bbxCURPOSX),A
		INC	A			; "
		CALL	dspNumA
		LD	A,'H'
		CALL	screenWrite
		POP	BC

		RET

; -------------------------------------------
; GETCSR - Return cursor coordinates.
;  Outputs:  DE = X coordinate (POS)
;            HL = Y coordinate (VPOS)
; Destroys: A,D,E,H,L,F
; -------------------------------------------
bbxGetCursor:	PUSH	BC
		CALL	dspEscape
		DB	"[6n",0			; Get cursor report
		LD	HL,$0000
		CALL	getNextCode
		CP	ESC
		JR	NZ,_errGetCursor
		CALL	getNextCode
		CP	'['
		JR	NZ,_errGetCursor
		PUSH	HL
		CALL	getCurPos
		EX	DE,HL
		POP	HL
		JR	C,_errGetCursor
		DEC	DE			; BASIC curpos starts at 0 and VT100 at 1
		PUSH	DE
		CALL	getCurPos
		POP	DE
		EX	DE,HL
		JR	C,_errGetCursor
		DEC	DE			; " 
		JR	_endGetCursor
_errGetCursor:	LD	DE,$0000
_endGetCursor:	POP	BC
		RET

getNextCode:	PUSH	HL
		CALL	getKeyWait
		POP	HL
		RET

getCurPos:	CALL	getNextCode
		CP	';'
		RET	Z
		CP	'R'
		RET	Z
		SUB	'0'
		RET	C
		CP	10
		RET	NC
		LD	DE,HL
		ADD	HL,HL			; x 2
		RET	C
		ADD	HL,HL			; x 4
		RET	C
		ADD	HL,DE			; x 5
		RET	C
		ADD	HL,HL			; x 10
		RET	C
		LD	E,A
		LD	D,0
		ADD	HL,DE			; Shift in digit 
		RET	C
		JR	getCurPos

; -----------------------------------------------------
; initConsole: Initialize console
; The VDP should be initialized first by the OS
; -----------------------------------------------------
initConsole:	; Init variables
		LD	HL,V80_START		; Source
		LD	DE,V80_RAM		; Destination
		LD	BC,V80_END-V80_START	; Number of bytes to copy (calculated by assembler)
		LDIR				; Copy initial variable values to RAM

		; Init screen
		CALL	dspEscape
		DB	"[?7l",0		; No auto wrap around / scroll text
		; Get screen width
		LD	DE,$00FE		; Column 254
		LD	H,D			; Line 0
		LD	L,D
		CALL	bbxSetCursor		; Set cursor to far right column
		CALL	bbxGetCursor		; Get actual column
		LD	A,E
		INC	A
		CP	8			; Test for minimum screen width
		JR	C,_endColumn		; Keep default value
		LD	(bbxWIDTH),A		; Save width
_endColumn:	CALL	bbxCls
		RET

; ------------------------------------------------------------------------------
; Subroutine: Input a line on the console, terminated by CR
; Parameters: HL = pointer to text buffer (L > 0 is edit line)
; Returns:    A= CR or something else if ESC is pressed
; Init state: Auto wrap / scroll is turned off, max line length is 255
; (partly based on original OSLINE routine)
; ------------------------------------------------------------------------------
; HL = pointer to text bufer
; L = relative cursor / buffer position
; A = character
; B = repeat counter
; C = repeat flag / char
; All cursor positioning is forward/backward 1 character (with repeat B)
; Last position in line contains CR
; ------------------------------------------------------------------------------
bbxGetLine:	
IFDEF WRAPWAIT
		LD	A,(FLAGS)
		OR	00010000B		; Set input flag
		LD	(FLAGS),A
ENDIF
		LD	A,L
		LD	L,0
		LD	C,L			; Set repeat flag
		CP	L
		JR	Z,_repeatKey		; Buffer is empty
updateDsp:	LD	B,0			; Update screen
_update1:	LD	A,(HL)
		INC	B
		INC	HL
		CP	CR
		CALL	NZ,bbxDspChar
		JR	NZ,_update1
		LD	A,' '			; Char at curpos is a space
		CALL	bbxDspChar
		LD	A,BS			; Cursor left
_update2:	CALL	bbxDspChar		; Repeat char write B times
		DEC	HL
		DJNZ	_update2
_repeatKey:	LD	A,C
		DEC	B
		JR	Z,_limit
		OR	A			; Repeat key?
_limit:		CALL	Z,keyWait		; Wait for keyboard key pressed
		LD	C,A			; Save for repeat
		LD	A,(FLAGS)
		OR	A			; Test for escape
		LD	A,C
		JP	M,endLine		; Escape?
		CP	CR
		JR	Z,endLine		; Enter?
		OR	A
		CALL	NZ,keyPressed
		JR	_repeatKey

endLine:	LD	A,(HL)
		CALL	bbxDspChar		; Write rest of line
		INC	HL
		SUB	CR
		JR	NZ,endLine
		CALL	dspCRLF
IFDEF WRAPWAIT
		LD	A,(FLAGS)
		AND	11101111B		; Reset input flag
		LD	(FLAGS),A
ENDIF
		LD	A,C			; CR or ESC
		RET

; ------------------------------------------------------------------------------
; Wait for key press and handle repeat delay / key sound
; ------------------------------------------------------------------------------
keyWait:	LD	A,(bbxWIDTH)		; Set repeat to screen width
		LD	B,A
		CALL	OSRDCH			; wait for a key to be pressed
		LD	C,A

		; key sound
		LD	A,(bbxKEYS)
		OR	A
		JR	Z,_endKeySound
		NOP				; insert key sound here
_endKeySound:	LD	A,C			; restore saved key value
		RET

; -------------------------------------------
; Subroutine: process key pressed on keyboard
; -------------------------------------------
keyPressed:	CP	$20			; Control character?
		JR	C,keyControl
		CP	$80			; Ascii character?
		RET	NC
		LD	C,0			; Inhibit repeat
keyAscii:	LD	D,(HL)			; Printing Character
		LD	(HL),A
		INC	L
		JP	Z,wontGo		; Line to long
		CALL	bbxDspChar
		LD	A,CR
		CP	D			; Last char in buffer?
		RET	NZ
		LD	(HL),A
		RET

keyControl:	CP	CUU			; Cursor up
		JR	Z,keyLeft
		CP	CUD			; Cursor down
		JR	Z,keyRight
		LD	B,0			; Set Repeat to max 256
		CP	ERALEFT
		JR	Z,keyBS
		CP	ERARIGHT
		JR	Z,keyDelete
		CP	KHOME
		JR	Z,keyLeft
		CP	KEND
		JR	Z,keyRight
		LD	C,0			; Inhibit repeat
		CP	PECHO
		JP	Z,togglePrint
		CP	BS
		JR	Z,keyBS
		CP	CUB
		JR	Z,keyLeft
		CP	CUF
		JR	Z,keyRight
		CP	DEL
		JR	Z,keyDelete
		CP	INS
		JR	Z,keyInsert
		RET				; Unsupported key

keyRight:	LD	A,(HL)
		CP	CR
		JR	Z,stopRepeat
		JR	keyAscii

keyBS:		SCF				; BS = cursor left + delete
keyLeft:	INC	L
		DEC	L
		JR	Z,stopRepeat
		LD	A,BS
		PUSH	AF			; Save Carry flag value
		CALL	bbxDspChar
		POP	AF
		DEC	L
		RET 	NC
keyDelete:	LD	A,(HL)
		CP	CR
		JR	Z,stopRepeat
		LD	D,H
		LD	E,L
_delete1:	INC	DE
		LD	A,(DE)
		DEC	DE
		LD	(DE),A
		INC	DE
		CP	CR
		JR	NZ,_delete1
endDelete:	POP	DE			; Ditch return address
		JP	updateDsp

keyInsert:	LD	A,CR	
		CP	(HL)
		RET	Z
		LD	D,H
		LD	E,254
_insert1:	INC	DE
		LD	(DE),A
		DEC	DE
		LD	A,E
		CP	L
		DEC	DE
		LD	A,(DE)
		JR	NZ,_insert1
		LD	(HL),' '
		JR	endDelete

wontGo:		DEC	L
		LD	(HL),CR
		LD	A,BELL
		CALL	bbxDspChar		; BEEP!
stopRepeat:	LD	C,0			; Stop repeat
		RET

togglePrint:	LD	A,(FLAGS)		; Toggle echo to printer
		XOR	00000100B
		LD	(FLAGS),A
		RET

; -----------------------------------------------------------------------
; Subroutine: Display an ASCII character on the console
; Includes cursor position update / scrolling
; -----------------------------------------------------------------------
bbxDspChar:	PUSH	HL
		PUSH	AF
		PUSH	BC
		LD	HL,bbxCURPOS
		CP	BS			; Cursor left?
		JR	Z,dspBS
		CP	CR			; Enter?
		JR	Z,dspCR
		CP	' '			; Other control character?
		JR	C,screenWrite1
IFDEF WRAPWAIT
		LD	B,A			; Save char
		LD	A,(FLAGS)
		BIT	4,A			; Input mode?
		JR	NZ,_inputMode
		LD	A,(bbxWIDTH)
		DEC	A
		CP	(HL)			; Compare X position
		CALL	C,dspCRLF
		LD	A,B			; Restore char
		CALL	screenWrite
		INC	(HL)
		JR	endWrite		
_inputMode:	LD	A,B
ENDIF
		CALL	screenWrite
		INC	(HL)			; Increase X position
		LD	A,(bbxWIDTH)	
		CP	(HL)			; Compare X position
		CALL	Z,dspCRLF
		JR	endWrite

dspBS:		XOR	A
		CP	(HL)
		JR	Z,_reverseWrap
		DEC	(HL)
		LD	A,BS
		JR	screenWrite1

_reverseWrap:	LD	A,(bbxWIDTH)
		DEC	A
		LD	B,A			; Save width-1
		LD	(HL),A
		LD	A,ESC			; Cursor up
		CALL	screenWrite
		LD	A,'M'
		CALL	screenWrite
		LD	A,ESC			; Cursor right width-1 times
		CALL	screenWrite
		LD	A,'['
		CALL	screenWrite
		LD	A,B			; HL = Width-1
		CALL	dspNumA
		LD	A,'C'
		JR	screenWrite1

dspCR:		LD	(HL),0
		JR	screenWrite1

; -------------------------------------------------------------------------
; Subroutine: write character to the screen and move cursor 1 right.
; -------------------------------------------------------------------------
screenWrite:	PUSH	HL
		PUSH	AF
		PUSH	BC
screenWrite1:	PUSH	DE
		CALL	dosOutChar
		POP	DE
endWrite:	POP	BC
		POP	AF
		POP	HL
		RET

; ------------------------------------------------------------------------------
; Subroutine: Move cursor to start of next line
; ------------------------------------------------------------------------------
dspCRLF:	LD	A,CR
		CALL	bbxDspChar
		LD	A,LF
		CALL	bbxDspChar
		RET

; ------------------------------------------------------------------------------
; Subroutine: Display prompt, always start on a new line
; ------------------------------------------------------------------------------
bbxDspPrompt:	LD	A,(bbxCURPOSX)
		AND	A
		JR	Z,_pos0
		CALL	dspCRLF
_pos0:		LD	A,'>'
		JP	bbxDspChar

; ------------------------------------------------------------------------------
; Subroutine: display string
; Parameters: HL = address
; dspStringA - start with length
; dspStringB - length in register B
; dspString0 - string terminated by 0
; ------------------------------------------------------------------------------
dspStringA:	LD	A,(HL)
		LD	B,A
		AND	A		; Length = 0 ?
		RET	Z
		INC	HL
dspStringB:	LD	A,(HL)
		CALL	bbxDspChar
		INC	HL
		DJNZ	dspStringB
		RET

dspString0:	LD	A,(HL)
		INC	HL
		OR	A
		RET	Z
		CALL	bbxDspChar
		JR	dspString0

; ---------------------------------------------------------------------------
; dspNumA - routine to display a value in A in ascii characters
; N.B. similar to PBCDL routine but 8 bit and direct screen write
; ---------------------------------------------------------------------------
dspNumA:	LD	L,A
		LD	H,0
		LD	BC,-100
		CALL	num1
		LD	BC,-10
		CALL	num1
		LD	C,-01
num1:		LD	A,'0'-1
num2:		INC	A
		ADD	HL,BC
		JR	C,num2
		SBC	HL,BC
		CALL	screenWrite
		RET

; ------------------------------------------------------------------------------
; Subroutine: tell message (as in BBC BASIC TELL routine) 
; ------------------------------------------------------------------------------
dspTell:	EX	(SP),HL		; Get return address
		CALL	dspString0
		EX	(SP),HL
		RET

; ------------------------------------------------------------------------------
; Subroutine: display escape code
; ------------------------------------------------------------------------------
dspEscape:	EX	(SP),HL
		LD	A,ESC
		CALL	screenWrite
escCode:	LD	A,(HL)
		INC	HL
		OR	A
		JR	Z,escEnd
		CALL	screenWrite
		JR	escCode
escEnd:		EX	(SP),HL
		RET
; ------------------------------------------------------------------------------
; Subroutine: Set text color
; ------------------------------------------------------------------------------
bbxSetColor:	PUSH	BC
		LD	A,L
		AND	7
		BIT	7,L
		JP	Z,FGCLR
		ADD	10
FGCLR:  	ADD	30
		BIT	3,L
		JP	Z,OUTCLR
		ADD	60
OUTCLR:		LD	L,A
		LD	A,ESC
		CALL	screenWrite
		LD	A,'['
		CALL	screenWrite
		LD	A,L
		CALL	dspNumA
		LD	A,'m'
		CALL	screenWrite
		POP	BC
		RET

; ------------------------------------------------------------------------------
; Subroutine: Direct console I/O
; Return a key (char) without echoing if one is waiting; zero if none available.
; Process escape sequence for special keys
; ------------------------------------------------------------------------------
bbxGetKey:	CALL	dosGetKey
		CP	ESC
		RET	NZ
		CALL	getKeyWait
		CP	'['
		JR	NZ,_endEsc
		CALL	getKeyWait
		CP	'A'
		JR	Z,codeUp
		CP	'B'
		JR	Z,codeDown
		CP	'C'
		JR	Z,codeRight
		CP	'D'
		JR	Z,codeLeft
		CP	'1'
		JR	Z,codeHome
		CP	'2'
		JR	Z,codeInsert
		CP	'3'
		JR	Z,codeDelete
		CP	'4'
		JR	Z,codeEnd
_endEsc:	LD	A,ESC		; unsupported key code
		RET

codeUp:		LD	A,CUU
		RET
codeDown:	LD	A,CUD
		RET
codeRight:	LD	A,CUF
		RET
codeLeft:	LD	A,CUB
		RET

codeHome:	LD	A,KHOME
		JR	_keyEnd
codeInsert:	LD	A,INS
		JR	_keyEnd
codeDelete:	LD	A,DEL
		JR	_keyEnd
codeEnd:	LD	A,KEND
_keyEnd:	LD	(bbxKEYSAV),A
		CALL	getKeyWait
		CP	'~'
		JR	NZ,_endEsc
		LD	A,(bbxKEYSAV)
		RET

getKeyWait:	LD	HL,SPEED	; Wait time (< 0.3sec)
_keyWait:	PUSH	HL
		CALL	dosGetKey
		POP	HL
		OR	A
		RET	NZ		; Key pressed
		OR	H
		OR	L
		RET	Z		; Time-out
		DEC	HL
		JR	_keyWait

; -------------------
; *** Static Data ***
; -------------------

; Initial values RAM variables 
; This table must exactly match with the V80_RAM table below!

V80_START:	DB	$C9,$00,$00	; bbxNMIUSR
		DB	0		; bbxNMIFLAG
		DB	0		; bbxNMICOUNT
		DW	0,0		; bbxSECONDS
		DB	$FF		; bbxBUFLEN
		DB	COLUMNS		; bbxWIDTH
		DB	$F0		; bbxTXTCOLOR
		DB	0		; bbxINVCHAR
		DB	1		; bbxKEYS
V80_END:

; -------------------------------------------
; *** RAM for initialized BBX80 variables *** 
; -------------------------------------------

		SECTION	BBX80VAR

		PUBLIC	bbxNMIUSR
		PUBLIC	bbxNMIFLAG
		PUBLIC	bbxNMICOUNT
		PUBLIC	bbxSECONDS
		PUBLIC	bbxBUFLEN
		PUBLIC	bbxTXTCOLOR
		PUBLIC	bbxINVCHAR
		PUBLIC	bbxKEYS

V80_RAM:

; NMI variables
bbxNMIUSR:	DB	$C9,$00,$00	; NMI interrupt routine extension (executed at end of Vsync routine)
bbxNMIFLAG:	DB	0		; NMI Flag
bbxNMICOUNT:	DB	0		; NMI Counter
bbxSECONDS:	DW	0,0		; Elapsed seconds since boot (approx.)

; Variables for console i/o
bbxBUFLEN:	DB	$FF		; Set input buffer length to max 255 (Byte 256 reserved for CR)
bbxWIDTH:	DB	COLUMNS		; Screen width
bbxTXTCOLOR:	DB	$F0		; Text color ($F0 is white on transparant)
bbxINVCHAR:	DB	0		; Inverse character (inverse color)
bbxKEYS:	DB	1		; Keyboard click sound on or off

; -------------------------------
; *** RAM for BBX80 variables ***
; -------------------------------
		
		SECTION BBX80RAM

; Variables for console i/o
bbxCURPOS:	DW	0		; Cursor position X,Y (Y is not used)
bbxKEYSAV:	DB	0		; Save escape code

; Constants
bbxCURPOSX:	EQU	bbxCURPOS+0
bbxCURPOSY:	EQU	bbxCURPOS+1
