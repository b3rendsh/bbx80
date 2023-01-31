; ------------------------------------------------------------------------------
; BBX80 v1.0
; 
; This module contains the memory map and bootcode for the BASIC environment.
; Initialy it will be a CP/M program that is loaded in RAM at address $0100.
; ------------------------------------------------------------------------------

		INCLUDE	"BBX80.INC"
		INCLUDE	"BASIC.INC"

; ------------------
; *** Memory map ***
; ------------------

		SECTION BOOT			; Start / Page 0
		SECTION	BASIC			; BBC BASIC interpreter
		SECTION	BASICASM		; BBC BASIC inline assembler
		SECTION	CPMHOST			; CP/M routines
		SECTION	BBX80CON		; BBX80 console (ANSI Terminal)

		SECTION	BASICRAM		; BBC BASIC RAM variables (768 bytes)
		ORG	$3E00			; Align to 256 byte page
		;ALIGN	256
		SECTION BBX80VAR		; BBX80 Initialized variables
		SECTION	BBX80RAM		; BBX80 variables (dynamic)
		SECTION	BBX80FREE		; Remaining free internal RAM for user

; -------------------------------------------
; *** Boot the host machine / start basic ***
; -------------------------------------------

		SECTION	BOOT

		PUBLIC	bbx80Init
		PUBLIC	bbx80Exit
		PUBLIC	bbxNMIenable
		PUBLIC	bbxNMIdisable
		PUBLIC	bbxSetTime
		PUBLIC	bbxGetTime
		PUBLIC	bbxCOMDS

		; commands not implemented
		PUBLIC	bbxDrawLine
		PUBLIC	bbxGetPixel
		PUBLIC	bbxPlotPixel
		PUBLIC	bbxComSave
		PUBLIC	bbxComLoad
		PUBLIC	bbxClg
		PUBLIC	bbxPsgEnvelope
		PUBLIC	bbxDspMode
		PUBLIC	bbxPsgSound
		PUBLIC	bbxAdval
		PUBLIC	bbxGetDateTime
		PUBLIC	bbxSetDateTime

		; basic
		EXTERN	START
		EXTERN	PBCDL
		EXTERN	OSWRCH
		EXTERN	CRLF
		EXTERN SORRY

		; bbx80
		EXTERN	initConsole
		EXTERN	dspTell

		EXTERN	bbxNMIFLAG
		EXTERN	bbxSECONDS

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

RST_00:		JP	START
		DB	BBXVERSION,0
RST_08:		JP	CRLF	
		DB	BASVERSION,0
RST_10:		JP	dspTell
RST_18:		JP	OSWRCH
RST_20:		JP	bbxNMIstop
RST_28:		JP	bbxNMIstart
RST_30:		RET			; Not used
RST_38:		RET			; Not used (INTVEC)

; -----------------------------------------------------------------------------
; NMI - must start at address $066 when in ROM
; Not implemented (yet)
; todo: investigate rc2014 interrupt options
; -----------------------------------------------------------------------------
bbxNMI:		RETN

; Disable/enable NMI 
bbxNMIenable:	PUSH	AF
		XOR	A
		LD	(bbxNMIFLAG),A
		NOP				; todo: insert code to enable NMI
		POP	AF
		RET

bbxNMIdisable:	PUSH	AF
		LD	A,1
		LD	(bbxNMIFLAG),A
		NOP				; todo: insert code to disable NMI
		POP	AF
		RET				

; Stop/start the NMI routine
bbxNMIstop:	PUSH	HL
		LD	HL,bbxNMIFLAG
		INC	(HL)
		POP	HL
		RET

bbxNMIstart:	PUSH	AF
		LD	A,(bbxNMIFLAG)
		DEC	A
		LD	(bbxNMIFLAG),A
		JR	NZ, _endResetIrq
		NOP				; insert code to reset NMI IRQ flag
_endResetIrq:	POP	AF
		RET

; ------------------------------------------------------------------------------
; PUTIME - Set elapsed-time clock.
; Inputs: DEHL = time to load (seconds)
;
; todo: investigate timer implementation options
; ------------------------------------------------------------------------------
bbxSetTime:	CALL	bbxNMIdisable		; todo: irq or nmi?
		LD	(bbxSECONDS),HL
        	LD	(bbxSECONDS+2),DE
		JP	bbxNMIenable		; todo: irq or nmi?

; ------------------------------------------------------------------------------
; GETIME - Read elapsed-time clock.
; Outputs: DEHL = elapsed time (seconds)
;
; todo: investigate timer implementation options
; The actual time counter is not implemented yet so this routine will just return 
; the last set time.
; ------------------------------------------------------------------------------
bbxGetTime:	CALL	bbxNMIdisable		; todo: irq or nmi?
		LD	HL,(bbxSECONDS)
		LD	DE,(bbxSECONDS+2)
		JP	bbxNMIenable		; todo: irq or nmi?

; -----------------------------------------------------------------------------
; Initialize bbx80 environment
; -----------------------------------------------------------------------------
bbx80Init:	LD	HL,BBX80USER	; PAGE
		PUSH	HL

		; Initialize host (CP/M)
		CALL	initConsole	; Init ANSI Terminal 
		CALL	bbxHostInit	; Z-flag reset indicates autorun
		PUSH	DE		; HIMEM

		PUSH	AF
		JP	NZ,endCredits

		; Display credits
		CALL	dspTell
		DB	BBXEDITION,$20,BBXVERSION,CR,LF
		DB	"(C) 2023 H.J.Berends",CR,LF
		DB	"BBC BASIC (Z80) ",BASVERSION,CR,LF
		DB	"(C) 1987 R.T.Russell",CR,LF
		DB	0

		; Display free memory
		EX	DE,HL
		SBC	HL,DE
		DEC	HL			; BASIC will take 3 bytes
		DEC	HL
		DEC	HL
		CALL	PBCDL			; Print Number in HL
		CALL	dspTell
		DB	" Bytes free",CR,LF
		DB	CR,LF
		DB	0 
endCredits:	CALL	bbxNMIenable
		POP	AF			; Z-Flag
		POP	DE			; HIMEM
		POP	HL			; PAGE 
		RET

; -----------------------------------------------------------------------------
; Exit bbx80 environment
; -----------------------------------------------------------------------------
bbx80Exit:	CALL	bbxNMIdisable
		JP	bbxHostExit


; ------------------------------------------------------------------------------
; Not implemented
; ------------------------------------------------------------------------------
bbxDrawLine:
bbxGetPixel:
bbxPlotPixel:	
bbxComSave:
bbxComLoad:	RET

bbxClg:		EQU	SORRY
bbxPsgEnvelope:	EQU	SORRY
bbxDspMode:	EQU	SORRY
bbxPsgSound:	EQU	SORRY
bbxAdval:	EQU	SORRY
bbxGetDateTime:	EQU	SORRY
bbxSetDateTime:	EQU	SORRY

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

; -------------------------------
; *** RAM for BBX80 variables ***
; -------------------------------
		
		SECTION BBX80RAM

		PUBLIC	bbxGCOLOR
		PUBLIC	bbxGCURPOS

; Plot commands
bbxGCOLOR:	DB	0		; Graphics comamnds color 
bbxGCURPOS:	DW	0		; Graphics cursor X,Y (max 255,191)
bbxGCURPOSX:	EQU	bbxGCURPOS+0
bbxGCURPOSY:	EQU	bbxGCURPOS+1


; -----------------------------------
; *** Remaining free internal RAM ***
; -----------------------------------

		SECTION	BBX80FREE

BBX80USER:				
