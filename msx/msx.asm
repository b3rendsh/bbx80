; ------------------------------------------------------------------------------
; BBX80 MSX HOST v1.1
; Copyright (C) 2026 H.J. Berends
;
; You can freely use, distribute or modify this program.
; It is provided freely and "as it is" in the hope that it will be useful, 
; but without any warranty of any kind, either expressed or implied.
; ------------------------------------------------------------------------------

		SECTION MSXHOST

		INCLUDE	"BBX80.INC"

		PUBLIC	msxKey
		PUBLIC	msxSetCliksw
		PUBLIC	msxInitText
		PUBLIC	msxBeep
		PUBLIC	msxTurbo
		PUBLIC	msxBIOS

; MSX constants and definitions
RDSLT		EQU	$000C
CALSLT		EQU	$001C
IDBYT0		EQU	$002B
INITXT		EQU	$006C
CHSNS   	EQU     $009C
CHGET		EQU	$009F
BEEP		EQU	$00C0
CHGCPU		EQU	$0180
CLIKSW		EQU	$F3DB
EXPTBL		EQU	$FCC1


; ------------------------------------------------------------------------------
; Use MSX BIOS keyboard input which is faster than via CP/M dosKey routine.
; ------------------------------------------------------------------------------
msxKey:		PUSH	IX
		LD	IX,CHSNS	; Test the status of the keyboard buffer
		CALL	msxBIOS
		JR	Z,_endKey	; Z = no key is pressed
		LD	IX,CHGET	; 
		CALL	msxBIOS
_endKey:	POP	IX
		RET

; ------------------------------------------------------------------------------
; Set keyboard click switch
; ------------------------------------------------------------------------------
msxSetCliksw:	AND	$01		; 0=Off 1=On
		LD	(CLIKSW),A
		RET

; ------------------------------------------------------------------------------
; Initialize text mode (screen 0), uses current screen width setting (LINL40)
; ------------------------------------------------------------------------------
msxInitText:	PUSH	IX
		LD	IX,INITXT
		CALL	msxBIOS
		POP	IX
		RET

; ------------------------------------------------------------------------------
; Output Bell / MSX Beep
; CHPUT BELL only works when the VDP is in text mode, use BIOS call instead
; ------------------------------------------------------------------------------
msxBeep:	PUSH	IX
		LD	IX,BEEP
		CALL	msxBIOS
		POP	IX
		RET

; ------------------------------------------------------------------------------
; Set processor turbo mode
; ------------------------------------------------------------------------------
msxTurbo:	PUSH	AF
		; routine to change cpu mode exists in BIOS?
		LD	HL,CHGCPU
		LD	A,(EXPTBL)
		CALL	RDSLT			
		EI				; RDSLT disables interrupts
		CP	$C3
		POP	HL
		RET	NZ			; nz=change cpu not supported, exit
		; change CPU:
		; bit 7   = switch LED
		; bit 0,1 = cpu mode: 00=z80 01=r800 rom 10=r800 dram 11=reserved
		LD	A,H
		AND	$83
		PUSH	IX
		LD	IX,CHGCPU
		CALL	msxBIOS
		POP	IX
		RET
		
; ------------------------------------------------------------------------------
; MSX BIOS routines, interslot call wrapper
; Parameters: 
;   IX = BIOS routine
; ------------------------------------------------------------------------------
msxBIOS:	PUSH 	IY
		LD	IY,(EXPTBL-1)		; BIOS slot in IYH

		; Save shadow registers
		EXX			
		PUSH	BC
		PUSH	DE
		PUSH	HL
		EXX

		CALL	CALSLT			; interslot call
		
		; Restore shadow registers
		EXX
		POP	HL
		POP	DE
		POP	BC
		EXX
		
		POP	IY
		RET

