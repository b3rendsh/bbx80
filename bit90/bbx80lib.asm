; ------------------------------------------------------------------------------
; BBX80 Library v1.2
; Copyright (C) 2023 H.J. Berends
;
; You can freely use, distribute or modify this program.
; It is provided freely and "as it is" in the hope that it will be useful, 
; but without any warranty of any kind, either expressed or implied.
; ------------------------------------------------------------------------------

		INCLUDE	"BBX80.INC"

		SECTION BBX80LIB

		PUBLIC	bbxClg
		PUBLIC	bbxDrawLine
		PUBLIC	bbxSetColor
		PUBLIC	bbxGetPixel
		PUBLIC	bbxPlotPixel

		PUBLIC	bbxComSave
		PUBLIC	bbxComLoad

		PUBLIC	vdpReadByte	
		PUBLIC	vdpWriteByte
		PUBLIC	vdpXYtoHLB
		PUBLIC	vdpWriteBlock
		
		; bbx80 
		EXTERN	bbxCOMSPEED
		EXTERN	bbxCOMMODE
		EXTERN	bbxCOMTIMEOUT

		; basic
		EXTERN	CLS

; ------------------------------------------------------------------------------
; Subroutine: Clear graphics screen
; Since text and graphics are on the same screen, CLG is the same as CLS
; ------------------------------------------------------------------------------
bbxClg:		EQU	CLS		; Must be CLS not bbxCls

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
; Parameters: DE points to memory variable for color (i.e. TXTCOLOR or GCOLOR)
;             HL contains the color number (only L is used)
; Color number 0 to 15 sets foreground color
; Color number +64 sets backdrop color
; Color number +128 sets background color
; Color number +192 sets background + backdrop color
; Note: the physical color numbers of the TMS9929A VDP are used.
; ------------------------------------------------------------------------------
bbxSetColor:	LD	H,L			; Copy color to H
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
		RST	R_NMIstop
		OUT	(IOVDP1),A
		LD	A,$87
		OUT	(IOVDP1),A
		RST	R_NMIstart
		RET

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
		RST	R_NMIstop		
		CALL	vdpReadByte
		RST	R_NMIstart
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
		RST	R_NMIstop
		CALL	vdpReadByte		; Read current pattern
		LD	C,A
		LD	A,(bbxGCOLOR)
		AND	A
		JR	Z,_plot_01		; Color 0?
		LD	A,C
		OR	B
		JR	_plot_02
_plot_01:	LD	A,B
		CPL
		AND	C
_plot_02:	CALL	vdpWriteByte		; Write pattern
		LD	A,(bbxGCOLOR)
		AND	A
		JR	Z,_plot_03		; Color 0?
		SET	5,H			; Offset Color table
		CALL	vdpWriteByte		; Write color
_plot_03:	RST	R_NMIstart
		POP	DE
		POP	BC
		POP	HL
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
vdpWriteByte:	LD	(bbxVDPVAR),A
		LD	A,L
		OUT	(IOVDP1),A
		LD	A,H
		SET	6,A
		OUT	(IOVDP1),A
		LD	A,(bbxVDPVAR)
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

; ------------------------------------------------------------------------------
; Subroutine: Load program via RS232 (COM port)
; Parameters: Start address in HL, max length in DE
; 
; Default start address is $8000
; Default end address is last free address or until no more data is received
; ------------------------------------------------------------------------------
bbxComLoad:	CALL	comInitPort
		LD	BC,$0000
		LD	A,(bbxCOMTIMEOUT)	; Timeout start receiving after appr. 20 seconds
		LD	(bbxTIMECOUNT),A
loadData:	IN	A,(IOCOM1)		; Read status
		AND	2
		JR	NZ,loadByte
		DJNZ	loadData		; Inner wait loop
		DEC	C
		JR	NZ,loadData		; Outer wait loop
		LD	A,(bbxTIMECOUNT)
		DEC	A
		LD	(bbxTIMECOUNT),A
		JR	NZ, loadData		; Appr. 0.77 seconds wait loop
		JR	loadEnd
loadByte:	IN	A,(IOCOM0)		; Get data
		LD	(HL),A
		INC	HL
		DEC	DE
		LD	A,D
		OR	E
		JR	Z,loadEnd
		LD	A,$03			
		LD	(bbxTIMECOUNT),A		
		JR	loadData
loadEnd:	POP	HL
		RET

; ------------------------------------------------------------------------------
; Subroutine: Save program via RS232 (COM port)
; Parameters: Start address in HL, length in DE
; ------------------------------------------------------------------------------
bbxComSave:	CALL	comInitPort
		LD	BC,$0000
		LD	A,(bbxCOMTIMEOUT)	; Timeout start transmission after appr. 20 seconds
		LD	(bbxTIMECOUNT),A
saveData:	IN	A,(IOCOM1)		; Read status
		AND	1
		JR	NZ,saveByte
		DJNZ	saveData		; Inner wait loop
		DEC	C
		JR	NZ,saveData		; Outer wait loop
		LD	A,(bbxTIMECOUNT)
		DEC	A
		LD	(bbxTIMECOUNT),A
		JR	NZ,saveData		; Appr. 0.77 seconds wait loop
		JR	saveEnd
saveByte:	LD	A,(HL)
		OUT	(IOCOM0),A		; Put data
		INC	HL
		DEC	DE
		LD	A,D
		OR	E
		JR	Z,saveEnd
		LD	A,$03			
		LD	(bbxTIMECOUNT),A
		JR	saveData
saveEnd:	POP	HL
		RET

; ------------------------------------------------------------------------------
; Initialize UART 8251 / COM port to 2400 8N1 
; Faster baudrate may produce data errors
; ------------------------------------------------------------------------------
comInitPort:	LD	A,(bbxCOMSPEED)		; Set baudrate
		OUT	(IOCOM2),A		
		LD	A,0			; Initialize with 3 zero's	
		OUT	(IOCOM1),A
		OUT	(IOCOM1),A
		OUT	(IOCOM1),A
		LD	A,64			; Reset instruction
		OUT	(IOCOM1),A		
		LD	A,(bbxCOMMODE)		; Mode instruction (baudrate divder / parity / stop bits)
		OUT	(IOCOM1),A	
		LD	A,55			; Command instruction (transmit enable / receive enable / reset errors)
		OUT	(IOCOM1),A		
		RET

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

; RS232 commands
bbxTIMECOUNT:	DB	0		; Time counter for timeout

; VDP commands 
bbxVDPVAR:	DB	0		; Used in vdp byte routines

