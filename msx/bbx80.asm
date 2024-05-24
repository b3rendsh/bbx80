; ------------------------------------------------------------------------------
; BBX80 v1.0
; Copyright (C) 2024 H.J. Berends
;
; You can freely use, distribute or modify this program.
; It is provided freely and "as it is" in the hope that it will be useful, 
; but without any warranty of any kind, either expressed or implied.
; ------------------------------------------------------------------------------
; Memory map, bootcode and I/O routines for a MSX1 host computer.
; This implementation requires MSXDOS 1.0 or higher (CP/M 2.2 compatible).
; ------------------------------------------------------------------------------

		INCLUDE	"bbx80.inc"
		INCLUDE	"console.inc"

; ------------------
; *** Memory map ***
; ------------------

		SECTION BBX80		; Boot machine and console routines
		SECTION	BASIC		; BBC BASIC interpreter
		SECTION	BASICASM	; BBC BASIC inline assembler
		SECTION	MSXHOST		; MSX (BIOS) routines
		SECTION	CPMHOST		; CP/M (MSXDOS) routines
		SECTION BBX80LIB	; BBX80 library
		SECTION	STATIC1		; BASIC static variables data
		SECTION	STATIC2		; BBX80 static variables data

		SECTION	BASICRAM	; BBC BASIC RAM variables (768 bytes + 256 VDP buffer)
		ORG	$4300		; Align to 256 bytes page
		SECTION BASICVAR	; BASIC Initialized variables
		SECTION BBX80VAR	; BBX80 Initialized variables
		SECTION	BBX80RAM	; BBX80 variables (dynamic)
		SECTION	BBX80FREE	; Remaining free internal RAM for user


; -----------------------------------------------
; *** Boot the MSX host machine / start basic ***
; -----------------------------------------------

		SECTION	BBX80

		PUBLIC	bbx80Init
		PUBLIC	bbxIRQenable		
		PUBLIC	bbxIRQdisable
		PUBLIC	bbxIRQstart
		PUBLIC	bbxIRQstop
		PUBLIC	bbxCOMDS

		; MSX customization
		PUBLIC	bbxGetLine
		PUBLIC	bbxGetKey
		PUBLIC	bbxKeysOn
		PUBLIC	bbxKeysOff
		PUBLIC	bbxReleaseKey
		PUBLIC	bbxBell

		; basic
		EXTERN	START
		EXTERN	PBCDL
		EXTERN	OSWRCH
		EXTERN	OSKEY
		EXTERN	CRLF
		EXTERN	CLS
		EXTERN	FLAGS
		EXTERN	VAR1_START
		EXTERN	VAR1_RAM

		; msx
		EXTERN	msxKey
		EXTERN	msxSetCliksw
		EXTERN	msxInitText
		EXTERN	msxBeep

		; common
		EXTERN	bbxCls
		EXTERN	bbxDspChar
		EXTERN	dspTell
		EXTERN	dspCRLF
		EXTERN	dspCursor
		EXTERN	vdpInit
		EXTERN	FLSCUR
		EXTERN	FLSPEED

		; cp/m (msxdos)
		EXTERN	bbxHostInit
		EXTERN	bbxHostExit
		EXTERN	bbxDosDir
		EXTERN	bbxDosDrive
		EXTERN	bbxDosErase
		EXTERN	bbxDosRename
		EXTERN	bbxDosResDisk
		EXTERN	bbxDosEscCtl
		EXTERN	bbxDosExec
		EXTERN	bbxHostBload
		EXTERN	bbxHostBsave
		EXTERN	bbxDosOpt
		EXTERN	bbxDosSpool
		EXTERN	bbxDosType

; ------------------------------------------------------------------------------
; Bootcode for BBX80 as a CP/M application. 
; ------------------------------------------------------------------------------

		ORG	$0100		; start address for CP/M applications

		JP	START
		DB	BBXVERSION,0
		DB	BASVERSION,0

; ------------------------------------------------------------------------------
; Enables/disables interrupts e.g. to prevent VDP I/O issues.
; Use stop/start variant for nested routines.
; ------------------------------------------------------------------------------

; Disable/enable IRQ
bbxIRQenable:	PUSH	AF
		XOR	A
		LD	(IRQFLAG),A
		POP	AF
		EI
		RET

