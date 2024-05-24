; ------------------------------------------------------------------------------
; BBX80 VDP_TMS9918A Library v1.0
; Copyright (C) 2024 H.J. Berends
;
; You can freely use, distribute or modify this program.
; It is provided freely and "as it is" in the hope that it will be useful, 
; but without any warranty of any kind, either expressed or implied.
; ------------------------------------------------------------------------------
; TMS9918A hardware dependent graphics commands and subroutines
; ------------------------------------------------------------------------------

		SECTION BBX80LIB

		INCLUDE	"bbx80.inc"

		PUBLIC	bbxDspMode
		PUBLIC	bbxClg
		PUBLIC	bbxDrawLine
		PUBLIC	bbxSetGfxColor
		PUBLIC	bbxGetPixel
		PUBLIC	bbxPlotPixel

		PUBLIC	vdpInit
		PUBLIC	vdpShowDsp
		PUBLIC	vdpHideDsp

		PUBLIC	vdpReadByte	
		PUBLIC	vdpWriteByte
		PUBLIC	vdpXYtoHLB
		PUBLIC	vdpWriteBlock

		EXTERN	bbxIRQstop
		EXTERN	bbxIRQstart

; ------------------------------------------------------------------------------
; Display mode (not implemented)
; ------------------------------------------------------------------------------
bbxDspMode:	EQU	SORRY

; ------------------------------------------------------------------------------
; Subroutine: Clear graphics screen
; ------------------------------------------------------------------------------
bbxClg:		CALL	bbxIRQstop
		LD	B,$18
		XOR	A			; A=0 clear all patterns
		LD	C,A
		LD	D,A
		LD	E,A			; Start of VDP pattern table and curpos 0,0
		LD	(GCURPOS),DE
		CALL	vdpWriteBlock
		LD	A,(GCOLOR)		; Set all pixel colors to default color
		LD	D,$20			; Color table offset
		CALL	vdpWriteBlock
		JP	bbxIRQstart

; ------------------------------------------------------------------------------
; Subroutine: Draw a line
; Parameters: HL=start, DE=end 
;
; Uses recursive divide and conquer algorithm 
; Requires less code than Bresenham's line algorithm but it's less accurate
; and we can't use self modifying code if it's in ROM. 
; ------------------------------------------------------------------------------
bbxDrawLine:	CALL	bbxPlotPixel
		PUSH	HL
		
		;Calculate centre pixel
		LD	A,H
		ADD	A,D
		RRA
		LD	H,A
		LD	A,L
		ADD	A,E
		RRA
		LD	L,A

		;If end=centre then exit
		OR	A
		SBC	HL,DE
		JR	Z,exitDraw
		ADD	HL,DE

		EX	DE,HL
		CALL	bbxDrawLine		; DE=centre, HL=start
		EX	(SP),HL
		EX	DE,HL
		CALL	bbxDrawLine		; DE=end, HL=centre
		EX	DE,HL
		POP	DE
		RET

exitDraw:	POP	HL
		RET

; ------------------------------------------------------------------------------
; Subroutine: Sets the foreground, background and backdrop color.
; Parameters: DE points to memory variable for color (i.e. GCOLOR)
;             HL contains the color number (only L is used)
; Color number 0 to 15 sets foreground color
; Color number +64 sets backdrop color
; Color number +128 sets background color
; Color number +192 sets background + backdrop color
; Note: the physical color numbers of the TMS9929A VDP are used.
; ------------------------------------------------------------------------------
bbxSetGfxColor:	LD	H,L			; Copy color to H
		LD	A,L
		AND	$0F			; Color value 0..15
		BIT	7,H			; set foreground color? 
		JR	NZ,_background
		BIT	6,H
		JR	NZ,_backdrop
		RLCA
		RLCA
		RLCA
		RLCA
		LD	L,A
		LD	A,(DE)
		AND	$0F
		OR	L
		LD	(DE),A
		RET

_background:	LD	L,A
		LD	A,(DE)
		AND	$F0
		OR	L
		LD	(DE),A
		BIT	6,H
		RET	Z
