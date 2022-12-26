; ------------------------------------------------------------------------------
; BBX80 Console v1.0
; Copyright (C) 2022 H.J. Berends
;
; You can freely use, distribute or modify this program.
; It is provided freely and "as it is" in the hope that it will be useful, 
; but without any warranty of any kind, either expressed or implied.
; ------------------------------------------------------------------------------

		INCLUDE	"BBX80.INC"
	
		SECTION BBX80CON

		PUBLIC	bbxCls
		PUBLIC	bbxSetTime
		PUBLIC	bbxGetTime
	        PUBLIC  bbxSetCursor
		PUBLIC	bbxGetCursor
		PUBLIC	bbxDspChar
		PUBLIC	bbxDspPrompt
		PUBLIC	bbxGetLine
		PUBLIC	bbxKeysOn
		PUBLIC	bbxKeysOff

		PUBLIC	initConsole
		PUBLIC	dspCursor
		PUBLIC	dspCRLF
		PUBLIC	dspStringA
		PUBLIC	dspStringB
		PUBLIC	dspString0
		PUBLIC	dspTell

		EXTERN	GETKEY_3330
		EXTERN	bbxShowDsp
		EXTERN	bbxHideDsp

		EXTERN	bbxNMIenable
		EXTERN	bbxNMIdisable

		EXTERN	vdpWriteByte
		EXTERN	vdpWriteBlock


; ------------------------------------------------------------------------------
; Command: CLS / CLG
; Clear screen (excluding lines starting at MAXLIN) and move cursor to pos 0,0
; ------------------------------------------------------------------------------
bbxCls:		RST	R_NMIstop
		LD	A,(bbxMAXLIN)
		LD	B,A
		LD	C,$00
		LD	DE,$0000		; Start of VDP pattern table and curpos 0,0
		LD	(bbxCURPOS),DE
		XOR	A			; A=0 clear all patterns
		CALL	vdpWriteBlock
		LD	A,(bbxTXTCOLOR)		; Set all pixel colors to default color
		LD	D,$20			; Color table offset
		CALL	vdpWriteBlock
		RST	R_NMIstart
		RET

; ------------------------------------------------------------------------------
; PUTIME - Set elapsed-time clock.
; Inputs: DEHL = time to load (seconds)
;
; In the BBX80 NMI only seconds are counted, not centiseconds.
; ------------------------------------------------------------------------------
bbxSetTime:	CALL	bbxNMIdisable
		LD	(bbxSECONDS),HL
        	LD	(bbxSECONDS+2),DE
		CALL	bbxNMIenable
	        RET

; ------------------------------------------------------------------------------
; GETIME - Read elapsed-time clock.
; Outputs: DEHL = elapsed time (seconds)
;
; In the BBX80 NMI only seconds are counted, not centiseconds.
; ------------------------------------------------------------------------------
bbxGetTime:	CALL	bbxNMIdisable
		LD	HL,(bbxSECONDS)
		LD	DE,(bbxSECONDS+2)
		CALL	bbxNMIenable
        	RET

; -------------------------------------------
; PUTCSR - Move cursor to specified position.
;   Inputs: DE = horizontal position (LHS=0)
;           HL = vertical position (TOP=0)
; -------------------------------------------
bbxSetCursor:	LD	A,E
		CP	$32
		JR	C,_storeX
		LD	A,$31
_storeX:	LD	(bbxCURPOSX),A
		LD	A,(bbxMAXLIN)
		DEC	A
		CP	L
		JR	C,_storeY
		LD	A,L
_storeY:	LD	(bbxCURPOSY),A
		RET

; -------------------------------------------
; GETCSR - Return cursor coordinates.
;   Outputs:  DE = X coordinate (POS)
;             HL = Y coordinate (VPOS)
; -------------------------------------------
bbxGetCursor:	LD	DE,(bbxCURPOS)	; D=Y and E=X
		LD	L,D
		LD	H,$00		; HL = Y
		LD	D,H		; DE = X
		RET

; -----------------------------------------------------
; initConsole: Initialize console
; The VDP should be initialized first by the OS
; -----------------------------------------------------
initConsole:	PUSH	HL

		; Init variables
		LD	HL,V80_START		; Source
		LD	DE,V80_RAM		; Destination
		LD	BC,V80_END-V80_START	; Number of bytes to copy (calculated by assembler)
		LDIR				; Copy initial variable values to RAM

		; Init screen
		CALL	bbxHideDsp
		LD	BC,$0300		; Set counter
		LD	HL,$1800		; Start address nametable