bbxIRQdisable:	DI
		PUSH	AF
		LD	A,1
		LD	(IRQFLAG),A
		POP	AF
		RET				

; Stop/start the IRQ routine
bbxIRQstop:	DI
		PUSH	HL	
		LD	HL,IRQFLAG
		INC	(HL)
		POP	HL
		RET

bbxIRQstart:	PUSH	AF
		LD	A,(IRQFLAG)
		DEC	A
		LD	(IRQFLAG),A
		JR	NZ, _endResetIRQ
		EI
_endResetIRQ:	POP	AF
		RET

; -----------------------------------------------------------------------------
; OSINIT - Initialise branch table and start bbx80 init
;  Outputs: DE = initial value of HIMEM (top of RAM)
;           HL = initial value of PAGE (user program)
;           Z-flag reset indicates AUTO-RUN.
; Destroys: A,B,C,D,E,H,L,F
; -----------------------------------------------------------------------------
bbx80Init:	; Init Branch table and Variables
		LD	HL,VAR1_START		; Source
		LD	DE,VAR1_RAM		; Destination
		LD	BC,VAR2_END-VAR1_START	; Number of bytes to copy
		LDIR				; Copy data

		; Initialize screen and IRQ handler
		CALL	bbxIRQdisable
		CALL	vdpInit
		CALL	bbxCls
		CALL	bbxIRQenable


		; Initialize host (CP/M)
		CALL	bbxHostInit		; Z-flag reset indicates autorun
		PUSH	DE			; HIMEM
		PUSH	AF
		JP	NZ,endCredits

		; Display credits
		CALL	dspTell
		DB	BBXEDITION,$20,BBXVERSION,CR,LF
		DB	"(C) 2024 H.J.Berends",CR,LF
		DB	"BBC BASIC (Z80) ",BASVERSION,CR,LF
		DB	"(C) 1987 R.T.Russell",CR,LF
		DB	0

		; Display free memory
		LD	HL,BBX80USER		; PAGE
		EX	DE,HL
		SBC	HL,DE			; HIMEM - PAGE
		DEC	HL			; BASIC will take 3 bytes
		DEC	HL
		DEC	HL
		CALL	PBCDL			; Print Number in HL
		CALL	dspTell
		DB	" Bytes free",CR,LF
		DB	CR,LF
		DB	0 
endCredits:	POP	AF			; Z-Flag
		POP	DE			; HIMEM
		LD	HL,BBX80USER		; PAGE
		RET

; -----------------------------------------------------------------------------
; Exit bbx80 environment
; -----------------------------------------------------------------------------
bbx80Exit:	CALL	bbxIRQenable
		CALL	msxInitText
		JP	bbxHostExit

; --------------------------------------------------------
; OS Commands / jump table (sort ascending on keyword)
; --------------------------------------------------------
bbxCOMDS:	DEFM	"BY"
		DEFB	'E'+80H
		DEFW	bbx80Exit
		DEFM	"DI"			; MSX: drive letter must be specificied e.g. *dir a:*.*
		DEFB	'R'+80H
		DEFW	bbxDosDir
		DEFM	"DRIV"			; MSX: not implemented (not compatible)
		DEFB	'E'+80H
		DEFW	bbxDosDrive
		DEFM	"ERAS"
		DEFB	'E'+80H
		DEFW	bbxDosErase
		DEFM	"ER"
		DEFB	'A'+80H
		DEFW	bbxDosErase
		DEFM	"ES"
		DEFB	'C'+80H
		DEFW	bbxDosEscCtl
		DEFM	"EXE"
		DEFB	'C'+80H
		DEFW	bbxDosExec
		DEFM	"KEYSOF"
		DEFB	'F'+80H
		DEFW	bbxKeysOff
		DEFM	"KEYSO"
		DEFB	'N'+80H
		DEFW	bbxKeysOn
		DEFM	"LOA"
		DEFB	'D'+80H
		DEFW	bbxHostBload
		DEFM	"OP"
		DEFB	'T'+80H
		DEFW	bbxDosOpt
		DEFM	"RENAM"
		DEFB	'E'+80H
		DEFW	bbxDosRename
		DEFM	"RE"
		DEFB	'N'+80H
		DEFW	bbxDosRename
		DEFM	"RESE"			; MSX: not implemented and not required
		DEFB	'T'+80H
		DEFW	bbxDosResDisk
		DEFM	"SAV"
		DEFB	'E'+80H
		DEFW	bbxHostBsave
		DEFM	"SPOO"
		DEFB	'L'+80H
		DEFW	bbxDosSpool
		DEFM	"SYSTE"			; equivalent of msx call system (replaces *cpm)
		DEFB	'M'+80H
		DEFW	bbx80Exit
		DEFM	"TYP"			; MSX: drive letter must be specified e.g. *type a:readme.txt
		DEFB	'E'+80H
		DEFW	bbxDosType
		DEFB	0FFH



