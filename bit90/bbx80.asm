; ------------------------------------------------------------------------------
; BBX80 v1.3

; You can freely use, distribute or modify this program.
; It is provided freely and "as it is" in the hope that it will be useful, 
; but without any warranty of any kind, either expressed or implied.
; ------------------------------------------------------------------------------
; Memory map and bootcode for the BIT90 host computer.
; ------------------------------------------------------------------------------

		INCLUDE	"bbx80.inc"
		INCLUDE	"console.inc"

; ------------------
; *** Memory map ***
; ------------------

		;Define in makefile:
		;DEFINE	BBX80ROM		
		;DEFINE	BBX80CART

		SECTION BBX80			; Boot machine
		SECTION	BASIC			; BASIC interpreter
		SECTION	BASICASM		; BASIC inline assembler
		SECTION	BIT90HOST		; BIT90 host routines
		SECTION	BBX80CON		; BBX80 console
		SECTION BBX80LIB		; BBX80 library
		SECTION	STATIC1			; BASIC static variables data
		SECTION	STATIC2			; BBX80 static variables data
		SECTION	BIT90VEC		; BIT90 required code at end of ROM

		; The Colecovision has 1K internal RAM: $7000-$73FF
		; The BIT90 has 2K internal RAM: $7000-$77FF

		SECTION	BASICRAM		; BASIC RAM variables (768 bytes + 256 VDP buffer)
		ORG	$7000
		SECTION BASICVAR		; BASIC Initialized variables
		ORG	$7400		
		SECTION BBX80VAR		; BBX80 Initialized variables
		SECTION	BBX80RAM		; BBX80 variables (dynamic)
		SECTION	BIT90RAM		; BIT90 host variables (dynamic)
		SECTION	BBX80FREE		; Remaining free internal RAM for user


; -----------------------------------------------
; *** Boot the BIT90 host machine / cartrdige ***
; -----------------------------------------------

		SECTION	BBX80

		PUBLIC	bbx80Init
		PUBLIC	bbxIRQenable
		PUBLIC	bbxIRQdisable
		PUBLIC	bbxShowDsp
		PUBLIC	bbxHideDsp
		PUBLIC	bbxSetVdpR1
		PUBLIC	bbxSetTime
		PUBLIC	bbxGetTime
		PUBLIC	bbxCOMDS

		; Not implemented
		PUBLIC	bbxClg
		PUBLIC	bbxDspMode
		PUBLIC	bbxGetDateTime
		PUBLIC	bbxSetDateTime

		; basic
		EXTERN	START
		EXTERN	PBCDL
		EXTERN	CSAVE
		EXTERN	CLOAD
		EXTERN	EXTERR
		EXTERN	VAR1_START
		EXTERN	VAR1_RAM

		; bit90
		EXTERN	bbxHostInit
		EXTERN	bbxHostExit
		EXTERN	bbxHostBload
		EXTERN	VDPR1_7015

		; bbx80con
		EXTERN	initConsole
		EXTERN	bbxDspChar
		EXTERN	bbxKeysOn
		EXTERN	bbxKeysOff
		EXTERN	dspTell
		EXTERN	dspCRLF

		; bbx80lib
		EXTERN	bbxComLoad
		EXTERN	bbxComSave
		EXTERN	dspStringA

; ------------------------------------------------------------------------------
; Bootcode for BBX80 ROM 16k edition.
; ------------------------------------------------------------------------------
IFDEF BBX80ROM

		ORG	$0000

RST_00:		JP	START
		DB	BBXVERSION,0
RST_08:		JP	dspCRLF	
		DB	BASVERSION,0
RST_10:		JP	dspTell
		DEFS	5,$00
RST_18:		JP	bbxDspChar
		DEFS	5,$00
RST_20:		JP	bbxIRQstop
		DEFS	5,$00
RST_28:		JP	bbxIRQstart
		DEFS	5,$00
RST_30:		RET			; Not used
		DEFS	2,$00
		DEFS	5,$00
RST_38:		RET			; Not used (INTVEC)
		DEFS	2,$00
ENDIF

; ------------------------------------------------------------------------------
; Bootcode for BBX80 Cartridge 16k edition.
; ------------------------------------------------------------------------------
IFDEF BBX80CART

		ORG	$8000

CARTRIDGE:	DB	$AA,$55			; $8000 (AA+55 display title, 55+AA for test)
		DS	8,$FF			; $8002 - $8009 not used
START_GAME:	DW	START			; $800A
RST_08H_RAM:	JP	dspCRLF			; $800C
RST_10H_RAM:	JP	dspTell			; $800F
RST_18H_RAM:	JP	bbxDspChar		; $8012
RST_20H_RAM:	JP	bbxIRQstop		; $8015
RST_28H_RAM:	JP	bbxIRQstart		; $8018
RST_30H_RAM:	DB	$C9,$00,$00		; $801B
IRQ_INT_VECT:	DB	$C9,$00,$00		; $801E
NMI_INT_VECT:	JP	bbxNMI			; $8021

