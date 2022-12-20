; ------------------------------------------------------------------------------
; BBX80 v1.0
; 
; This module contains the memory map and bootcode for the BIT90 host computer.
; ------------------------------------------------------------------------------

		INCLUDE	"BBX80.INC"
		INCLUDE	"BASIC.INC"

; ------------------
; *** Memory map ***
; ------------------

		;Define in makefile:
		;DEFINE	BBX80ROM		
		;DEFINE	BBX80CART

		SECTION BOOT			; Start / Page 0
		SECTION	BASIC			; BBC BASIC interpreter
		SECTION	BASICASM		; BBC BASIC inline assembler
		SECTION	BIT90HOST		; BIT90 host routines
		SECTION	BBX80CON		; BBX80 console
		SECTION BBX80LIB		; BBX80 library
		SECTION	BIT90VEC		; BIT90 required code at end of ROM

		; The Colecovision has 1K internal RAM: $7000-$73FF
		; The BIT90 has 2K internal RAM: $7000-$77FF

		SECTION	BASICRAM		; BBC BASIC RAM variables (768 bytes + 256 VDP buffer)
		ORG	$7000

		SECTION BBX80VAR		; BBX80 Initialized variables
		ORG	$7400		

		SECTION	BBX80RAM		; BBX80 variables (dynamic)
		SECTION	BIT90RAM		; BIT90 host variables (dynamic)
		SECTION	BBX80FREE		; Remaining free internal RAM for user


; -----------------------------------------------
; *** Boot the BIT90 host machine / cartrdige ***
; -----------------------------------------------

		SECTION	BOOT

		PUBLIC	bbx80Init
		PUBLIC	bbxNMIenable
		PUBLIC	bbxNMIdisable

		EXTERN	START
		EXTERN	bbxNMIUSR
		EXTERN	bbxNMICOUNT
		EXTERN	bbxNMIFLAG
		EXTERN	bbxSECONDS

		EXTERN	INIT_3FBB
		EXTERN	SETMOD_252B
		EXTERN	VDPR1_7015
		EXTERN	CAPSKEY_7016

		EXTERN	bbxDspChar
		EXTERN	dspCRLF
		EXTERN	dspTell

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
RST_20:		JP	bbxNMIstop
		DEFS	5,$00
RST_28:		JP	bbxNMIstart
		DEFS	5,$00
RST_30:		RET
		DEFS	2,$00
		DEFS	5,$00
RST_38:		RET			; JP INTVEC
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
RST_20H_RAM:	JP	bbxNMIstop		; $8015
RST_28H_RAM:	JP	bbxNMIstart		; $8018
RST_30H_RAM:	DB	$C9,$00,$00		; $801B
IRQ_INT_VECT:	DB	$C9,$00,$00		; $801E
NMI_INT_VECT:	JP	bbxNMI			; $8021

; $8024 Title, 3 lines separated by '/' where Character $1D=(C)
GAME_NAME:	DB	"BBBX80 ",$1D," 2022 H.J.BERENDS/" 
		DB	"BBC BASIC Z80 ",$1D," R.T.RUSSELL/"	
		DB	"2022"

ENDIF

; ---------------------------------------------------------------------------
; dspNumHL - routine to display a value in HL in ascii characters
; ---------------------------------------------------------------------------
dspNumHL:	LD	BC,-10000
		CALL	num1
		LD	BC,-1000
		CALL	num1
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
		RST	R_dspChar
		INC	DE
		RET

; -----------------------------------------------------------------------------
; NMI - must start at address $066 when in ROM
; If necessary move the routines from above this point
; On the BIT90 the NMI is attached to the TMS9929A VDP interrupt pin
; It will be triggered every VSYNC (50 or 60 times per second)
; For vdp routines the NMIFLAG must be set with NMIstop and after the routine 
; it must be reset by calling NMIstart. 
; -----------------------------------------------------------------------------

IFDEF BBX80ROM
		ALIGN	$0066
		JP	bbxNMI
		DB	VIDEOHZ			; $0069 value 60=NTSC or 50=PAL systems 
ENDIF						; this should be the same value as in the Coleco ROM

bbxNMI:		PUSH	AF
		PUSH	HL
		LD	HL,bbxNMICOUNT
		INC	(HL)			; Increase NMI counter

		; count to 50 or 60 and then increase seconds
		; LD	A,($0069)		; If you have a Coleco ROM for your region this should work correctly
		LD	A,VIDEOHZ		; If there's a mismatch then try this code instead
		CP	(HL)
		JR	NZ,_endCount
		XOR	A
		LD	(HL),A
		LD	HL,(bbxSECONDS)
		INC	HL			; Count seconds 
		LD	(bbxSECONDS),HL
		LD	A,H
		OR	L
		JR	NZ,_endCount
		LD	HL,(bbxSECONDS+2)		 
		INC	HL
		LD	(bbxSECONDS+2),HL
_endCount:	LD	A,(bbxNMIFLAG)		; Is there a vdp routine running?
		CP	$AA
		JR	Z,_endNMI
		IN	A,(IOVDP1)		; Reset interrupt flag (also destroys vdp address register)
		LD	A,(bbxNMIUSR)
		CP	$C3			; Test for user interrupt vector
		CALL	Z,bbxNMIUSR
_endNMI:	POP	HL
		POP	AF
		RETN

; High frequency use of following routines will cause video artifacts.
bbxNMIenable:	PUSH	AF
		LD	A,(VDPR1_7015)
		SET	5,A			; Interrupt Bit
		JR	_NMIset
bbxNMIdisable:	PUSH	AF
		LD	A,(VDPR1_7015)
		RES	5,A			; Interrupt Bit
_NMIset:	LD	(VDPR1_7015),A
		CALL	SETMOD_252B
		POP	AF
		RET

; Stop/start the NMI routine to prevent VDP RAM addressing issues / screen artifacts.
; This works fasters and is more reliable than frequent use of NMI enable/disable.
; Alternative is the Colecovision vdp deferred queue, but that takes more code space.
bbxNMIstop:	PUSH	AF
		LD	A,$AA
		LD	(bbxNMIFLAG),A
		POP	AF
		RET

bbxNMIstart:	PUSH	AF
		XOR	A
		LD	(bbxNMIFLAG),A
		IN	A,(IOVDP1)		; reset interrupt on the vdp
		POP	AF
		RET
		
; -----------------------------------------------------------------------------
; Initialize bit90 host
; Initialize console
; -----------------------------------------------------------------------------
bbx80Init:	; Test available expansion memory 
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

		; BIT90 init command mode: screen / sound
		CALL	INIT_3FBB
		XOR	A
		LD	(CAPSKEY_7016),A	; Set caps lower off (ie. caps is on after boot)

		RST	R_dspTell
		DB	BELL
		DB	"BBX80 FOR BIT90 ",BBXVERSION,CR,LF
		DB	"BBC BASIC (Z80) ",BASVERSION,CR,LF
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
		CALL	dspNumHL
		RST	R_dspTell
		DB	" BYTES FREE",CR,LF
		DB	CR,LF
		DB	0 

		CALL	bbxNMIenable

		; Get saved himem and page, while switching hl and de
		POP	HL			; PAGE 
		POP	DE			; HIMEM
		RET

; -----------------------------------
; *** Remaining free internal RAM ***
; -----------------------------------

		SECTION	BBX80FREE

BBX80USER:				
