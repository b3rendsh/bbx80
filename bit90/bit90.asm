; ------------------------------------------------------------------------------
; BBX80 BIT90 HOST v1.0
; Copyright (C) 2022 H.J. Berends*
;
; You can freely use, distribute or modify this program.
; It is provided freely and "as it is" in the hope that it will be useful, 
; but without any warranty of any kind, either expressed or implied.
;
; *For this module I inspected original code of the BIT90 BASIC and re-used
; a few parts, with modifications. I consider it fair use of orphaned software.
; ------------------------------------------------------------------------------

		INCLUDE	"BBX80.INC"

; ---------------------------
; *** BIT90 host routines ***
; ---------------------------
 
		SECTION BIT90HOST

		PUBLIC	SETMOD_252B
		PUBLIC	SHOWDSP_3FD4
		PUBLIC	HIDEDSP_3FDD
		PUBLIC	BSAVE_1A90
		PUBLIC	BLOAD_1C4B
		PUBLIC	GETKEY_3330

		EXTERN	TAPE_ERR

		EXTERN	dspStringA
		EXTERN	dspCursor
		EXTERN	bbxNMIenable
		EXTERN	bbxNMIdisable
		EXTERN	bbxFLSCUR

; ------------------------------------------------------------------------------
; Set VDP register 0 and 1
; (bit90: $252B)
; ------------------------------------------------------------------------------
SETMOD_252B:	IN	A,(IOVDP1)
		LD	A,(VDPR0_7014)
		OUT	(IOVDP1),A
		LD	A,$80
		OUT	(IOVDP1),A
		LD	A,(VDPR1_7015)
		OUT	(IOVDP1),A
		LD	A,$81
		OUT	(IOVDP1),A
		RET

; ------------------------------------------------------------------------------
; Show / Hide display
; (bit90: $3FDD)
; ------------------------------------------------------------------------------

SHOWDSP_3FD4:	IN	A,(IOVDP1)		; Enable display
		LD	A,(VDPR1_7015)		; Copy of VDP Register 1
		OR	$40			; %01000000
		JR	_setVDPR1
HIDEDSP_3FDD:	IN	A,(IOVDP1)		; Disable display
		LD	A,(VDPR1_7015)
		AND	$BF			; %10111111
_setVDPR1:	LD	(VDPR1_7015),A
		OUT	(IOVDP1),A
		LD	A,$81
		OUT	(IOVDP1),A
		BIT	1,C
		RET

; -----------------------------------------------------------------------------
; BSAVE - Save an area of memory to a file on tape.
; Inputs: HL =  addresses filename (term CR)
;         DE = start address of data to save
;         BC = length of data to save (bytes)
; 
; The filename is truncated to max 15 characters (including extension).
; The filename, type (.M) and start address are saved with the data on tape.
; You can use any ASCII character in the filename.
; (bit90: $1A90 with modifications)
; -----------------------------------------------------------------------------
BSAVE_1A90:	LD	(LAB_71C9),BC		; Store file size (bytes)
		LD	(LAB_71C7),DE		; Store start address
		LD	(LAB_70A0),DE
		LD	DE,LAB_70A9
		CALL	FUN_1B31		; Copy filename
		LD	HL,(LAB_71C9)		; load the file size in HL
		LD	A,'M'			; Binary files have extension ".M" on BIT90
		LD	(LAB_709F),A
LAB_1AF4:	LD	A,L			; Calculate number of 256 byte blocks
		OR	A
		LD	A,H
		JR	Z,LAB_1AFA
		INC	A
LAB_1AFA:	LD	(LAB_709E),A		; 256-byte Block counter
		CALL	FUN_1C2E		; Wait until user start the tape unit
		JP	NZ,LAB_1B2C		; Not ready, terminate
		CALL	bbxNMIdisable		; Tape I/O requires exact timing
		LD	A,$42			; Header ID
		LD	(LAB_71CB),A
		XOR	A
		LD	(LAB_709D),A
		RST	R_dspTell
		DB	CR,LF,BELL,"*TAPE DUMP:"
		DB	0
		CALL	FUN_1D84		; display filename and calculate checksum
		CALL	FUN_1B6C		; Write file header to tape
		CALL	FUN_1BE4		; Write file data to tape
		CALL	bbxNMIenable
