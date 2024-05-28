; ------------------------------------------------------------------------------
; BBX80 CON_TMS9918A Console v1.0
; Copyright (C) 2024 H.J. Berends
;
; You can freely use, distribute or modify this program.
; It is provided freely and "as it is" in the hope that it will be useful, 
; but without any warranty of any kind, either expressed or implied.
; ------------------------------------------------------------------------------
; TMS9918A hardware dependent console output commands and subroutines.
; ------------------------------------------------------------------------------

		SECTION BBX80LIB

		INCLUDE	"bbx80.inc"
		INCLUDE "console.inc"

		PUBLIC	bbxCls
	        PUBLIC  bbxSetCursor
		PUBLIC	bbxGetCursor
		PUBLIC	bbxDspChar
		PUBLIC	bbxSetColor
		PUBLIC	bbxDspPrompt

		PUBLIC	dspCRLF
		PUBLIC	dspStringA
		PUBLIC	dspStringB
		PUBLIC	dspString0
		PUBLIC	dspTell

		PUBLIC	dspCursor

		EXTERN	bbxIRQstart
		EXTERN	bbxIRQstop
		EXTERN	bbxBell
		EXTERN	bbxSetGfxColor
		EXTERN	vdpWriteBlock
		EXTERN	vdpWriteByte

		EXTERN	MAXLIN
		EXTERN	TXTCOLOR
		EXTERN	INVCHAR
		EXTERN	VDPBUF

; ------------------------------------------------------------------------------
; Command: CLS
; Clear screen and move cursor to pos 0,0
; Lines starting at MAXLIN (e.g. statusline) are not cleared
; ------------------------------------------------------------------------------
bbxCls:		CALL	bbxIRQstop
		LD	A,(MAXLIN)
		LD	B,A
		XOR	A			; A=0 clear all patterns
		LD	C,A
		LD	D,A
		LD	E,A			; Start of VDP pattern table and curpos 0,0
		LD	(CURPOS),DE
		CALL	vdpWriteBlock
		LD	A,(TXTCOLOR)		; Set all pixel colors to default color
		LD	D,$20			; Color table offset
		CALL	vdpWriteBlock
		JP	bbxIRQstart

; -------------------------------------------
; PUTCSR - Move cursor to specified position.
;   Inputs: DE = horizontal position (LHS=0)
;           HL = vertical position (TOP=0)
; -------------------------------------------
bbxSetCursor:	LD	A,COLUMNS-1
		CP	E
		JR	C,_storeX
		LD	A,E
_storeX:	LD	(CURPOSX),A
		LD	A,(MAXLIN)
		DEC	A
		CP	L
		JR	C,_storeY
		LD	A,L
_storeY:	LD	(CURPOSY),A
		RET

; -------------------------------------------
; GETCSR - Return cursor coordinates.
;   Outputs:  DE = X coordinate (POS)
;             HL = Y coordinate (VPOS)
; -------------------------------------------
bbxGetCursor:	LD	DE,(CURPOS)	; D=Y and E=X
		LD	L,D
		LD	H,$00		; HL = Y
		LD	D,H		; DE = X
		RET

; -----------------------------------------------------------------------
; Subroutine: Display an ASCII character on the console
; Includes cursor position update / scrolling
; -----------------------------------------------------------------------
bbxDspChar:	PUSH	BC
		PUSH	DE
		PUSH	HL
		PUSH	AF
		LD	DE,endChar
		PUSH	DE			; Set return address
		LD	DE,(CURPOS)

		CP	BELL
		JP	Z,bbxBell
		CP	BS
		JR	Z,charLeft
		CP	LF
		JR	Z,charDown
		CP	CR
		JR	Z,charEnter
		CP	$20
		JR	C,endControl
		CP	$80			; Ascii character?
		JP	C,screenWrite
endControl:	POP	DE			; Ditch return address
		JR	endChar2

endChar:	CALL	scroll
		LD	(CURPOS),DE
endChar2:	POP	AF
		POP	HL
		POP	DE
		POP	BC
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
		LD	IX,CHARDEF		; Memory offset Character set definition
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
		CALL	bbxIRQstop


; Load 16 bytes from VDP in VBPBUF starting at address in HL
; begin ----------------------------------------------------
		PUSH	BC
		LD	C,IOVDP1
		OUT	(C),L
		OUT	(C),H
		LD	HL,VDPBUF
		LD	B,$10
		LD	C,IOVDP0
_repeatRxChar:	INI
		JR	NZ,_repeatRxChar
		POP	BC
; end ------------------------------------------------------
	
		LD	IY,VDPBUF
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
_nibbleDone:	LD	A,(INVCHAR)
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
		LD	HL,VDPBUF
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
		LD	A,(TXTCOLOR)
		LD	B,$10
		LD	C,IOVDP0
_repeatCharCol:	OUT	(C),A
		NOP				; wait for VDP memory 29 T-states required
		DJNZ	_repeatCharCol
; end ---------------------------------------------------------------------------

_endCharCol:	CALL	bbxIRQstart
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