_writeNT:	LD	A,L
		CALL	vdpWriteByte
		CPI				; Write Nametable with 3x 0..FF
		JP	PE,_writeNT
		CALL	bbxCls
		CALL	bbxShowDsp

		POP	HL
		RET

; ------------------------------------------------------------------------------
; Subroutine: Input a line on the console, terminated by CR
; ------------------------------------------------------------------------------
bbxGetLine:	PUSH	HL
		LD	A,(bbxBUFLEN)
		LD	B,A
		INC	B
		LD	HL,(bbxBUFPTR)
		LD	A,$20
_spaceBuffer:	LD	(HL),A
		INC	HL
		DJNZ	_spaceBuffer
		LD	HL,(bbxCURPOS)
		LD	(bbxMINPOS),HL
_repeatGetkey:	CALL	GETKEY_3330		; Get keyboard key pressed
		JR	C,_repeatGetkey
_newKey:	LD	B,$60			; time to wait for repeat
		LD	D,$FF
_repeatKey:	CALL	GETKEY_3330		; repeat key pressed
		JR	NC,_endKey
		LD	HL,bbxFLSCUR
		SET	6,(HL)
_endKey:	CALL	dspCursor
		JR	NC,_newKey
		CP	D			; compare with previous key press
		JR	NZ,_endNewkey		; not the same
		DJNZ	_repeatKey		; delay repeat key
		CALL	keyPressed
		LD	B,$04			; repeat speed
		JR	_repeatKey
_endNewkey:	LD	D,A
		CALL	keyPressed
		JR	_repeatKey

; -------------------------------------------
; Subroutine: process key pressed on keyboard
; -------------------------------------------
keyPressed:	PUSH	BC
		PUSH	DE
		PUSH	AF
		LD	A,(bbxKEYS)
		OR	A
		JR	Z,_endKeySound
		LD	A,$87			; key pressed sound
		OUT	(IOPSG0),A
		LD	A,$02
		OUT	(IOPSG0),A
		LD	A,$93
		OUT	(IOPSG0),A
		LD	HL,$1000
_repeatSound:	DEC	HL
		LD	A,H
		OR	L
		JR	NZ,_repeatSound
		LD	A,$9F
		OUT	(IOPSG0),A
_endKeySound:	POP	AF
		CP	$0D			; Enter pressed?
		JR	Z,_enterPressed
		LD	HL,(bbxCURPOS)
		LD	(bbxCURSAV),HL
		CALL	dspChar			; display pressed key and load it in the buffer
		LD	HL,(bbxCURPOS)
		LD	DE,(bbxMINPOS)
		XOR	A
		SBC	HL,DE			; curpos < minpos ?
		JR	C,_posError
		CALL	maxPos
		LD	HL,(bbxCURPOS)
		EX	DE,HL
		XOR	A
		SBC	HL,DE			; curpos > maxpos ?
_posError:	POP	DE
		POP	BC
		RET	NC
		LD	HL,(bbxCURSAV)		; load curpos with saved value
		LD	(bbxCURPOS),HL
		RET
_enterPressed:	POP	HL			; Offload pushed BC,DE,AF
		POP	HL
		POP	HL
		LD	HL,bbxFLSCUR
		RES	6,(HL)
		CALL	dspCursor
		LD	HL,(bbxBUFPTR)		; Destination buffer must be on page boundary
		LD	A,(bbxBUFLEN)
		LD	L,A
		LD	B,A
; Remove trailing spaces and add a CR
_delSpace:	LD	A,(HL)
		CP	$20
		JR	NZ,_endDelSpace
		DEC	HL
		DJNZ	_delSpace
_endDelSpace:	INC	HL			
		LD	(HL),CR			; Add \r to indicate end of buffer (bit90: 0)
		RST	R_dspCRLF		; Move cursor to beginning of next line
		POP	HL
		RET

; ----------------------------------------------
; Subroutine: count character position in buffer
; ----------------------------------------------
bufCount:	PUSH	AF
		LD	HL,(bbxMINPOS)
		LD	A,D
		SUB	H
		SLA	A
		LD	H,A
		SLA	H
		SLA	H
		SLA	H
		ADD	A,H
		SLA	H
		ADD	A,H
		ADD	A,E
		SUB	L
		LD	HL,(bbxBUFPTR)		; TXTBUF
		LD	L,A
		POP	AF
		RET