LAB_1B26:	RST	R_dspTell
		DB	CR,LF,"* END *",BELL
		DB	0
LAB_1B2C:	RST	R_dspCRLF
		RET


; Write filename to memory, DE points to memory location
FUN_1B31:	LD	B,$0F			; Max length of filename
_copyFilename:	LD	A,(HL)
		CP	CR
		JR	Z,_endFilename
		LD	(DE),A
		INC	DE
		INC	HL
		DJNZ	_copyFilename
_endFilename:	LD	A,$0F
		SUB	B
		LD	(LAB_70A8),A		; Length of filename for save
		LD	(LAB_71B0),A		; Length of filenmame for load
		RET

; Write file header to tape
FUN_1B6C:	LD	A,(LAB_71CB)
		LD	(LAB_7098),A		; Header id ($42)
		LD	HL,(LAB_71C7)		
		LD	(LAB_71AA),HL		; Start address
		LD	HL,(LAB_71C9)		
		LD	(LAB_71AC),HL
		LD	(LAB_709B),HL		; Number of data bytes in block
		CALL	FUN_1BC2
		LD	(LAB_7099),DE		; Checksum
		CALL	FUN_1D6E		; Save to tape
		RET

; Calculate block checksum
FUN_1BC2:	LD	BC,$010D		; 13 control + 256 data = 269 byte counter
		LD	HL,LAB_709B
		XOR	A
		LD	D,A
LAB_1BCA:	ADD	A,(HL)			; Add all bytes in the block
		JR	NC,LAB_1BCE
		INC	D
LAB_1BCE:	CPI
		JP	PE,LAB_1BCA
		LD	E,A			; DE = SUM(Block Content)
		RET

; Write file data to tape (in 256 byte blocks)
FUN_1BE4:	; Added progress indicator
		LD	A,'.'
		RST	R_dspChar
		LD	A,$44
		LD	(LAB_7098),A		; Block data id
		LD	B,$01
LAB_1BEB:	PUSH	BC
		LD	HL,(LAB_71AC)
		LD	A,H
		OR	L
		JR	Z,LAB_1C1E
		LD	A,H
		OR	A
		LD	BC,$0100
		JR	NZ,LAB_1BFE
		LD	C,L
		LD	B,A
		LD	L,B
		LD	H,B
LAB_1BFE:	LD	(LAB_71AC),HL
		LD	HL,LAB_709D
		INC	(HL)			; Blocknumber++
		LD	(LAB_709B),BC
		LD	HL,(LAB_71AA)
		LD	DE,LAB_70A8
		LDIR
		LD	(LAB_71AA),HL
		CALL	FUN_1BC2
		LD	(LAB_7099),DE
		CALL	FUN_1D6E
LAB_1C1E:	POP	BC
		LD	HL,(LAB_71AC)
		LD	A,H
		OR	A
		RET	Z
		DJNZ	LAB_1BEB
		DEC	H
		LD	(LAB_71AC),HL
		JP	FUN_1BE4

; Get Ready, called by BSAVE and BLOAD
FUN_1C2E:	RST	R_dspTell
		DB	CR,LF,"READY?",BELL
		DB	0
_getReady:	CALL	dspCursor
		CALL	GETKEY_3330
		JR	NC,_getReady
		LD	HL,bbxFLSCUR
		RES	6,(HL)
		CALL	dspCursor
		RST	R_dspChar
		CP 	'Y'
		RET

; Save block to tape
FUN_1D6E:	LD	BC,$0110		; 16 control + 256 data bytes
		LD	HL,LAB_7098		; Buffer
		CALL	FUN_1DB7		; Write to tape
		RET

; display filename and calculate checksum
FUN_1D84:	LD	HL,LAB_70A8
		CALL	dspStringA		; Print filename
LAB_1D91:	LD	A,'.'
		RST	R_dspChar
		LD	A,(LAB_709F)
		RST	R_dspChar
		CALL	FUN_1BC2		; Calculate checksum
		LD	HL,(LAB_7099)
		XOR	A
		SBC	HL,DE
		RET