; --------------------------------------
; Subroutine: scroll screen up if needed
; --------------------------------------
scroll:		LD	A,(MAXLIN)
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
; Subroutine: Set text color (same as set graphics color)
; ------------------------------------------------------------------------------
bbxSetColor:	EQU	bbxSetGfxColor

; ------------------------------------------------------------------------------
; Subroutine: tell message (as in BASIC TELL routine) 
; ------------------------------------------------------------------------------
dspTell:	EX	(SP),HL		; Get return address
		CALL	dspString0
		EX	(SP),HL
		RET

; ------------------------------------------------------------------------------
; Subroutine: Display prompt, always start on a new line
; ------------------------------------------------------------------------------
bbxDspPrompt:	LD	A,(CURPOSX)
		AND	A
		JR	Z,_pos0
		CALL	dspCRLF		
_pos0:		LD	A,'>'
		JP	bbxDspChar

; ------------------------------------------------------------------------------
; Subroutine: Move cursor to start of next line
; ------------------------------------------------------------------------------
dspCRLF:	LD	A,CR
		CALL	bbxDspChar
		LD	A,LF
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


; -----------------------------------------------------------------------------------
; Subroutine: display cursor sprite (blink on and off)
; -----------------------------------------------------------------------------------
dspCursor:	PUSH	BC
		PUSH	DE
		PUSH	HL
		PUSH	AF
		CALL	bbxIRQstop
		LD	BC,$0008		; Counter
		LD	DE,$3800		; Beginning of sprite pattern table
		LD	HL,$3C00		; Beginning of attribute table
		LD	A,$F8			; New pattern
		AND	A
		CALL	vdpWriteBlock		; Block write to VDP
		LD	A,(CURPOSY)
		RLCA
		RLCA
		RLCA
		DEC	A
		LD	D,A
		CALL	vdpWriteByte
		INC	HL
		LD	A,(CURPOSX)
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
		LD	A,(FLSCUR)		; Counter
		AND	$40
		JR	Z,_endFlash
		LD	A,(TXTCOLOR)
		SRL	A
		SRL	A
		SRL	A
		SRL	A
_endFlash:	CALL	vdpWriteByte
		CALL	bbxIRQstart
		POP	AF
		POP	HL
		POP	DE
		POP	BC
		RET


; ------------------------------------------------------------------------------
; Subroutine: VDP copy one line to another line (pattern + color)
; Parameters: H = Source
;             L = Destination
; Uses:       VDPBUF
; ------------------------------------------------------------------------------
vdpCopyLine:	PUSH	HL
		PUSH	DE
		CALL	bbxIRQstop
		LD	DE,HL
		SET	6,E			; Write modus for destination
		XOR	A
		LD	C,IOVDP1
		OUT	(C),A
		OUT	(C),D			; Source line number
		LD	C,IOVDP0
		LD	HL,VDPBUF
		LD	B,A
_repeatPatSrc:	INI
		JR	NZ,_repeatPatSrc
		LD	C,IOVDP1
		OUT	(C),A
		OUT	(C),E
		LD	C,IOVDP0
		LD	HL,VDPBUF
_repeatPatDest:	OUTI
		JR	NZ,_repeatPatDest
		SET	5,D			; Offset Color table
		LD	C,IOVDP1
		XOR	A
		OUT	(C),A
		OUT	(C),D
		LD	C,IOVDP0
		LD	HL,VDPBUF
_repeatColSrc:	INI
		JR	NZ,_repeatColSrc
		SET	5,E			; Offset Color table
		LD	C,IOVDP1
		OUT	(C),A
		OUT	(C),E
		LD	C,IOVDP0
		LD	HL,VDPBUF
_repeatColDest:	OUTI
		JR	NZ,_repeatColDest
_endCopyLine:	CALL	bbxIRQstart
		POP	DE
		POP	HL
		RET

; ------------------------------------------------------------------------------
; Subroutine: VDP clear a line (pattern + color)
; Parameters: A = Line to clear
; Uses:       VDPBUF
; ------------------------------------------------------------------------------
vdpClearLine:	CALL	bbxIRQstop
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
		LD	A,(TXTCOLOR)
_repeatClrCol:	OUT	(IOVDP0),A		; Clear Color (set to default color)
		NOP				; wait for VDP memory 29 T-states required
		DJNZ	_repeatClrCol
_endClrLine:	JP	bbxIRQstart

; -------------------
; *** Static Data ***
; -------------------

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

CHARDEF:	EQU	CHARDEF128-128

		; Offset from base CHARDEF is 32x4 is 128 bytes

CHARDEF128:	DB	$00,$00,$00,$00	; 32 <space>
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

; -------------------------------
; *** RAM for BBX80 variables ***
; -------------------------------
		
		SECTION BBX80RAM

		PUBLIC	CURPOS
		PUBLIC	FLSCUR
		PUBLIC	FLSPEED
		PUBLIC	CURPOSY
		PUBLIC	CURPOSX

CURPOS:		DS	2		; Cursor position x,y
FLSCUR:		DS	1		; Flash cursor counter
FLSPEED:	DS	1		; Flash cursor speed control

CURPOSX:	EQU	CURPOS+0
CURPOSY:	EQU	CURPOS+1


 