; -------------------------------
; *** MSX customized routines *** 
; -------------------------------

; ------------------------------------------------------------------------------
; Subroutine: Input a line on the console, terminated by CR
; Parameters: HL = pointer to text buffer (L > 0 is edit line)
; Returns:    A = CR or something else if ESC is pressed
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
bbxGetLine:	LD	A,L
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

endLine:	CALL	bbxReleaseKey
_writeLine:	LD	A,(HL)
		CALL	bbxDspChar		; Write rest of line
		INC	HL
		SUB	CR
		JR	NZ,_writeLine
		CALL	dspCRLF
		LD	A,C			; Load last pressed key (CR or ESC)
		RET

; ------------------------------------------------------------------------------
; Wait for key press and handle repeat delay / key sound
; ------------------------------------------------------------------------------
keyWait:	LD	B,COLUMNS		; Set repeat to screen width
		PUSH	BC
		PUSH	HL
		LD	BC,(LASTKEY)
		OR	A			; Clear carry flag
		SBC	HL,HL			; HL=0
_repeatWait:	CALL	OSKEY			; Get keyboard key pressed
		JR	C,_validateKey
		LD	B,$60			; set time to wait for repeat
		LD	C,$00			; no key pressed
		CALL	dspCursor
		JR	_repeatWait

_validateKey:	CP	C
		JR	NZ,_endKey
		DJNZ	_repeatWait		; delay repeat key
		LD	B,$04			; set repeat speed
		LD	HL,FLSCUR
		SET	6,(HL)			; show cursor during repeat
		CALL	dspCursor

_endKey:	LD	C,A
		LD	(LASTKEY),BC		; save key / repeat counter

		LD	A,(CONKEYS)
		OR	A
		JR	Z,_endKeySound
		NOP				; use MSX BIOS for keyclick sound

_endKeySound:	LD	A,C			; restore saved key value
		POP	HL
		POP	BC
		RET


; -------------------------------------------
; Subroutine: process key pressed on keyboard
; -------------------------------------------
keyPressed:	PUSH	HL
		CALL	keyConversion
		POP	HL
		CP	$20			; Control character?
		JR	C,keyControl
		CP	$80			; Ascii character?
		RET	NC
		LD	C,0			; Inhibit repeat
keyAscii:	LD	D,(HL)			; Printing Character
		LD	(HL),A
		INC	L
		JR	Z,wontGo		; Line to long
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

; -----------------------------------------------------------------------
; Subroutine: Convert proprietary keycodes to standard code
; -----------------------------------------------------------------------

keyConversion:	LD	HL,CONVTAB
_repeatConv:	CP	(HL)
		JR	Z,_convertKey
		INC	HL
		INC	HL
		JR	NC,_repeatConv
		RET
_convertKey:	INC	HL
		LD	A,(HL)
		RET

; -----------------------------------------------------------------------
; Subroutine: Hide cursor and wait until all keys are released
; -----------------------------------------------------------------------
bbxReleaseKey:	PUSH	AF
		PUSH	HL
		LD	HL,FLSCUR
		RES	6,(HL)
		CALL	dspCursor
_releaseKey:	OR	A			; Clear carry flag
		SBC	HL,HL			; HL=0
		CALL	OSKEY			; Wait until all keys are released
		JR	C,_releaseKey
		POP	HL
		POP	AF
		RET

; -------------------------------------------------------------------------
; Subroutine: set keyboard click sound on or off
; -------------------------------------------------------------------------
bbxKeysOff:	PUSH	AF
		XOR	A
		JR	_setKeys