; Save data to tape (same code as BIT90 BASIC)
FUN_1DB7:	EXX
		LD	HL,$78B4
		EXX
		PUSH	BC
		LD	DE,$0096		; number of sync bit pairs
LAB_1DC0:	AND	A
		CALL	FUN_1E06		; write sync bit 0
		SCF
		PUSH	HL
		POP	HL
		CALL	FUN_1E06		; write sync bit 1
		DEC	DE
		LD	A,D
		OR	E
		JP	NZ,LAB_1DC0
		LD	B,$1C			; number of sync bytes
		LD	C,$8F			; sync byte
LAB_1DD4:	RRC	C
		NOP
		CALL	FUN_1E06		; sync bit
		DJNZ	LAB_1DD4
		POP	BC
		NOP
LAB_1DDE:	SCF
		CALL	FUN_1E06		; write control bit
		LD	E,$08			; write 8 data bits
		LD	D,(HL)			; get data byte in block
		INC 	HL			; increase data pointer
LAB_1DE6:	RRC	D			; get next bit from the data byte
		CALL	FUN_1E06		; write to tape
		LD	A,$00
		DEC	E
		JP	NZ,LAB_1DE6
		SCF
		NOP
		CALL	FUN_1E06		; write control bit
		DEC 	BC
		LD	A,B			; buffer counter in BC
		OR	C
		JP	NZ,LAB_1DDE		; end of buffer?
		SCF
		NOP
		CALL	FUN_1E06		; write control bit	
		LD	A,$02			; sync signal level
		OUT	(IOTAP0),A		; Write to tape port
		RET

; Write carry flag bit to tape
FUN_1E06:	EXX
		LD	BC,$0306		; wavelength 1 bit
		JP	C,LAB_1E10
		LD	BC,$0D0C		; wavelength 0 bit
LAB_1E10:	LD	D,$07
		JP	LAB_1E16
LAB_1E15:	LD	B,C
LAB_1E16:	DJNZ	LAB_1E16
		RLC	H
		RLA
		RLC	L
		RLA
		OUT	(IOTAP0),A		; Write to tape port
		DEC	D
		JP	NZ,LAB_1E15
		RLC	H
		RLC	L
		EXX
		RET

; -----------------------------------------------------------------------------
; BLOAD - Load an area of memory from a file on tape.
; Inputs: HL = addresses filename (term CR)
;         DE = address at which to load
;         BC = maximum allowed size (bytes)
;
; On the BIT90 a machine file is loaded at the same start address that was used 
; in BSAVE. This is changed so you can load at a different address.
; A check for max file size is also added as are the progress indication dots.
; 
; (bit90: $1C4B with modifications)
; -----------------------------------------------------------------------------
BLOAD_1C4B:	LD	(LAB_71C9),BC		; Store max file size (bytes)
		LD	(LAB_71C7),DE		; Store start address
		LD	DE,LAB_71B1
		CALL	FUN_1B31		; Copy filename to BIT90 variable
		LD	A,'M'			; File is of type 'M'achine (binary)
		LD	(LAB_71A9),A
		PUSH	HL
LAB_1C68:	LD	A,$42			; Block: header id
		LD	(LAB_71CB),A
		CALL	FUN_1C2E		; Wait until user starts the tape unit
		JP	NZ,LAB_1B2C		; Not ready, terminate
		CALL	bbxNMIdisable		; Tape I/O requires exact timing
		RST	R_dspTell
		DB	CR,LF,BELL,"*TAPE LOAD:"
		DB	0
		CALL	FUN_1C8D		; Load and check header
		CALL	FUN_1CF6		; Load data
		CALL	bbxNMIenable
		JP	LAB_1B26		; Print 'end' and done


; Added indicator that filename or type is incorrect
WRONG_FILE:	LD	A,'x'
		RST	R_dspChar	

; Load next file from tape, check header if it's the right file
; Display filename from block if it's a valid header 
; if it's the right filename and file type then process file size from header block
; else try next block from tape


FUN_1C8D:	RST	R_dspCRLF
		LD	D,$00