; $8024 Title, 3 lines separated by '/' where Character $1D=(C)
GAME_NAME:	DB	$1D," 2024 H.J. BERENDS/"	
		DB	"BBX80 BASIC FOR BIT90/" 
		DB	"2024"

ENDIF

; ------------------------------------------------------------------------------
; Stop/start the IRQ routine to prevent VDP RAM addressing issues / screen artifacts.
; This works fasters and is more reliable than frequent use of IRQ enable/disable.
; Alternative is the Colecovision vdp deferred queue, but that takes more code space.
; Stopping/starting IRQ can be used in nested routines, a counter is added to support this.
; The only IRQ used by the bit90 is the NMI from the VDP.
; ------------------------------------------------------------------------------
bbxIRQstop:	PUSH	HL
		LD	HL,IRQFLAG
		INC	(HL)
		POP	HL
		RET

bbxIRQstart:	PUSH	AF
		LD	A,(IRQFLAG)
		DEC	A
		LD	(IRQFLAG),A
		JR	NZ, _endResetIrq
		IN	A,(IOVDP1)
_endResetIrq:	POP	AF
		RET

; ------------------------------------------------------------------------------
; PUTIME - Set elapsed-time clock.
; Inputs: DEHL = time to load (seconds)
;
; In the BBX80 interrupt handler only seconds are counted, not centiseconds.
; ------------------------------------------------------------------------------
bbxSetTime:	CALL	bbxIRQdisable
		LD	(SECONDS),HL
        	LD	(SECONDS+2),DE
		JP	bbxIRQenable

; -----------------------------------------------------------------------------
; NMI - must start at address $066 when in ROM
; If necessary move the routines from above this point
; On the BIT90 the NMI is attached to the TMS9929A VDP interrupt pin
; It will be triggered every VSYNC (50 or 60 times per second)
; For vdp routines the IRQFLAG must be set with IRQstop and after the routine 
; it must be reset by calling IRQstart. 
; -----------------------------------------------------------------------------
IFDEF BBX80ROM
		ALIGN	$0066
ENDIF

bbxNMI:		PUSH	AF
		PUSH	HL
		LD	HL,IRQCOUNT
		INC	(HL)			; Increase IRQ counter

		; count to 50 or 60 and then increase seconds
IFDEF BBX80CART
		; LD	A,($0069)		; If you have a Coleco ROM for your region this should work correctly
		LD	A,VIDEOHZ		; If there's a mismatch then try this code instead
ELSE
		LD	A,VIDEOHZ
ENDIF
		CP	(HL)
		JR	NZ,_endCount
		XOR	A
		LD	(HL),A
		LD	HL,(SECONDS)
		INC	HL			; Count seconds 
		LD	(SECONDS),HL
		LD	A,H
		OR	L
		JR	NZ,_endCount
		LD	HL,(SECONDS+2)		 
		INC	HL
		LD	(SECONDS+2),HL
_endCount:	LD	A,(IRQFLAG)		; Is there a vdp routine running?
		OR	A
		JR	NZ,_endNMI
		IN	A,(IOVDP1)		; Reset interrupt flag (also destroys vdp address register)
		LD	A,(IRQUSR)
		CP	$C3			; Test for user interrupt vector
		CALL	Z,IRQUSR
_endNMI:	POP	HL
		POP	AF
		RETN

; ------------------------------------------------------------------------------
; VPD interrupt related routines (replaces bit90 SETMOD)
; ------------------------------------------------------------------------------

; Disable/enable IRQ 
; Cannot be nested, frequent usage may cause video artifacts.
bbxIRQenable:	PUSH	AF
		XOR	A
		LD	(IRQFLAG),A
		LD	A,(VDPR1_7015)
		SET	5,A			; Interrupt Bit
		JR	saveVdpR1

bbxIRQdisable:	PUSH	AF
		LD	A,1
		LD	(IRQFLAG),A
		LD	A,(VDPR1_7015)
		RES	5,A			; Interrupt Bit
		JR	saveVdpR1

; Show / Hide display
bbxShowDsp:	PUSH	AF			; Enable display
		LD	A,(VDPR1_7015)
		SET	6,A
		JR	saveVdpR1

bbxHideDsp:	PUSH	AF
		LD	A,(VDPR1_7015)
		RES	6,A

saveVdpR1:	LD	(VDPR1_7015),A

bbxSetVdpR1:	IN	A,(IOVDP1)		; reset interrupt on the vdp
		LD	A,(VDPR1_7015)
		OUT	(IOVDP1),A
		LD	A,$81
		OUT	(IOVDP1),A
		POP	AF
		RET

; ------------------------------------------------------------------------------
; GETIME - Read elapsed-time clock.
; Outputs: DEHL = elapsed time (seconds)
;
; In the BBX80 interrupt handler only seconds are counted, not centiseconds.
; ------------------------------------------------------------------------------
bbxGetTime:	CALL	bbxIRQdisable
		LD	HL,(SECONDS)
		LD	DE,(SECONDS+2)
		JR	bbxIRQenable

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

		; Test available expansion memory 
		; Note: himem in bbc basic is first unusable byte and in bit90 last usable byte