; --------------------------------------
; Move 1 position to the left
; --------------------------------------
curMin:		LD	A,$31			; Set curpos - 1
		DEC	E				
		CP	E
		RET	NC
		LD	E,A				
		DEC	D
		RET
	
; --------------------------------------
; Move 1 position to the right
; --------------------------------------
curPlus:	LD	A,$31			; Set curpos + 1
		INC	E
		CP	E
		RET	NC
		INC	D
		LD	E,$00
		RET

; -------------------------------------------------------------
; Subroutine: calculate max cursor position while in input mode
; -------------------------------------------------------------
maxPos:		LD	DE,(bbxMINPOS)
		LD	A,(bbxBUFLEN)
		DEC	A
_repeatPos:	CP	$32
		JR	C,_endPosY
		INC	D
		SUB	$32
		JR	_repeatPos
_endPosY:	ADD	A,E
		CP	$32
		JR	C,_endPosX
		INC	D
		SUB	$32
_endPosX:	LD	E,A
		RET


; -------------------------------------------------------------
; Part of dspchar subroutine, move here to conserve space
charBell:	LD	A,$87
		OUT	(IOPSG0),A
		LD	A,$03
		OUT	(IOPSG0),A
		LD	A,$90
		OUT	(IOPSG0),A
		LD	HL,$7000
_repeatBell:	DEC	HL
		LD	A,H
		OR	L
		JR	NZ,_repeatBell
		LD	A,$9F
		OUT	(IOPSG0),A
		JP	endChar


; -----------------------------------------------------------------------
; Subroutine : bbxDspChar
; Display an ASCII character on the console
; -----------------------------------------------------------------------
bbxDspChar:	PUSH	BC
		PUSH	DE
		PUSH	HL
		PUSH	AF
		LD	DE,(bbxCURPOS)
charControl:	CP	$07
		JR	Z,charBell
		CP	$09
		JR	Z,charTab
		CP	$0A
		JP	Z,charDown
		CP	$0D
		JR	Z,charEnter
		CP	$20
		JR	C,endChar
		CP	$80
		JR	NC,endChar
		CALL	screenWrite
		CALL	curPlus
		JR	endCharScroll


; -----------------------------------------------------------------------
; Subroutine : dspChar
; Display an ASCII character on the console and
; a printable character will also be stored in the buffer (HL)
; -----------------------------------------------------------------------
dspChar:	PUSH	BC
		PUSH	DE
		PUSH	HL
		PUSH	AF
		LD	DE,(bbxCURPOS)
		CP	$20			; Is it a control character?
		JR	NC,_noControl
		CP	$08
		JR	Z,charBS
		JR	charControl
_noControl:	CP	$80
		JR	C,charAscii
		CP	$F0
		JR	Z,charUp
		CP	$F1
		JR	Z,charDown
		CP	$F2
		JR	Z,charLeft
		CP	$F3
		JR	Z,charRight
		CP	$F4
		JR	Z,charDelete
		CP	$F5
		JR	Z,charInsert
endCharScroll:	CALL	scroll
endCharPos:	LD	(bbxCURPOS),DE
endChar:	POP	AF
		POP	HL
		POP	DE
		POP	BC
		RET


charBS:		LD	A,D
		OR	E
		JR	Z,endChar
		CALL	curMin
		CALL	bufCount
		LD	A,L
		CP	$FF			; BS before 1st char in buffer?
		JR	Z,endCharPos	
		LD	A,$20
		CALL	screenWrite
		LD	(HL),A
		JR	endCharPos

charTab:	LD	A,$09
_repeatTab:	CP	E
		JR	NC,_endTab
		ADD	A,$0A
		CP	$31
		JR	NZ,_repeatTab
		INC	D
		LD	E,$00
		JR	endCharScroll
_endTab:	INC	A
		LD	E,A
		JR	endCharPos

charEnter:	LD	E,$00
		JR	endCharPos

charAscii:	CALL	screenWrite
		CALL	bufCount
		LD	(HL),A			; Store character in the buffer
		CALL	curPlus
		JR	endCharScroll

charUp:		XOR 	A
		OR	D
		JR	Z,endChar
		DEC	D
		JR	endCharPos

charDown:	INC	D
		JR	endCharScroll

charLeft:	LD	A,E
		OR	D
		JR	Z,endChar
		CALL	curMin
		JR	endCharPos

charRight:	CALL	curPlus
		JR	endCharScroll

charDelete:	CALL	bufCount
_repeatDelete:	INC	HL
		LD	A,(HL)
		DEC	HL
		LD	(HL),A
		CALL	screenWrite
		CALL	curPlus
		INC	HL
		LD	A,(bbxBUFLEN)
		CP	L
		JR 	NZ,_repeatDelete
		JP	endChar