_backdrop:	LD	A,L
		CALL	bbxIRQstop
		OUT	(IOVDP1),A
		LD	A,$87
		OUT	(IOVDP1),A
		JP	bbxIRQstart

; -----------------------------------------------------------------------------
; Subroutine: Get a pixel value on/off
; Parameters: DE = Y,X 
; Returns   : Z flag = pixel off, C flag = wrong X,Y value
;             If pixel on then A contains pixel bit position value 
; -----------------------------------------------------------------------------
bbxGetPixel:	PUSH	HL
		PUSH	BC
		CALL	vdpXYtoHLB		; calculate VDP address for X,Y position
		JR	C,_endGetPixel		; wrong X,Y value?
		CALL	bbxIRQstop		
		CALL	vdpReadByte
		CALL	bbxIRQstart
		AND	B			; Z = 0 if pixel not set
_endGetPixel:	POP	BC
		POP	HL
		RET

; -----------------------------------------------------------------------------
; Subroutine: Plot a pixel
; Parameters: DE = Y,X and Color in variable GCOLOR
;
; Only plotting in highres is implemented
; -----------------------------------------------------------------------------
bbxPlotPixel:	PUSH	HL
		PUSH	BC
		PUSH	DE
		CALL	vdpXYtoHLB		; Convert X,Y to VDP address and bitnr
		CALL	bbxIRQstop
		CALL	vdpReadByte		; Read current pattern
		LD	C,A
		LD	A,(GCOLOR)
		AND	A
		JR	Z,_plot_01		; Color 0?
		LD	A,C
		OR	B
		JR	_plot_02
_plot_01:	LD	A,B
		CPL
		AND	C
_plot_02:	CALL	vdpWriteByte		; Write pattern
		LD	A,(GCOLOR)
		AND	A
		JR	Z,_plot_03		; Color 0?
		SET	5,H			; Offset Color table
		CALL	vdpWriteByte		; Write color
_plot_03:	CALL	bbxIRQstart
		POP	DE
		POP	BC
		POP	HL
		RET

; ------------------------------------------------------------------------------
; Subroutine: Initialize graphics adapter
; ------------------------------------------------------------------------------
vdpInit:	IN	A,(IOVDP1)		; Read VDP register 0
		LD	A,(VDPINITR1)
		LD	(VDPR1),A
		LD	B,$10
		LD	C,IOVDP1
		LD	HL,VDPINITR0
		OTIR				; Initialize VDP register 0 to 7

		; Init screen
		CALL	vdpHideDsp
		LD	BC,$0300		; Set counter
		LD	HL,$1800		; Start address nametable
_writeNT:	LD	A,L
		CALL	vdpWriteByte
		CPI				; Write Nametable with 3x 0..FF
		JP	PE,_writeNT
		XOR	A
		LD	(GCOLOR),A
		CALL	bbxClg
		CALL	vdpShowDsp

; ------------------------------------------------------------------------------
; Show / Hide display
; ------------------------------------------------------------------------------
vdpShowDsp:	PUSH	AF			; Enable display
		LD	A,(VDPR1)
		SET	6,A
		JR	saveVdpR1

vdpHideDsp:	PUSH	AF
		LD	A,(VDPR1)
		RES	6,A

saveVdpR1:	LD	(VDPR1),A

vdpSetVdpR1:	IN	A,(IOVDP1)		; reset interrupt on the vdp
		LD	A,(VDPR1)
		OUT	(IOVDP1),A
		LD	A,$81
		OUT	(IOVDP1),A
		POP	AF
		RET

; ------------------------------------------------------------------------------
; Subroutine: Read Byte from VDP
; Parameters: HL = Address to readm
; Returns   : A  = Byte read 
; Replaces bit90 ROM routine $30E2
; There is really at least 4xNOP needed for a physical VDP unless during vblank
; ------------------------------------------------------------------------------
vdpReadByte:	LD	A,L
		OUT	(IOVDP1),A
		LD	A,H
		OUT	(IOVDP1),A
		NOP				; wait for VDP memory 29 T-states required 
		NOP				; "  
		NOP				; "
		NOP				; "
		IN	A,(IOVDP0)
 		RET