LAB_1C95:	CALL	FUN_1D78		; Read block from tape
		LD	A,(LAB_7098)
		LD	HL,LAB_71CB
		CP	(HL)			; Is it a file header block?
		JR	NZ,LAB_1C95
		LD	A,(LAB_709D)
		AND	A			; Is the blocknr 0 (extra check)?
		JR	NZ,LAB_1C95
		CALL	FUN_1D9C		; Verify checksum block data
		JR	NZ,LAB_1C95
		CALL	FUN_1D84		; Display filename and verify checksum
		LD	A,(LAB_71B0)		; Load filename length
		AND	A			; Is a filename specified?

		; Start verify filename
		JR	Z,LAB_1CCD		; If not specified, skip check
		LD	B,A
		LD	HL,LAB_71B1
		LD	A,(LAB_70A8)
		CP	B
		JR	NZ,WRONG_FILE		; Not the same length
		LD	DE,LAB_70A9
LAB_1CC5:	LD	A,(DE)
		CP	(HL)
		JR	NZ,WRONG_FILE		; Not the same name
		INC	HL
		INC	DE
		DJNZ	LAB_1CC5
		; End verify filename

LAB_1CCD:	LD	A,(LAB_709F)
		LD	HL,LAB_71A9		; 'M'achine or 'B'asic ?
		CP	(HL)
		JR	NZ,WRONG_FILE		; Not the right filetype
LAB_1CE0:	LD	HL,(LAB_709B)		; Get the file size from tape
		; Added check max file size
		LD	DE,(LAB_71C9)		; Max file size
		AND	A
		SBC	HL,DE
		JR	C,_endMaxSize		
		LD	DE,(LAB_709B)		; Save actual size if smaller than max size
		LD	(LAB_71C9),DE
_endMaxSize:	LD	(LAB_71AC),DE
		LD	A,(LAB_709E)		; Get last blocknr from tape
		LD	(LAB_71C4),A
		LD	HL,(LAB_71C7)
		LD	(LAB_71AA),HL		; Set destination address
		RET

; Load file data from tape
FUN_1CF6:	LD	B,$10			; Counter
		LD	A,$FF			; Value
		LD	HL,LAB_71B1		; Destination
LAB_1CFD:	LD	(HL),A			; Fill destination with 16 x FF
		INC	HL
		DJNZ	LAB_1CFD
		XOR 	A
		LD	(LAB_71C5),A		; End load data flag
		LD	(LAB_71C2),A		; Block number
		LD	A,$44			; Data block id
		LD	(LAB_71C1),A
LAB_1D0D:	LD	HL,LAB_71C2
		INC	(HL)
		CALL	FUN_1D1C		; Load data block from tape

		; Added progress indicator
		LD	A,'.'
		RST	R_dspChar

		LD	A,(LAB_71C5)
		CP	$FE			; End load data? 
		JR	NZ,LAB_1D0D
		RET

; Load data block from tape
FUN_1D1C:	CALL	FUN_1D78		; load block from tape
		LD	A,(LAB_7098)
		LD	HL,LAB_71C1
		CP	(HL)			; is it a data block?
		JR	Z,LAB_1D31
		LD	HL,LAB_71CB
		CP	(HL)
		JP	NZ,LAB_1B8C		; tape error
		JR	FUN_1D1C

; process loaded data block:
; verify integrity of the data
; if ok then copy data to destination else tape error
LAB_1D31:	LD	HL,LAB_709E
		LD	A,(LAB_71C4)
		CP	(HL)
		JP	NZ,LAB_1B8C		; tape error
		LD	HL,LAB_71C2
		LD	A,(LAB_709E)
		CP	(HL)
		JR	NZ,LAB_1D49
		LD	A,$FE
		LD	(LAB_71C5),A
LAB_1D49:	LD	A,(HL)
		LD	HL,LAB_709D
		CP	(HL)
		JR	Z,LAB_1D52
		JR	C,FUN_1D1C
LAB_1D52:	CALL	FUN_1D9C		; verify checksum
		JR	Z,LAB_1D5A
		JP	LAB_1B8C		; tape error