charInsert:	CALL	bufCount
		LD	A,(bbxBUFLEN)
		DEC	A
		LD	C,A
		LD	B,H
		LD	A,(BC)
		CP	$20
		JP	NZ,charBell
_repeat1Insert:	DEC	BC
		LD	A,(BC)
		INC	BC
		LD	(BC),A
		DEC	BC
		LD	A,L
		CP	C
		JR	NZ,_repeat1Insert
		LD	A,$20
		LD	(BC),A
_repeat2Insert:	CALL	screenWrite
		CALL	curPlus
		INC	BC
		LD	A,(bbxBUFLEN)
		CP	C
		JP	Z,endChar
		LD	A,(BC)
		JR	_repeat2Insert

; -------------------------------------------------------------------------
; Subroutine: set keyboard click sound on or off
; -------------------------------------------------------------------------
bbxKeysOff:	PUSH	AF
		XOR	A
		JR	_setKeys
bbxKeysOn:	PUSH	AF
		LD	A,1
_setKeys:	LD	(bbxKEYS),A
		POP	AF
		RET
; -------------------------------------------------------------------------
; Subroutine: write character to the screen.
; A character is 5x8 pixels and must be mapped on 8x8 character patterns.
; The character can span 2 consecutive bytes in the pattern table.
; The color will spill over to the next character, due to VDP limitations.
; Uses register IX and IY 
; -------------------------------------------------------------------------
screenWrite:	PUSH	BC
		PUSH	DE			; cursor position in DE
		PUSH	HL
		PUSH	AF
		PUSH	IX
		PUSH	IY
		LD	L,A			; Character to write (ascii)
		LD	H,$00
		ADD	HL,HL
		ADD	HL,HL
		EX	DE,HL			; DE = 4 * A, HL = CURPOS
		LD	IX,bbxCHARDEF		; Memory offset Character set definition
		ADD	IX,DE

; Calculate bit positions and masks:
; begin ------------------------------------
		LD	A,L
		RLCA
		RLCA
		ADD	A,L
		ADD	A,$06
		LD	L,A			; L = CURPOSX * 5 + 6
		OR	$F8
		CPL
		INC	A
		LD	C,A
		; --------------------------
		LD	A,L
		AND	$F8
		LD	L,A
		; --------------------------
		EX	DE,HL
		LD	HL,$FF07
		LD	B,C
_shiftLeft:	ADD	HL,HL
		INC	L
		DJNZ	_shiftLeft
		EX	DE,HL
; end --------------------------------------
; HL = Location Char Byte 1 in pattern table
; DE = Byte Mask 1 and 2
; C  = Bitpattern offset to the left

		PUSH	HL
		RST	R_NMIstop


; Load 16 bytes from VDP in VBPBUF starting at address in HL
; begin ----------------------------------------------------
		PUSH	BC
		LD	C,IOVDP1
		OUT	(C),L
		OUT	(C),H
		LD	HL,bbxVDPBUF
		LD	B,$10
		LD	C,IOVDP0
_repeatRxChar:	INI
		JR	NZ,_repeatRxChar
		POP	BC
; end ------------------------------------------------------
	
		LD	IY,bbxVDPBUF
		LD	B,$08			; A Character pattern is 8 lines
_repeatRead:	PUSH	BC

; Read the character definition in 2 nibbles and apply inversion filter if needed
; begin -------------------------------------------------------------------------
		LD	H,$00
		LD	A,B
		AND	1
		JR	NZ,_rightNibble
		LD	A,(IX+$00)
		AND	$F0
		LD	L,A
		JR	_nibbleDone
_rightNibble:	LD	A,(IX+$00)
		AND	$0F
		RLCA
		RLCA
		RLCA
		RLCA
		LD	L,A
		INC	IX			; Move to next 2 line patterns
_nibbleDone:	LD	A,(bbxINVCHAR)
		AND	1
		JR	Z,_invDone
		LD	A,L
		XOR	$F8			; Inverse character definition
		LD	L,A
_invDone:
; end ---------------------------------------------------------------------------

; Shift left the character to the correct position in the 2-byte pattern
; Then apply masks and insert character bits
; begin -------------------------------------------------------------------------
		LD	B,C
