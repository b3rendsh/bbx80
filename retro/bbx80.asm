; ------------------------------------------------------------------------------
; BBX80 v1.1
; Copyright (C) 2024 H.J. Berends
;
; You can freely use, distribute or modify this program.
; It is provided freely and "as it is" in the hope that it will be useful, 
; but without any warranty of any kind, either expressed or implied.
; ------------------------------------------------------------------------------
; Memory map and bootcode and I/O routines for a Z80 CP/M host computer.
; This implementation requires a CP/M 2.2 compatible DOS.
; ------------------------------------------------------------------------------

		INCLUDE	"bbx80.inc"
		INCLUDE	"console.inc"

; ------------------
; *** Memory map ***
; ------------------

		SECTION BBX80		; Boot machine
		SECTION	BASIC		; BASIC interpreter
		SECTION	BASICASM	; BASIC inline assembler
		SECTION	CPMHOST		; CP/M routines
		SECTION BBX80LIB	; BBX80 library
		SECTION	STATIC1		; BASIC static variables data
		SECTION	STATIC2		; BBX80 static variables data

		SECTION	BASICRAM	; BASIC RAM variables (768 bytes)
		ORG	$4100		; Align to 256 byte page
		;ALIGN	256		; Exclude section doesn't work with align
		SECTION BASICVAR	; BASIC Initialized variables
		SECTION BBX80VAR	; BBX80 Initialized variables
		SECTION	BBX80RAM	; BBX80 variables (dynamic)
		SECTION	BBX80FREE	; Remaining free internal RAM for user


; -------------------------------------------
; *** Boot the host machine / start basic ***
; -------------------------------------------

		SECTION	BBX80

		PUBLIC	bbx80Init
		PUBLIC	bbxIRQenable
		PUBLIC	bbxIRQdisable
		PUBLIC	bbxIRQstart
		PUBLIC	bbxIRQstop
		PUBLIC	bbxCOMDS

IFDEF INCRTC
		PUBLIC	bbxSetTime
		PUBLIC	bbxGetTime
		PUBLIC	bbxGetDateTime
		PUBLIC	bbxSetDateTime
ENDIF

		; basic
		EXTERN	START
		EXTERN	PBCDL
		EXTERN	OSWRCH
		EXTERN	CRLF
		EXTERN	VAR1_START
		EXTERN	VAR1_RAM

		; bbx80
		EXTERN	initConsole
		EXTERN	bbxCls
		EXTERN	dspTell
		EXTERN	vdpInit
		EXTERN	IRQFLAG
		EXTERN	SECONDS

		; cp/m
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

; -----------------------------------------------------------------------------
; Enables/disables interrupts e.g. to prevent VDP I/O issues.
; Use stop/start variant for nested routines.
; -----------------------------------------------------------------------------

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
		JR	NZ, _endResetIrq
		EI
_endResetIrq:	POP	AF
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

		; Initialize screen
		CALL	initConsole
IFDEF INCVDP
		CALL	bbxIRQdisable
		CALL	vdpInit
		CALL	bbxCls
		CALL	bbxIRQenable
ELSE
		CALL	bbxCls
ENDIF

		; Initialize host (CP/M)
		CALL	bbxHostInit	; Z-flag reset indicates autorun
		PUSH	DE		; HIMEM

		PUSH	AF
		JP	NZ,endCredits

		; Display credits
		CALL	dspTell
		DB	"BBX80 BASIC ",BASVERSION,CR,LF
		DB	BBXEDITION,$20,BBXVERSION,CR,LF
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
		DB	" Bytes Free",CR,LF
		DB	CR,LF
		DB	0 
endCredits:	POP	AF			; Z-Flag
		POP	DE			; HIMEM
		LD	HL,BBX80USER		; PAGE
		RET

; -----------------------------------------------------------------------------
; Exit bbx80 environment
; -----------------------------------------------------------------------------
bbx80Exit:	EQU	bbxHostExit

; ------------------------------------------------------------------------------
; OS Commands / jump table
; ------------------------------------------------------------------------------
bbxCOMDS:	DEFM	"BY"
		DEFB	'E'+80H
		DEFW	bbx80Exit
		DEFM	"CP"
		DEFB	'M'+80H
		DEFW	bbx80Exit
		DEFM	"DI"
		DEFB	'R'+80H
		DEFW	bbxDosDir
		DEFM	"DRIV"
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
		DEFM	"RESE"
		DEFB	'T'+80H
		DEFW	bbxDosResDisk
		DEFM	"SAV"
		DEFB	'E'+80H
		DEFW	bbxHostBsave
		DEFM	"SPOO"
		DEFB	'L'+80H
		DEFW	bbxDosSpool
		DEFM	"TYP"
		DEFB	'E'+80H
		DEFW	bbxDosType
		DEFB	0FFH

; -----------------------------------------
; *** Retrocomputer customized routines *** 
; -----------------------------------------

IFDEF INCRTC
; ------------------------------------------------------------------------------
; PUTIME - Set elapsed-time clock.
; Inputs: DEHL = time to load (seconds)
; Implemented with HBIOS (V3.0 Compatible)
; ------------------------------------------------------------------------------
bbxSetTime:	LD	BC,$F9D1		; SYSSET SECONDS
		RST	08			; Call HBIOS
		RET

; ------------------------------------------------------------------------------
; GETIME - Read elapsed-time clock.
; Outputs: DEHL = elapsed time (seconds)
; Implemented with HBIOS (V3.0 Compatible)
; ------------------------------------------------------------------------------
bbxGetTime:	LD	BC,$F8D1		; SYSGET SECONDS
		RST	08			; Call HBIOS
		RET

; ------------------------------------------------------------------------------
; GETIMS / PUTIMS - Read/write date and/or time in BASIC TIME$ variable
; Not implemented
; ------------------------------------------------------------------------------

bbxGetDateTime:	EQU	SORRY
bbxSetDateTime:	EQU	SORRY

ENDIF

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
		DB	COLUMNS		; CONWIDTH	Screen width
		DB	$F0		; TXTCOLOR	Text color ($F0 is white on transparant)
		DB	0		; INVCHAR	Inverse character (inverse color)
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
		PUBLIC	CONWIDTH
		PUBLIC	TXTCOLOR
		PUBLIC	INVCHAR

VAR2_RAM:

IRQUSR:		DS	3		
IRQFLAG:	DS	1		
IRQCOUNT:	DS	1
SECONDS:	DS	4		
BUFLEN:		DS	1		
CONWIDTH:	DS	1
TXTCOLOR:	DS	1		
INVCHAR:	DS	1		

; -----------------------------------
; *** Remaining free internal RAM ***
; -----------------------------------

		SECTION	BBX80FREE

BBX80USER:				