; Copy loaded data to destination
LAB_1D5A:	LD	BC,(LAB_709B)
		LD	HL,LAB_70A8
		LD	DE,(LAB_71AA)
		LDIR
		LD	(LAB_71AA),DE
		LD	A,$99
		RET

; Read block from tape
FUN_1D78:	LD	BC,$0110		; Block length
		LD	HL,LAB_7098		; Buffer address
		CALL	FUN_1E2A
		RET	Z
		JR	FUN_1D78

; Verify checksum block data
FUN_1D9C:	CALL	FUN_1BC2		; Calculate checksum
		LD	HL,(LAB_7099)		; Get stored checksum
		XOR	A
		SBC	HL,DE			; Do the checksums match?
		RET

; Read data from tape (same code as BIT90 BASIC)
FUN_1E2A:	PUSH	HL
		PUSH	BC
LAB_1E2C:	LD	B,$18
LAB_1E2E:	CALL	FUN_1EF0
		LD	L,A
		CALL	FUN_1EF0
		ADD	A,L
		LD	C,A
		CP	$10
		JR	C,LAB_1E2C
		CP	$80
		JR	NC,LAB_1E2C
		SUB	H
		JR	NC,LAB_1E44
		NEG
LAB_1E44:	CP	$06
		LD	H,C
		JR	NC,LAB_1E2C
		DJNZ	LAB_1E2E
		LD	D,$00
		CALL	FUN_1EF0
		CALL	FUN_1EF0
		LD	B,A
		CALL	FUN_1EF0
		SUB	B
		JR	NC,LAB_1E5C
		NEG
LAB_1E5C:	PUSH	AF
		LD	D,$FF
		CALL	FUN_1EF0
		CALL	FUN_1EF0
		LD	B,A
		CALL	FUN_1EF0
		SUB	B
		JR	NC,LAB_1E6E
		NEG
LAB_1E6E:	POP	HL
		CP	H
		JR	NC,LAB_1E77
		LD	D,$00
		CALL	FUN_1EF0
LAB_1E77:	CALL	FUN_1EF0
		LD	L,A
		CALL	FUN_1EF0
		ADD	A,L
		SRL	A
		LD	C,A
LAB_1E82:	CALL	FUN_1EF0
		JR	NC,LAB_1E82
		LD	B,$18
LAB_1E89:	CALL	FUN_1EF0
		JR	C,LAB_1E2C
		CALL	FUN_1EF0
		JR	NC,LAB_1E2C
		DJNZ	LAB_1E89
		LD	L,A
		CALL	FUN_1EF0
		ADD	A,L
		SRL	A
		ADD	A,$01
		LD	C,A
		LD	L,$FF
LAB_1EA1:	LD	B,$04
LAB_1EA3:	CALL	FUN_1EF0
		EX	AF,AF'
		DEC	L
		JP	Z,LAB_1E2C
		EX	AF,AF'
		JR	NC,LAB_1EA1
		DJNZ	LAB_1EA3
LAB_1EB0:	CALL	FUN_1EF0
		JR	C,LAB_1EB0
LAB_1EB5:	CALL	FUN_1EF0
		JR	NC,LAB_1EB5
		EXX
		POP	BC
		EXX
		POP	HL
		CALL	FUN_1EDC
		CP	$C7
		JP	NZ,FUN_1E2A
		CALL	FUN_1EDC
		CP	$F1
		JP	NZ,FUN_1E2A
LAB_1ECE:	CALL	FUN_1EDC
		LD	(HL),A
		RET	NC
		INC	HL
		EXX
		DEC	BC
		LD	A,B
		OR	C
		EXX
		JR	NZ,LAB_1ECE
		RET

FUN_1EDC:	CALL	FUN_1EF0
		RET	NC
		LD	B,$08
		PUSH	HL
LAB_1EE3:	CALL	FUN_1EF0
		RR	H
		DJNZ	LAB_1EE3
		CALL	FUN_1EF0
		LD	A,H
		POP	HL
		RET

FUN_1EF0:	IN	A,(IOTAP1)		; Read tape port
		XOR	D
		JP	M,FUN_1EF0
		LD	E,$00