_shiftA:	ADD	HL,HL
		DJNZ	_shiftA
		LD	A,(IY+$00)		; Load 1st byte from buffer
		AND	D			; Mask neighbouring char
		OR	H			; Add new char pattern
		LD	(IY+$00),A
		LD	A,(IY+$08)		; Load 2nd byte from buffer
		AND	E
		OR	L
		LD	(IY+$08),A
		INC	IY			; Next position in write buffer
; end ---------------------------------------------------------------------------

		POP	BC
		DJNZ	_repeatRead

; Block write Char Byte 1 and Byte 2 patterns
; begin -------------------------------------------------------------------------
		POP	HL
		SET	6,H			; Write mode
		LD	DE,HL
		LD	C,IOVDP1
		OUT	(C),E
		OUT	(C),D
		LD	HL,bbxVDPBUF
		LD	B,$10
		LD	C,IOVDP0
_repeatCharPat:	OUTI
		JR	NZ,_repeatCharPat	
; end ---------------------------------------------------------------------------


; Block write colors for Byte 1 and Byte 2
; begin -------------------------------------------------------------------------
		SET	5,D			; Offset Color table
		LD	C,IOVDP1
		OUT	(C),E
		OUT	(C),D
		LD	A,(bbxTXTCOLOR)
		LD	B,$10
		LD	C,IOVDP0
_repeatCharCol:	OUT	(C),A
		NOP				; wait for VDP memory 29 T-states required
		DJNZ	_repeatCharCol
; end ---------------------------------------------------------------------------

_endCharCol:	RST	R_NMIstart
		POP	IY
		POP	IX
		POP	AF
		POP	HL
		POP	DE
		POP	BC
		RET

; -----------------------------------------------------------------------------------
; Subroutine: display cursor sprite (blink on and off)
; -----------------------------------------------------------------------------------
dspCursor:	PUSH	BC
		PUSH	DE
		PUSH	HL
		PUSH	AF
		RST	R_NMIstop
		LD	BC,$0008		; Counter
		LD	DE,$3800		; Beginning of sprite pattern table
		LD	HL,$3C00		; Beginning of attribute table
		LD	A,$F8			; New pattern
		AND	A
		CALL	vdpWriteBlock		; Block write to VDP
		LD	A,(bbxCURPOSY)
		RLCA
		RLCA
		RLCA
		DEC	A
		LD	D,A
		CALL	vdpWriteByte
		INC	HL
		LD	A,(bbxCURPOSX)
		LD	B,A
		RLCA
		RLCA
		ADD	A,B
		ADD	A,$06
		CALL	vdpWriteByte
		INC	HL
		XOR	A
		CALL	vdpWriteByte
		INC	HL
		LD	A,(bbxFLSCUR)		; Counter
		AND	$40
		JR	Z,_endFlash
		LD	A,(bbxTXTCOLOR)
		SRL	A
		SRL	A
		SRL	A
		SRL	A
_endFlash:	CALL	vdpWriteByte
		RST	R_NMIstart
		POP	AF
		POP	HL
		POP	DE
		POP	BC
		RET

; --------------------------------------
; Subroutine: scroll screen up if needed
; --------------------------------------
scroll:		LD	A,(bbxMAXLIN)
		DEC	A
		CP	D
		RET	NC			; No (further) scrolling needed
		PUSH	BC
		PUSH	DE
		PUSH	HL
		LD	D,A			; Save last line i.e. number of lines to scroll
		LD	HL,$0100		; Source=line 1, Destination line 0
_repeatScroll:	CALL	vdpCopyLine
		INC	H
		INC	L
		DEC	D			; Row counter
		JR	NZ, _repeatScroll
		DEC	H
		LD	A,H
		CALL	vdpClearLine
		LD	HL,bbxMINPOSY
		CP	(HL)
		JR	Z,_endNewline		; cursor is at Y position 0
		DEC	(HL)
_endNewline:	LD	HL,bbxCURSAVY
		DEC	(HL)
		POP	HL
		POP	DE
		POP	BC
		DEC	D			; cusor position Y -1
		JP	scroll			

; ------------------------------------------------------------------------------
; Subroutine: Move cursor to start of next line
; ------------------------------------------------------------------------------
dspCRLF:	LD	A,CR
		RST	R_dspChar
		LD	A,LF
		RST	R_dspChar
		RET

; ------------------------------------------------------------------------------
; Subroutine: Display prompt, always start on a new line
; ------------------------------------------------------------------------------
bbxDspPrompt:	LD	A,(bbxCURPOSX)
		AND	A
		JR	Z,_pos0
		RST	R_dspCRLF		