IFDEF BBX80CART
RAMSTART:	EQU	$C000			; Cartridge:tape version can use remaining RAM
RAMSIZE:	EQU	$4000			; First 16K are for BASIC, 2nd 16K max user RAM
ELSE
RAMSTART:	EQU	$8000			; ROM or TEST version may use all available RAM
RAMSIZE:	EQU	$8000
ENDIF
IFDEF BBX80ROM
		LD	A,$4F
		OUT	(IORAM1),A
ENDIF
		LD	HL,RAMSTART		; Start address
		LD	BC,RAMSIZE		; Max number of bytes to test


_mem_01:	LD	A,(HL)
		CPL
		LD	(HL),A
		CP	(HL)
		JR	NZ,_mem_02
		CPL
		LD	(HL),A
		CPI				; Test address++
		JR	NZ,_mem_02
		JP	PE,_mem_01		; Test until $FFFF
		DEC	HL
_mem_02:	LD	DE,RAMSTART		; Start address		
		LD 	A,D
		SUB	H
		JR	C,_mem_03		; At least 256 bytes test ok?
IFDEF BBX80ROM
		OUT	(IORAM0),A		; No expansion RAM available
ENDIF
		LD	HL,$7800		; Revert to internal RAM
		LD	DE,BBX80USER
_mem_03:	PUSH	DE			; PAGE (see LOMEM)
		PUSH	HL			; HIMEM

		; BIT90 init command mode: screen / sound / capsoff
		CALL	bbxHostInit
		CALL	initConsole		

		RST	R_dspTell
		DB	BELL
		DB	"BBX80 BASIC ",BASVERSION,CR,LF
		DB	BBXEDITION,$20,BBXVERSION,CR,LF
		DB	0

IFDEF BBX80ROM
		; Check for extended BASIC ROM
		LD	HL,$4000
		LD	A,$55
		CP	(HL)
		JR	NZ,_endCheckXbas
		INC	HL
		LD	A,$AA
		CP	(HL)
		JR	NZ,_endCheckXbas
		CALL	$4002			; Init extended BASIC
_endCheckXbas:
ENDIF
		; Display free memory
		POP	HL			; HIMEM
		POP	DE			; PAGE 
		PUSH	HL			; Save values
		PUSH	DE
		SBC	HL,DE
		DEC	HL			; BASIC will take 3 bytes
		DEC	HL
		DEC	HL
		CALL	PBCDL
		RST	R_dspTell
		DB	" Bytes Free",CR,LF
		DB	CR,LF
		DB	0 

		CALL	bbxIRQenable

		; Get saved himem and page, while switching hl and de
		POP	HL			; PAGE 
		POP	DE			; HIMEM
		XOR	A			; Set Z-flag (no autorun)
		RET


; -----------------------------------------------------------------------------
; Exit bbx80 environment
; -----------------------------------------------------------------------------
bbx80Exit:	EQU	bbxHostExit

; ------------------------------------------------------------------------------
; Not implemented
; ------------------------------------------------------------------------------

bbxClg:		EQU	STUB
bbxDspMode:	EQU	SORRY
bbxGetDateTime:	EQU	SORRY
bbxSetDateTime:	EQU	SORRY

; --------------------------------------------------------
; OS Commands / jump table
; --------------------------------------------------------
bbxCOMDS:	DEFM	"BLOA"
		DEFB	'D'+80H
		DEFW	bbxHostBload
		DEFM	"BY"
		DEFB	'E'+80H
		DEFW	bbx80Exit
		DEFM	"CLOA"
		DEFB	'D'+80H
		DEFW	CLOAD
		DEFM	"CSAV"
		DEFB	'E'+80H
		DEFW	CSAVE
		DEFM	"KEYSOF"
		DEFB	'F'+80H
		DEFW	bbxKeysOff
		DEFM	"KEYSO"
		DEFB	'N'+80H
		DEFW	bbxKeysOn
		DEFB	0FFH


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
		DB	0		; bbxCAPSOFF	The BIT90 has no capslock but a caps lower button, 0 means caps on
		DB	0		; bbxCOMSPEED	Baudrate selection (2400 Baud)
		DB	78		; bbxCOMMODE	Baudrate divder / bits / parity / stopbits  (8N1)
		DB	28		; bbxCOMTIMEOUT	Timeout (20sec.)
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
		PUBLIC	CAPSOFF
		PUBLIC	COMSPEED
		PUBLIC	COMMODE
		PUBLIC	COMTIMEOUT

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
CAPSOFF:	DS	1		
COMSPEED:	DS	1
COMMODE:	DS	1
COMTIMEOUT:	DS	1


; -----------------------------------
; *** Remaining free internal RAM ***
; -----------------------------------

		SECTION	BBX80FREE

BBX80USER:				