LAB_1EF8:	INC	E
		IN	A,(IOTAP1)
		XOR	D
		JP	P,LAB_1EF8
		LD	A,E
		CP	C
		RET
		
; Error handling in BBC BASIC wrapper module
LAB_1B8C:	CALL	bbxNMIenable
		JP	TAPE_ERR


; ------------------------------------------------------------------------------
; BIT90 Specific part of the console initialization
; (bit90: $32AF with modifications)
; ------------------------------------------------------------------------------
INIT_32AF:	; Sound off
		LD	A,$9F
		OUT	(IOPSG0),A
		LD	A,$BF
		OUT	(IOPSG0),A
		LD	A,$DF
		OUT	(IOPSG0),A
		LD	A,$FF
		OUT	(IOPSG0),A

		; VDP initialization
		IN	A,(IOVDP1)		; Read VDP register 0
		LD	A,(VDPINITR0)
		LD	(VDPR0_7014),A
		LD	A,(VDPINITR1)
		LD	(VDPR1_7015),A
		LD	B,$10
		LD	C,IOVDP1
		LD	HL,VDPINITR0
		OTIR				; Initialize VDP register 0 to 7
		RET

; --------------------------------------------------------
; GETKEY routine 
; (bit90: $3330 with modifications)
; --------------------------------------------------------
GETKEY_3330:	PUSH	BC
		PUSH	DE
		PUSH	HL
		LD	HL,bbxFLSCUR
		INC	(HL)
		CALL	KEYSCAN_3405
		LD	B,E
		LD	C,A
		CALL	FUN_345C
		CALL	KEYSCAN_3405
		JR	NC,LAB_337F
		CP	C
		JR	NZ,LAB_337F
		LD	HL,SCANCODES
		LD	B,$00
		LD	C,A
		ADD	HL,BC
		LD	B,(HL)
		LD	A,B
		CP	$7F
		JR	NC,LAB_3382
		LD	A,E
		CP	$02			; Control key pressed
		JR	Z,LAB_33B9
		CP	$05			; Basic key presses
		JR	Z,LAB_33CC
		CP	$07			; FCTN key pressed
		JR	Z,LAB_33DA		
		AND	A
		LD	A,C
		JR	NZ,LAB_3376
		CP	$25
		JR	NZ,LAB_336F
		XOR	A
		LD	(CAPSKEY_7016),A
		JR	LAB_337F

LAB_336F:	CALL	LAB_3396
		JR	NC,LAB_33A3
		JR	LAB_33D5

LAB_3376:	CP	$25
		JR	NZ,LAB_3382
		LD	A,$20
		LD	(CAPSKEY_7016),A

LAB_337F:	AND	A
		JR	LAB_33D6

LAB_3382:	CALL	LAB_3396
		JR	NC,LAB_33D5
		LD	HL,CAPSKEY_7016
		OR	(HL)
IFDEF BIT90
		LD	HL,LAB_7017		; Graphics key characters not implemented
		BIT	6,(HL)
		JR	Z,LAB_33D5
		OR	$20
ENDIF

		JR	LAB_33D5

LAB_3396:	LD	A,B
		CP	'A'
		JR	C,LAB_33A1
		CP	'Z'+1
		JR	NC,LAB_33A1
		SCF
		RET
LAB_33A1:	AND	A
		RET

LAB_33A3:	CP	'A'
		JR	NC,LAB_33B1
		CP	'@'
		JR	C,LAB_33B5
		JR	NZ,LAB_337F
		LD	A,'_'
		JR	LAB_33D5

LAB_33B1:	XOR	$20
		JR	LAB_33D5

LAB_33B5:	XOR	$10
		JR	LAB_33D5

LAB_33B9:	LD	A,B
		CP	$2C
		JR	C,LAB_33D5
		CP	$60
		JR	NC,LAB_33D5
		CP	$30
		JR	NC,LAB_33C8
		XOR	$10
LAB_33C8:	ADD	A,$50
		JR	LAB_33D5

LAB_33CC:	CALL	LAB_3396
		JR	NC,LAB_33D5
		RES	6,A
		JR	LAB_33D5