_pos0:		LD	A,'>'
		RST	R_dspChar
		RET

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
		RST	R_dspChar
		INC	HL
		DJNZ	dspStringB
		RET

dspString0:	LD	A,(HL)
		INC	HL
		OR	A
		RET	Z
		RST	R_dspChar
		JR	dspString0

; ------------------------------------------------------------------------------
; Subroutine: tell message (as in BBC BASIC TELL routine) 
; --------------------------------------------------------------------------
dspTell:	EX	(SP),HL		; Get return address
		CALL	dspString0
		EX	(SP),HL
		RET

; ------------------------------------------------------------------------------
; Subroutine: VDP copy one line to another line (pattern + color)
; Parameters: H = Source
;             L = Destination
; Uses:       VDPBUF
; ------------------------------------------------------------------------------
vdpCopyLine:	PUSH	HL
		PUSH	DE
		RST	R_NMIstop
		LD	DE,HL
		SET	6,E			; Write modus for destination
		XOR	A
		LD	C,IOVDP1
		OUT	(C),A
		OUT	(C),D			; Source line number
		LD	C,IOVDP0
		LD	HL,bbxVDPBUF
		LD	B,A
_repeatPatSrc:	INI
		JR	NZ,_repeatPatSrc
		LD	C,IOVDP1
		OUT	(C),A
		OUT	(C),E
		LD	C,IOVDP0
		LD	HL,bbxVDPBUF
_repeatPatDest:	OUTI
		JR	NZ,_repeatPatDest
		SET	5,D			; Offset Color table
		LD	C,IOVDP1
		XOR	A
		OUT	(C),A
		OUT	(C),D
		LD	C,IOVDP0
		LD	HL,bbxVDPBUF
_repeatColSrc:	INI
		JR	NZ,_repeatColSrc
		SET	5,E			; Offset Color table
		LD	C,IOVDP1
		OUT	(C),A
		OUT	(C),E
		LD	C,IOVDP0
		LD	HL,bbxVDPBUF
_repeatColDest:	OUTI
		JR	NZ,_repeatColDest
_endCopyLine:	RST	R_NMIstart
		POP	DE
		POP	HL
		RET

; ------------------------------------------------------------------------------
; Subroutine: VDP clear a line (pattern + color)
; Parameters: A = Line to clear
; Uses:       VDPBUF
; ------------------------------------------------------------------------------
vdpClearLine:	RST	R_NMIstop
		LD	C,A
		SET	6,C
		XOR	A
		LD	B,A
		OUT	(IOVDP1),A
		LD	A,C			; Write modus
		OUT	(IOVDP1),A
		XOR	A
_repeatClrPat:	OUT	(IOVDP0),A		; Clear Pattern
		NOP				; wait for VDP memory 29 T-states required
		DJNZ	_repeatClrPat
		XOR	A
		OUT	(IOVDP1),A
		SET	5,C			; Offset Color table
		LD	A,C
		OUT	(IOVDP1),A
		LD	A,(bbxTXTCOLOR)
_repeatClrCol:	OUT	(IOVDP0),A		; Clear Color (set to default color)
		NOP				; wait for VDP memory 29 T-states required
		DJNZ	_repeatClrCol
_endClrLine:	RST	R_NMIstart
		RET


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
		DB	$18		; bbxMAXLIN
		DB	$F0		; bbxTXTCOLOR
		DB	0		; bbxINVCHAR
		DB	1		; bbxKEYS
		DB	0		; bbxCAPSOFF
		DB	0		; bbxCOMSPEED
		DB	78		; bbxCOMMODE
		DB	28		; bbxCOMTIMEOUT
V80_END:

; ------------------------------------------------------------------------------
; Characterset bitmap definition 8x4 bit
;
; Example character 'A':
;
;   Line:           $Nibble
;      1: - - - -   0
;      2: - X X -   6
;      3: X - - X   9
;      4: X - - X   9
;      5: X X X X   F
;      6: X - - X   9
;      7: X - - X   9
;      8: - - - -   0
;
; Each line is a nibble, with 2 nibble in 1 byte results in 4 bytes per char:
; A = $06 $99 $F9 $90
;
; To separate the characters 1 more column is required so each character is 8x5
; Horizontal 5 x 50 = 250 pixels (the first character starts at pixel 6)
; Vertical   8 x 24 = 192 pixels
; ------------------------------------------------------------------------------

bbxCHARDEF:	EQU	bbxCHARDEF128-128

		; Offset from base CHARDEF is 32x4 is 128 bytes

