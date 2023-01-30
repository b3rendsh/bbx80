; ------------------------------------------------------------------------------
; BBX80 Console v1.1
; Copyright (C) 2023 H.J. Berends
;
; You can freely use, distribute or modify this program.
; It is provided freely and "as it is" in the hope that it will be useful, 
; but without any warranty of any kind, either expressed or implied.
; ------------------------------------------------------------------------------

		INCLUDE	"BBX80.INC"
	
		SECTION BBX80CON

		PUBLIC	bbxCls
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

		EXTERN	bbxShowDsp
		EXTERN	bbxHideDsp

		EXTERN	bbxNMIenable
		EXTERN	bbxNMIdisable

		EXTERN	vdpWriteByte
		EXTERN	vdpWriteBlock

		EXTERN	OSKEY
		EXTERN	FLAGS

; ------------------------------------------------------------------------------
; Command: CLS / CLG
; Clear screen (excluding lines starting at MAXLIN) and move cursor to pos 0,0
; ------------------------------------------------------------------------------
bbxCls:		RST	R_NMIstop
		LD	A,(bbxMAXLIN)
		LD	B,A
		XOR	A			; A=0 clear all patterns
		LD	C,A
		LD	D,A
		LD	E,A			; Start of VDP pattern table and curpos 0,0
		LD	(bbxCURPOS),DE
		CALL	vdpWriteBlock
		LD	A,(bbxTXTCOLOR)		; Set all pixel colors to default color
		LD	D,$20			; Color table offset
		CALL	vdpWriteBlock
		RST	R_NMIstart
		RET

; -------------------------------------------
; PUTCSR - Move cursor to specified position.
;   Inputs: DE = horizontal position (LHS=0)
;           HL = vertical position (TOP=0)
; -------------------------------------------
bbxSetCursor:	LD	A,COLUMNS-1
		CP	E
		JR	C,_storeX
		LD	A,E
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
initConsole:	; Init variables
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
		JP	bbxShowDsp

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

endLine:	PUSH	HL
		LD	HL,bbxFLSCUR
		RES	6,(HL)
		CALL	dspCursor
_releaseKey:	OR	A			; Clear carry flag
		SBC	HL,HL			; HL=0
		CALL	OSKEY			; Wait until all keys are released
		JR	C,_releaseKey
		POP	HL
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
		LD	BC,(bbxLASTKEY)
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
		LD	HL,bbxFLSCUR
		SET	6,(HL)			; show cursor during repeat
		CALL	dspCursor

_endKey:	LD	C,A
		LD	(bbxLASTKEY),BC		; save key / repeat counter

		; key sound
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

; ----------------------------------------------
; Convert proprietary keycodes to standard code
; ----------------------------------------------
keyConversion:	LD	HL,bbxCONVTAB
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
; Subroutine : bbxDspChar
; Display an ASCII character on the console
; -----------------------------------------------------------------------
bbxDspChar:	PUSH	BC
		PUSH	DE
		PUSH	HL
		PUSH	AF
		LD	DE,endChar
		PUSH	DE			; Set return address
		LD	DE,(bbxCURPOS)

		CP	BELL
		JR	Z,charBell
		CP	BS
		JR	Z,charLeft
		CP	LF
		JR	Z,charDown
		CP	CR
		JR	Z,charEnter
		CP	$80			; Ascii character?
		JR	C,screenWrite
		POP	DE			; Ditch return address

endChar:	CALL	scroll
		LD	(bbxCURPOS),DE
		POP	AF
		POP	HL
		POP	DE
		POP	BC
		RET

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
		RET

charLeft:	LD	A,D
		OR	E
		RET	Z			; At pos 0,0?
		LD	A,COLUMNS-1		; Set curpos - 1
		DEC	E				
		CP	E
		RET	NC
		LD	E,A				
		DEC	D
		RET

charDown:	INC	D
		RET

charEnter:	LD	E,$00
		RET	

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
; Subroutine: write character to the screen and move cursor 1 right.
; A character is 5x8 pixels and must be mapped on 8x8 character patterns.
; The character can span 2 consecutive bytes in the pattern table.
; The color will spill over to the next character, due to VDP limitations.
; Uses register IX and IY 
; -------------------------------------------------------------------------
screenWrite:	PUSH	BC
		PUSH	DE			; cursor position in DE
		PUSH	HL
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
		POP	HL
		POP	DE
		POP	BC
		; Set curpos + 1
		LD	A,COLUMNS-1
		INC	E
		CP	E
		RET	NC
		INC	D
		LD	E,$00
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
		POP	HL
		POP	DE
		POP	BC
		DEC	D			; cusor position Y -1
		JR	scroll			

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

; Conversion table
bbxCONVTAB:	DB	$F0,CUU		; Key up
		DB	$F1,CUD		; Key down
		DB	$F2,CUB		; Key left
		DB	$F3,CUF		; Key right
		DB	$F4,DEL		; Delete
		DB	$F5,INS		; Insert
		DB	$FF,$00		; End of table


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

		PUBLIC	bbxCURPOS
		PUBLIC	bbxFLSCUR

; Variables for console i/o
bbxCURPOS:	DW	0		; Cursor position x,y
bbxFLSCUR:	DB	0		; Flash cursor counter
bbxLASTKEY:	DW	0		; Last key pressed / repeat counter

; Constants
bbxCURPOSX:	EQU	bbxCURPOS+0
bbxCURPOSY:	EQU	bbxCURPOS+1

; ---------------------------------------
; *** BASIC RAM, additional variables ***
; ---------------------------------------

		SECTION BASICRAM

		PUBLIC	bbxVDPBUF

bbxVDPBUF:	DS	256,0		; 256 Byte VDP buffer (must be aligned to 256 byte page)
 