LAB_33D5:	SCF
LAB_33D6:	POP	HL
		POP	DE
		POP	BC
		RET

; Function key pressed
LAB_33DA:	LD	A,B
		CP	$30
		JR	C,LAB_33D5
		CP	$3A
		JR	NC,LAB_33D5
		ADD	A,$B0
IFDEF BIT90
		CP	$E0			; In the BIT90 pressing FCTN+0 will try to jump to
		JR	Z,LAB_33EB		; the ROM address $4000 (expansion module)
		JR	LAB_33D5
LAB_33EB:
ELSE
		JR	LAB_33D5
ENDIF
		
; -------------------------------------------------------
; KEYSCAN - Keyboard I/O
; (bit90: $3405)
; -------------------------------------------------------
KEYSCAN_3405:	PUSH	BC
		LD	E,$0F
		LD	B,$07
LAB_340A:	LD	A,B
		RLCA
		RLCA
		RLCA
		RLCA
		OUT	(IOKEY0),A
		IN	A,(IOKEY1)
		CP	$FF
		JR	NZ,LAB_341D
LAB_3417:	DEC	B
		JP	P,LAB_340A
		JR	LAB_3423

LAB_341D:	LD	D,A
		CALL	FUN_3428
		JR	LAB_3417

LAB_3423:	LD	A,$FF
		AND	A
		POP	BC
		RET

FUN_3428:	LD	C,$07
		LD	A,D
LAB_342B:	RLA
		JR	NC,LAB_3435
		DEC	C
		JP	P,LAB_342B
		POP	HL
		JR	LAB_3423

LAB_3435:	LD	A,B
		CP	$07
		JR	NZ,LAB_344D
		LD	A,C
		CP	$01
		JR	Z,LAB_344D
		CP	$03
		JR	Z,LAB_344D
		CP	$04
		JR	Z,LAB_344D
		CP	$06
		JR	Z,LAB_344D
		LD	E,A
		RET

LAB_344D:	POP	HL
		LD	A,B
		AND	$07
		RLCA
		RLCA
		RLCA
		LD	B,A
		LD	A,C
		AND	$07
		OR	B
		SCF
		POP	BC
		RET

FUN_345C:	PUSH	BC
		PUSH	HL
		PUSH	AF
		LD	BC,$0300
LAB_3462:	CPI
		JP	PE,LAB_3462
		POP	AF
		POP	HL
		POP	BC
		RET

; -------------------
; *** Static Data ***
; -------------------

; VDP Registers (bit90: $3EEE with modifications)
VDPINITR0:	DB	$02,$80		; ------10: Set mode bit 3 (graphics 2 mode), Disable external VDP input 
VDPINITR1:	DB	$C0,$81		; 11000-00: Select 4416 ram, enable display, disable interrupt, graphics 2 mode,
					;           sprite size 0 (8x8), magnification 1x 
VDPINITR2:	DB	$06,$82		; Base address nametable $1800
VDPINITR3:	DB	$FF,$83		; Base address colortable $3FC0 (?)
VDPINITR4:	DB	$03,$84		; Base address patterns $0000
VDPINITR5:	DB	$78,$85		; Base address sprite attributes $3C00
VDPINITR6:	DB	$07,$86		; Base address sprite patterns $3800
VDPINITR7:	DB	$01,$87		; ----0001: Backdrop color ($01=black, $0C=green)

; Keyboard scancode (bit90: $36A0)
SCANCODES:	DB	$2D,$37,$33,$5C,$F5,$31,$35,$39
		DB	$5E,$38,$34,$08,$F4,$32,$36,$30
		DB	$50,$59,$57,$5D,$F0,$1B,$52,$49
		DB	$5B,$55,$45,$7F,$F3,$51,$54,$4F
		DB	$3B,$48,$53,$40,$2F,$00,$46,$4B
		DB	$3A,$4A,$44,$0D,$2E,$41,$47,$4C
		DB	$4E,$56,$58,$4D,$2C,$5A,$43,$42
		DB	$00,$F7,$00,$F2,$F1,$00,$20,$00