bbxCHARDEF128:	DB	$00,$00,$00,$00	; 32 <space>
		DB	$04,$44,$40,$40	; 33 !
		DB	$0A,$A0,$00,$00	; 34 "
		DB	$09,$F9,$9F,$90	; 35 #
		DB	$02,$7A,$65,$E4	; 36 $
		DB	$09,$A2,$45,$90	; 37 %
		DB	$0E,$A4,$BA,$D0	; 38 &
		DB	$06,$24,$00,$00	; 39 '
		DB	$02,$44,$44,$20	; 40 (
		DB	$04,$22,$22,$40	; 41 )
		DB	$00,$96,$F6,$90	; 42 *
		DB	$00,$44,$E4,$40	; 43 +
		DB	$00,$00,$06,$24	; 44 ,
		DB	$00,$00,$F0,$00	; 45 -
		DB	$00,$00,$06,$60	; 46 .
		DB	$01,$22,$44,$80	; 47 /
		DB	$06,$9B,$D9,$60	; 48 0
		DB	$02,$62,$22,$70	; 49 1
		DB	$06,$91,$68,$F0	; 50 2
		DB	$0F,$12,$19,$60	; 51 3
		DB	$08,$AA,$F2,$20	; 52 4
		DB	$0F,$8E,$19,$60	; 53 5
		DB	$06,$8E,$99,$60	; 54 6
		DB	$0F,$12,$44,$40	; 55 7
		DB	$06,$96,$99,$60	; 56 8
		DB	$06,$99,$71,$60	; 57 9
		DB	$00,$66,$06,$60	; 58 :
		DB	$00,$66,$06,$24	; 59 ;
		DB	$00,$24,$84,$20	; 60 <
		DB	$00,$0F,$0F,$00	; 61 =
		DB	$00,$84,$24,$80	; 62 >
		DB	$06,$92,$40,$40	; 63 ?
		DB	$06,$91,$79,$60	; 64 @
		DB	$06,$99,$F9,$90	; 65 A
		DB	$0E,$9E,$99,$E0	; 66 B
		DB	$07,$88,$88,$70	; 67 C
		DB	$0E,$99,$99,$E0	; 68 D
		DB	$0F,$8E,$88,$F0	; 69 E
		DB	$0F,$8E,$88,$80	; 70 F
		DB	$06,$98,$B9,$60	; 71 G
		DB	$09,$9F,$99,$90	; 72 H
		DB	$07,$22,$22,$70	; 73 I
		DB	$01,$11,$19,$60	; 74 J
		DB	$09,$AC,$CA,$90	; 75 K
		DB	$08,$88,$88,$F0	; 76 L
		DB	$09,$F9,$99,$90	; 77 M
		DB	$09,$DD,$BB,$90	; 78 N
		DB	$06,$99,$99,$60	; 79 O
		DB	$0E,$99,$E8,$80	; 80 P
		DB	$06,$99,$9A,$70	; 81 Q
		DB	$0E,$99,$EA,$90	; 82 R
		DB	$07,$86,$11,$E0	; 83 S
		DB	$0E,$44,$44,$40	; 84 T
		DB	$09,$99,$99,$60	; 85 U
		DB	$09,$99,$9A,$C0	; 86 V
		DB	$09,$99,$9F,$90	; 87 W
		DB	$09,$96,$69,$90	; 88 X
		DB	$09,$99,$71,$60	; 89 Y
		DB	$0F,$12,$48,$F0	; 90 Z
		DB	$06,$44,$44,$60	; 91 [
		DB	$08,$44,$22,$10	; 92 \
		DB	$06,$22,$22,$60	; 93 ]
		DB	$00,$69,$00,$00	; 94 ^
		DB	$00,$00,$00,$0F	; 95 _
		DB	$06,$42,$00,$00	; 96 `
		DB	$00,$06,$9F,$90	; 97 a
		DB	$08,$8E,$99,$E0	; 98 b
		DB	$00,$06,$88,$60	; 99 c
		DB	$01,$17,$99,$70	; 100 d
		DB	$00,$06,$9E,$70	; 101 e
		DB	$06,$4E,$44,$40	; 102 f
		DB	$00,$07,$97,$16	; 103 g
		DB	$08,$8E,$99,$90	; 104 h
		DB	$02,$02,$22,$20	; 105 i
		DB	$02,$02,$22,$24	; 106 j
		DB	$08,$8A,$CC,$A0	; 107 k
		DB	$04,$44,$44,$60	; 108 l
		DB	$00,$09,$F9,$90	; 109 m
		DB	$00,$0E,$99,$90	; 110 n
		DB	$00,$06,$99,$60	; 111 o
		DB	$00,$0E,$9E,$88	; 112 p
		DB	$00,$07,$97,$11	; 113 q
		DB	$00,$06,$88,$80	; 114 r
		DB	$00,$07,$C3,$E0	; 115 s
		DB	$04,$4E,$44,$20	; 116 t
		DB	$00,$09,$99,$60	; 117 u
		DB	$00,$09,$9A,$C0	; 118 v
		DB	$00,$09,$9F,$90	; 119 w
		DB	$00,$09,$66,$90	; 120 x
		DB	$00,$09,$97,$16	; 121 y
		DB	$00,$0F,$3C,$F0	; 122 z
		DB	$00,$64,$84,$60	; 123 {
		DB	$04,$40,$44,$40	; 124 |
		DB	$00,$C4,$24,$C0	; 125 }
		DB	$00,$05,$A0,$00	; 126 ~
		DB	$00,$00,$00,$00	; 127 <del>

; -------------------------------------------
; *** RAM for initialized BBX80 variables *** 
; -------------------------------------------

		SECTION	BBX80VAR

		PUBLIC	bbxNMIUSR
		PUBLIC	bbxNMIFLAG
		PUBLIC	bbxNMICOUNT
		PUBLIC	bbxSECONDS
		PUBLIC	bbxBUFLEN
		PUBLIC	bbxMAXLIN
		PUBLIC	bbxTXTCOLOR
		PUBLIC	bbxINVCHAR
		PUBLIC	bbxKEYS
		PUBLIC	bbxCAPSOFF
		PUBLIC	bbxCOMSPEED
		PUBLIC	bbxCOMMODE
		PUBLIC	bbxCOMTIMEOUT

V80_RAM:

; NMI variables
bbxNMIUSR:	DB	$C9,$00,$00	; NMI interrupt routine extension (executed at end of Vsync routine)
bbxNMIFLAG:	DB	0		; NMI Flag
bbxNMICOUNT:	DB	0		; NMI Counter
bbxSECONDS:	DW	0,0		; Elapsed seconds since boot (approx.)

; Variables for console i/o
bbxBUFLEN:	DB	$FF		; Set input buffer length to max 255 (Byte 256 reserved for CR)
bbxMAXLIN:	DB	$18		; Maximum linenumber + 1
bbxTXTCOLOR:	DB	$F0		; Text color ($F0 is white on transparant)
bbxINVCHAR:	DB	0		; Inverse character (inverse color)
bbxKEYS:	DB	1		; Keyboard click sound on or off
bbxCAPSOFF:	DB	0		; The BIT90 has no capslock but a caps lower button, 0 means caps on


; Variables for RS232 i/o
bbxCOMSPEED:	DB	0		; Baudrate selection (2400 Baud)
bbxCOMMODE:	DB	78		; Baudrate divder / bits / parity / stopbits  (8N1)
bbxCOMTIMEOUT:	DB	28		; Timeout (20sec.)

; -------------------------------
; *** RAM for BBX80 variables ***
; -------------------------------
		
		SECTION BBX80RAM

		PUBLIC	bbxBUFPTR
		PUBLIC	bbxCURPOS
		PUBLIC	bbxMINPOS
		PUBLIC	bbxCURSAV
		PUBLIC	bbxFLSCUR


; Variables for console i/o
bbxBUFPTR:	DW	0		; Pointer to destination text buffer (replaces TXTBUF)
bbxCURPOS:	DW	0		; Cursor position x,y
bbxMINPOS:	DW	0		; Minimum curpos x,y
bbxCURSAV:	DB	0		; Saved curpos
bbxFLSCUR:	DB	0		; Flash cursor counter


; Constants
bbxCURPOSX:	EQU	bbxCURPOS+0
bbxCURPOSY:	EQU	bbxCURPOS+1
bbxMINPOSX:	EQU	bbxMINPOS+0
bbxMINPOSY:	EQU	bbxMINPOS+1
bbxCURSAVX:	EQU	bbxCURSAV+0
bbxCURSAVY:	EQU	bbxCURSAV+1

; ---------------------------------------
; *** BASIC RAM, additional variables ***
; ---------------------------------------

		SECTION BASICRAM

		PUBLIC	bbxVDPBUF

bbxVDPBUF:		DS	256,0		; 256 Byte VDP buffer (must be aligned to 256 byte page)

 