; ------------------------------------------------------------------------------
; Subroutine: Write Byte to VDP
; Parameters: HL = Address to readm
;             A  = Byte to write 
; Replaces bit90 ROM routine $30F9
; ------------------------------------------------------------------------------
vdpWriteByte:	LD	(VDPVAR),A
		LD	A,L
		OUT	(IOVDP1),A
		LD	A,H
		SET	6,A
		OUT	(IOVDP1),A
		LD	A,(VDPVAR)
		OUT	(IOVDP0),A
		RET

; ------------------------------------------------------------------------------
; Subroutine: Calculate VDP address for Pixel X,Y
; Parameters: DE = Y,X
; Return    : HL = VDP address and B = Bitnr
;
; VDP Address is INT(Y/8)*256 + (Y MOD 8) + INT(X/8)*8
; ------------------------------------------------------------------------------
vdpXYtoHLB:	LD	A,D
		CP	192
		JR	NC,_errPixel		; invalid Y position
		LD	A,E
		AND	$07
		LD	B,A
		INC	B			; B = bit position in the pattern byte
		LD	A,E
		AND	$F8			
		LD	C,A			; C = INT(X/8)*8
		LD	A,D
		AND	$07
		OR	C			
		LD	L,A			; L = C + (Y MOD 8)
		LD	H,D
		SRL	H
		SRL	H
		SRL	H			; H = INT(Y/8)
		XOR	A
		SCF
_bitPixel:	RRA
		DJNZ	_bitPixel
		LD	B,A			; B = Bit mask X position
		RET

_errPixel:	XOR	A
		SCF
		RET

; ------------------------------------------------------------------------------
; Subroutine: Write Block to VDP
; Parameters: DE = Destination VDP Address
;             HL = Source RAM Address (if carry flag set)
;             A  = Fill byte (if carry flag not set)
;             BC = Number of bytes to write
; Returns   : A  = Byte read 
; Replaces bit90 ROM routine $3888
; ------------------------------------------------------------------------------
vdpWriteBlock:	PUSH	BC
		PUSH	DE
		PUSH	HL
		EX	AF,AF'
		LD	A,E
		OUT	(IOVDP1),A
		LD	A,D
		OR	$40
		OUT	(IOVDP1),A
		EX	AF,AF'
_repeatFill:	JR	NC,_exitFill
		LD	A,(HL)
_exitFill:	OUT	(IOVDP0),A
		CPI
		JP	PE,_repeatFill
		POP	HL
		POP	DE
		POP	BC			
		RET

; -------------------
; *** Static Data ***
; -------------------

; VDP Registers 
VDPINITR0:	DB	$02,$80		; ------10: Set mode bit 3 (graphics 2 mode), Disable external VDP input 
VDPINITR1:	DB	$E0,$81		; 11100-00: Select 4416 ram, enable display, enable interrupt, graphics 2 mode,
					;           sprite size 0 (8x8), magnification 1x 
VDPINITR2:	DB	$06,$82		; Base address nametable $1800
VDPINITR3:	DB	$FF,$83		; Base address colortable $2000
VDPINITR4:	DB	$03,$84		; Base address patterns $0000
VDPINITR5:	DB	$78,$85		; Base address sprite attributes $3C00
VDPINITR6:	DB	$07,$86		; Base address sprite patterns $3800
VDPINITR7:	DB	$01,$87		; ----0001: Backdrop color ($01=black, $0C=green)

; -------------------------------
; *** RAM for BBX80 variables ***
; -------------------------------
		
		SECTION BBX80RAM

		PUBLIC	GCOLOR
		PUBLIC	GCURPOS

GCOLOR:		DS	1		; Graphics comamnds color 
GCURPOS:	DS	2		; Graphics cursor X,Y (max 255,191)
VDPVAR:		DS	1		; Used in vdp byte routines
VDPR1:		DS	1		; Copy of VDP register 1 value


GCURPOSX:	EQU	GCURPOS+0
GCURPOSY:	EQU	GCURPOS+1

; ---------------------------------------
; *** BASIC RAM, additional variables ***
; ---------------------------------------

		SECTION BASICRAM

		PUBLIC	VDPBUF

VDPBUF:		DS	256,0		; 256 Byte VDP buffer (must be aligned to 256 byte page)