; --------------------------------------------------
; *** Mandatory code at the end of the BIT90 ROM ***
; --------------------------------------------------

		SECTION	BIT90VEC 

IFDEF BBX80ROM
		ORG	$3FD8
ENDIF


		PUBLIC	BYE_3FB1
		PUBLIC	BAS_3FB8
		PUBLIC	INIT_3FBB

		EXTERN	bbxNMIdisable
		EXTERN	initConsole

; ------------------------------------------------------------------------------
; BYE - Exit BASIC and reboot machine with banked Game ROM
; (bit90: $3FB1 with modifications)
; ------------------------------------------------------------------------------
BYE_3FB1:	CALL	bbxNMIdisable
		XOR	A			; Command "BYE" / exit BASIC
		LD	($8000),A		; $8000 = Game rom identifier ($AA $55)
		IN	A,(IOROM0)			; Switch Mem bank to Coleco ROM
		RST	$00			; Reboot

; ------------------------------------------------------------------------------
; BAS - Exit Game and reboot machine with banked BASIC ROM
; (bit90: $3FB8 relocated)
; ------------------------------------------------------------------------------
BAS_3FB8:	IN	A,(IOROM1)		; Switch mem bank to BASIC ROM
		RST	$00			; Reboot

; ------------------------------------------------------------------------------
; INIT - Initialize command mode
; (bit90: $3FBB modified)
; ------------------------------------------------------------------------------
INIT_3FBB:	PUSH	HL
		CALL	INIT_32AF
		CALL	initConsole
		POP	HL
		RET

; ------------------------------------------------------------------------------
; Mandatory vectors
; ------------------------------------------------------------------------------

LAB_3FEE:	JP	SHOWDSP_3FD4
LAB_3FF1:	JP	HIDEDSP_3FDD
LAB_3FF4:	JP	SETMOD_252B
LAB_3FF7:	JP	KEYSCAN_3405
LAB_3FFA:	JP	INIT_3FBB
LAB_3FFD:	JP	BAS_3FB8		; Address called from Game ROM


; ------------------------------------
; *** RAM for BIT90 host variables ***
; ------------------------------------

		SECTION BIT90RAM

		PUBLIC	VDPR0_7014
		PUBLIC	VDPR1_7015
		PUBLIC	CAPSKEY_7016
		PUBLIC	TAPE_VAR

		
VDPR0_7014:	DB	0		; Copy of VDP register 0 value
VDPR1_7015:	DB	0		; Copy of VDP register 1 value
CAPSKEY_7016:	DB	0		; Used by GETKEY

; BSAVE / BLOAD (bit90: $7098, the variables must be in consecutive addresses)
; The space can be re-used for variables in functions that don't use console or tape routines
; Total 16 + 256 + 36 = 308 bytes

TAPE_VAR:				; Tape: control record 7098 to 70A7
LAB_7098:	DB	0		; Tape: Header is $42 Data is $44		
LAB_7099:	DB	0,0		; Tape:	Checksum
LAB_709B:	DB	0,0		; Tape: number of data bytes in block	(Header: filesize)
LAB_709D:	DB	0		; Tape: block number
LAB_709E:	DB	0		; Tape: last block number
LAB_709F:	DB	0		; Tape: file type (M or B)
LAB_70A0:	DB	0,0		; Tape: address origin (for M type)
		DS	6,0		; Tape: ? same values in every block
LAB_70A8:	DB	0		; Tape: data record 256 bytes		(Header: length of filename)
LAB_70A9:	DS	$FF,0		; Tape: data				(Header: filename)
LAB_71A8:	DB	0
LAB_71A9:	DB	0
LAB_71AA:	DB	0,0
LAB_71AC:	DB	0,0,0,0
LAB_71B0:	DB	0
LAB_71B1:	DS	$0B,0
LAB_71BC:	DB	0,0
LAB_71BE:	DB	0,0,0
LAB_71C1:	DB	0
LAB_71C2:	DB	0,0
LAB_71C4:	DB	0
LAB_71C5:	DB	0,0
LAB_71C7:	DB	0,0		; Start address of data to save/load
LAB_71C9:	DB	0,0		; File length (in bytes)
LAB_71CB:	DB	0