bbxKeysOn:	PUSH	AF
		LD	A,1
_setKeys:	LD	(CONKEYS),A
		CALL	msxSetCliksw		; set key click switch in BIOS
		POP	AF
		RET

; ------------------------------------------------------------------------------
; Subroutine: Direct console I/O
; Return a key (char) without echoing if one is waiting; zero if none available.
; Process escape sequence for special keys
; ------------------------------------------------------------------------------
bbxGetKey:	PUSH	BC
		PUSH	DE
		PUSH	HL
		LD	HL,FLSPEED
		LD	A,4			; Higher value will lower the flash speed
		CP	(HL)
		JR	C,_resFlspeed
		INC	(HL)
		JR	_endFlspeed
_resFlspeed:	XOR	A
		LD	(HL),A
		LD	HL,FLSCUR
		INC	(HL)
_endFlspeed:	CALL	msxKey
		CP	ESC
		CALL	Z,_processESC
		POP	HL
		POP	DE
		POP	BC
		RET

_processESC:	CALL	getKeyWait
		CP	'A'
		JR	Z,codeUp
		CP	'B'
		JR	Z,codeDown
		CP	'C'
		JR	Z,codeRight
		CP	'D'
		JR	Z,codeLeft
		CP	'H'
		JR	Z,codeHome
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
		RET

getKeyWait:	LD	HL,SPEED	; Wait time (< 0.3sec)
_keyWait:	PUSH	HL
		CALL	msxKey
		POP	HL
		OR	A
		RET	NZ		; Key pressed
		OR	H
		OR	L
		RET	Z		; Time-out
		DEC	HL
		JR	_keyWait

; Conversion table (sort ascending on keycode)
CONVTAB:	DB	$12,INS		; Insert
		DB	$1C,CUF		; Key right
		DB	$1D,CUB		; Key left
		DB	$1E,CUU		; Key up
		DB	$1F,CUD		; Key down
		DB	$7F,DEL		; Delete
		DB	$FF,$00		; End of table

; -----------------------------------------------------------------------
; Subroutine: output Bell
; -----------------------------------------------------------------------
bbxBell:	EQU	msxBeep


; --------------------------
; *** Static Data 2 of 2 ***
; --------------------------

		SECTION	STATIC2

		PUBLIC	VAR2_END

; Initial RAM variable values
; This table must exactly match with the VAR2_RAM table below!

VAR2_START:	DB	$C9,$00,$00	; IRQUSR	IRQ interrupt routine extension (executed at end of Vsync routine)
		DB	0		; IRQFLAG	IRQ Flag
		DB	0		; IRQCOUNT	IRQ Counter
		DW	0,0		; SECONDS	Elapsed seconds since boot (approx.)
		DB	$FF		; BUFLEN	Set input buffer length to max 255 (Byte 256 reserved for CR)
		DB	$18		; MAXLIN	Maximum linenumber + 1
		DB	$F0		; TXTCOLOR	Text color ($F0 is white on transparant)
		DB	0		; INVCHAR	Inverse character (inverse color)
		DB	1		; CONKEYS	Keyboard click sound on or off
		DW	0		; LASTKEY	Last key pressed / repeat counter
VAR2_END:

; -------------------------------------------
; *** RAM for initialized BBX80 variables *** 
; -------------------------------------------

		SECTION	BBX80VAR

		PUBLIC	IRQUSR
		PUBLIC	IRQFLAG
		PUBLIC	IRQCOUNT
		PUBLIC	SECONDS
		PUBLIC	BUFLEN
		PUBLIC	MAXLIN
		PUBLIC	TXTCOLOR
		PUBLIC	INVCHAR
		PUBLIC	CONKEYS

VAR2_RAM:

IRQUSR:		DS	3		
IRQFLAG:	DS	1		
IRQCOUNT:	DS	1
SECONDS:	DS	4		
BUFLEN:		DS	1		
MAXLIN:		DS	1		
TXTCOLOR:	DS	1		
INVCHAR:	DS	1		
CONKEYS:	DS	1		
LASTKEY:	DS	2

; -----------------------------------
; *** Remaining free internal RAM ***
; -----------------------------------

		SECTION	BBX80FREE

BBX80USER:				
