; ------------------------------------------------------------------------------
; CP/M host v1.1
;
; This module contains specific CP/M routines.
; It is based on the code in the bbc basic cmos.z80 file.
; The code is restructured into OS functions and lower level BDOS calls.
; MSX BDOS deviations from CP/M are handled via the directive MSXDOS.
; ------------------------------------------------------------------------------

		SECTION CPMHOST

		INCLUDE	"bbx80.inc"
		INCLUDE "console.inc"

		PUBLIC	bbxDosOpen
		PUBLIC	bbxDosShut
		PUBLIC	bbxDosBget
		PUBLIC	bbxDosBput
		PUBLIC	bbxDosStat
		PUBLIC	bbxDosGetext
		PUBLIC	bbxDosGetPtr
		PUBLIC	bbxDosPutPtr
		PUBLIC	bbxDosReset
		PUBLIC	bbxDosCall
		PUBLIC	bbxDosDot
		PUBLIC	bbxDosDir
		PUBLIC	bbxDosExecIn

		PUBLIC	bbxHostInit
		PUBLIC	bbxHostExit
		PUBLIC	bbxDosType
		PUBLIC	bbxDosOpt
		PUBLIC	bbxDosResDisk
		PUBLIC	bbxDosDrive
		PUBLIC	bbxDosErase
		PUBLIC	bbxDosRename
		PUBLIC	bbxDosEscCtl
		PUBLIC	bbxDosExec
		PUBLIC	bbxDosSpool
		PUBLIC	bbxHostBsave
		PUBLIC	bbxHostSave
		PUBLIC	bbxHostBload
		PUBLIC	bbxHostLoad

		PUBLIC	dosOutChar
		PUBLIC	dosGetKey

		; basic
		EXTERN	EXTERR
		EXTERN	UPPRC
		EXTERN	OSBPUT
		EXTERN	SKIPSP
		EXTERN	HUH
		EXTERN	HEX
		EXTERN	LTRAP
		EXTERN	FLAGS
		EXTERN	ACCS
		EXTERN	CRLF
		EXTERN	OSWRCH
		EXTERN	CPTEXT
		EXTERN	SPTEXT
		EXTERN	FREE
		EXTERN	CLOSE
		EXTERN	CHECK
		EXTERN	HIMEM
		EXTERN	OSBGET
		EXTERN	OSOPEN
		EXTERN	OSSHUT
		EXTERN	ABORT

; ------------------------------------------------------------------------------
; OSSAVE - Save an area of memory to a file.
;   Inputs: HL = addresses filename (term CR)
;           DE = start address of data to save
;           BC = length of data to save (bytes)
; Destroys: A,B,C,D,E,H,L,F
; ------------------------------------------------------------------------------
bbxHostBsave:	CALL	SAVLOD		;*SAVE
		JP	C,HUH		;"Bad command"
		PUSH	HL
		JR	OSS1

bbxHostSave:	PUSH	BC		;SAVE
		CALL	SETUP0
OSS1:		EX	DE,HL
		CALL	dosFcreate
		JR	NZ,SAVE
DIRFUL:		LD	A,190
		CALL	EXTERR
		DEFM	"Directory full"
		DEFB	0
SAVE:		CALL	dosWrite
		ADD	HL,BC
		EX	(SP),HL
		SBC	HL,BC
		EX	(SP),HL
		JR	Z,SAVE1
		JR	NC,SAVE
SAVE1:		POP	BC
CLOSE:		JP	dosFclose

; ------------------------------------------------------------------------------
; OSSHUT - Close disk file(s).
;   Inputs: E = file channel
;           If E=0 all files are closed (except SPOOL)
; Destroys: A,B,C,D,E,H,L,F
; ------------------------------------------------------------------------------
bbxDosShut:	LD	A,E
		OR	A
		JR	NZ,SHUT1
SHUT0:		INC	E
		BIT	3,E
		RET	NZ
		PUSH	DE
		CALL	SHUT1
		POP	DE
		JR	SHUT0

SESHUT:		LD	HL,FLAGS
		RES	0,(HL)		;STOP EXEC
		RES	1,(HL)		;STOP SPOOL
		LD	E,8		;SPOOL/EXEC CHANNEL
SHUT1:		CALL	FIND1
		RET	Z
		XOR	A
		LD	(HL),A
		DEC	HL
		LD	(HL),A
		LD	HL,37
		ADD	HL,DE
		BIT	7,(HL)
		INC	HL
		CALL	NZ,dosWrite
		LD	HL,FCBSIZ
		ADD	HL,DE
		LD	BC,(FREE)
		SBC	HL,BC
		JP	NZ,CLOSE
		LD	(FREE),DE	;RELEASE SPACE
		JP	CLOSE

; ------------------------------------------------------------------------------
; TYPE - *TYPE command.
; Types file to console output.
; ------------------------------------------------------------------------------
bbxDosType:	SCF			;*TYPE
		CALL	OSOPEN
		OR	A
		JP	Z,NOTFND
		LD	E,A
TYPE1:		LD	A,(FLAGS)	;TEST
		BIT	7,A		;FOR
		JR	NZ,TYPESC	;ESCape
		CALL	OSBGET
		CALL	OSWRCH		;N.B. CALLS "TEST"
		JR	NC,TYPE1
		JP	OSSHUT

TYPESC:		CALL	OSSHUT		;CLOSE!
		JP	ABORT

; ------------------------------------------------------------------------------
; OSLOAD - Load an area of memory from a file.
;   Inputs: HL addresses filename (term CR)
;           DE = address at which to load
;           BC = maximum allowed size (bytes)
;  Outputs: Carry reset indicates no room for file.
; Destroys: A,B,C,D,E,H,L,F
; ------------------------------------------------------------------------------
bbxHostBload:	CALL	SAVLOD		;*LOAD
		PUSH	HL
		JR	OSL1

bbxHostLoad:	PUSH	BC		;LOAD
		CALL	SETUP0
OSL1:		EX	DE,HL
		CALL	dosFopen
		JR	NZ,LOAD0
NOTFND:		LD	A,214
		CALL	EXTERR
		DEFM	"File not found"
		DEFB	0
LOAD:		CALL	dosRead
		JR	NZ,LOAD1
		CALL	dosIncRec
		ADD	HL,BC
LOAD0:		EX	(SP),HL
		SBC	HL,BC
		EX	(SP),HL
		JR	NC,LOAD
LOAD1:		POP	BC
		PUSH	AF
		CALL	CLOSE
		POP	AF
		CCF
bbxDosCall:	RET

; ------------------------------------------------------------------------------
; OSOPEN - Open a file for reading or writing.
;   Inputs: HL addresses filename (term CR)
;           Carry set for OPENIN, cleared for OPENOUT.
;  Outputs: A = file channel (=0 if cannot open)
;           DE = file FCB
; Destroys: A,B,C,D,E,H,L,F
; ------------------------------------------------------------------------------
OPENIT:		PUSH	AF		;SAVE CARRY
		CALL	SETUP0
		POP	AF
		CALL	NC,dosFcreate
		CALL	C,dosFopen
		RET

bbxDosOpen:	CALL	OPENIT
		RET	Z		;ERROR
		LD	B,7		;MAX. NUMBER OF FILES
		LD	HL,TABLE+15
OPEN1:		LD	A,(HL)
		DEC	HL
		OR	(HL)
		JR	Z,OPEN2		;FREE CHANNEL
		DEC	HL
		DJNZ	OPEN1
		LD	A,192
		CALL	EXTERR
		DEFM	"Too many open files"
		DEFB	0

OPEN2:		LD	DE,(FREE)	;FREE SPACE POINTER
		LD	(HL),E
		INC	HL
		LD	(HL),D
		LD	A,B		;CHANNEL (1-7)
		LD	HL,FCBSIZ
		ADD	HL,DE		;RESERVE SPACE
		LD	(FREE),HL
OPEN3:		LD	HL,FCB		;ENTRY FROM SPOOL/EXEC
		PUSH	DE
		LD	BC,36
		LDIR			;COPY FCB
		EX	DE,HL
		INC	HL
		LD	(HL),C		;CLEAR PTR
		INC	HL
		POP	DE
		LD	B,A
		CALL	dosReadFill	
		LD	A,B
		JP	CHECK

; ------------------------------------------------------------------------------
; OSBPUT - Write a byte to a random disk file.
;   Inputs: E = file channel
;           A = byte to write
; Destroys: A,B,C,F
; ------------------------------------------------------------------------------
bbxDosBput:	PUSH	DE
		PUSH	HL
		LD	B,A
		CALL	FIND
		LD	A,B
		LD	B,0
		DEC	HL
		LD	(HL),B		;CLEAR EOF
		INC	HL
		LD	C,(HL)
		RES	7,C
		SET	7,(HL)
		INC	(HL)
		INC	HL
		PUSH	HL
		ADD	HL,BC
		LD	(HL),A
		POP	HL
		CALL	Z,dosWriteFill	
		POP	HL
		POP	DE
		RET

; ------------------------------------------------------------------------------
; OSBGET - Read a byte from a random disk file.
;   Inputs: E = file channel
;  Outputs: A = byte read
;           Carry set if LAST BYTE of file
; Destroys: A,B,C,F
; ------------------------------------------------------------------------------
bbxDosBget:	PUSH	DE
		PUSH	HL
		CALL	FIND
		LD	C,(HL)
		RES	7,C
		INC	(HL)
		INC	HL
		PUSH	HL
		LD	B,0
		ADD	HL,BC
		LD	B,(HL)
		POP	HL
		CALL	PE,dosIncRecFill
		CALL	Z,dosWriteFill
		LD	A,B
		POP	HL
		POP	DE
		RET

; ------------------------------------------------------------------------------
; OSSTAT - Read file status.
;   Inputs: E = file channel
;  Outputs: Z flag set - EOF
;           (If Z then A=0)
;           DE = address of file block.
; Destroys: A,D,E,H,L,F
; ------------------------------------------------------------------------------
bbxDosStat:	CALL	FIND
		DEC	HL
		LD	A,(HL)
		INC	A
		RET

; ------------------------------------------------------------------------------
; GETEXT - Find file size.
;   Inputs: E = file channel
;  Outputs: DEHL = file size (0-&800000)
; Destroys: A,B,C,D,E,H,L,F
; ------------------------------------------------------------------------------
bbxDosGetext:	CALL	FIND
		EX	DE,HL
		LD	DE,FCB
		LD	BC,36
		PUSH	DE
		LDIR			;COPY FCB
		EX	DE,HL
		EX	(SP),HL
		EX	DE,HL
		CALL	dosFsize
		POP	HL
		XOR	A
		JR	GETPT1

; ------------------------------------------------------------------------------
; GETPTR - Return file pointer.
;   Inputs: E = file channel
;  Outputs: DEHL = pointer (0-&7FFFFF)
; Destroys: A,B,C,D,E,H,L,F
; ------------------------------------------------------------------------------
bbxDosGetPtr:	CALL	FIND
		LD	A,(HL)
		ADD	A,A
		DEC	HL
GETPT1:		DEC	HL
		LD	D,(HL)
		DEC	HL
		LD	E,(HL)
		DEC	HL
		LD	H,(HL)
		LD	L,A
		SRL	D
		RR	E
		RR	H
		RR	L
		RET

; ------------------------------------------------------------------------------
; PUTPTR - Update file pointer.
;   Inputs: A = file channel
;           DEHL = new pointer (0-&7FFFFF)
; Destroys: A,B,C,D,E,H,L,F
; ------------------------------------------------------------------------------
bbxDosPutPtr:	LD	D,L
		ADD	HL,HL
		RL	E
		LD	B,E
		LD	C,H
		LD	E,A		;CHANNEL
		PUSH	DE
		CALL	FIND
		POP	AF
		AND	7FH
		BIT	7,(HL)		;PENDING WRITE?
		JR	Z,PUTPT1
		OR	80H
PUTPT1:		LD	(HL),A
		PUSH	DE
		PUSH	HL
		DEC	HL
		DEC	HL
		DEC	HL
		LD	D,(HL)
		DEC	HL
		LD	E,(HL)
		EX	DE,HL
		OR	A
		SBC	HL,BC
		POP	HL
		POP	DE
		RET	Z
		INC	HL
		OR	A
		CALL	M,dosWrite
		PUSH	HL
		DEC	HL
		DEC	HL
		DEC	HL
		LD	(HL),0
		DEC	HL
		LD	(HL),B
		DEC	HL
		LD	(HL),C		;NEW RECORD NO.
		POP	HL
		JP	dosReadFill

; ------------------------------------------------------------------------------
; WRRDF - Write, read; if EOF fill with zeroes.
; RDF - Read; if EOF fill with zeroes.
;   Inputs: DE address FCB.
;           HL addresses data buffer.
;  Outputs: A=0, Z-flag set.
;           Carry set if fill done (EOF)
; Destroys: A,H,L,F
; ------------------------------------------------------------------------------
dosWriteFill:	CALL	dosWrite
dosReadFill:	CALL	dosRead
		DEC	HL
		RES	7,(HL)
		DEC	HL
		LD	(HL),A		;CLEAR EOF FLAG
		RET	Z
		LD	(HL),-1		;SET EOF FLAG
		INC	HL
		INC	HL
		PUSH	BC
		XOR	A
		LD	B,128
FILL:		LD	(HL),A
		INC	HL
		DJNZ	FILL
		POP	BC
		SCF
		RET

; ------------------------------------------------------------------------------
; INCRDF - Increment record, read; if EOF fill.
;   Inputs: DE addresses FCB.
;           HL addresses data buffer.
;  Outputs: A=1, Z-flag reset.
;           Carry set if fill done (EOF)
; Destroys: A,H,L,F
; ------------------------------------------------------------------------------
dosIncRecFill:	CALL	dosIncRec
		CALL	dosReadFill
		INC	A
		RET

; ------------------------------------------------------------------------------
; Subroutine: Read a record from a disk file.
; Parameters: DE addresses FCB.
;             HL = address to store data.
; Returns   : A<>0 & Z-flag reset indicates EOF.
;             Carry = 0
; Destroys  : A,F
; ------------------------------------------------------------------------------
dosRead:	CALL	dosSetDMA
		LD	A,33
		JR	BDOS1

; ------------------------------------------------------------------------------
; Subroutine: CP/M BDOS call.
; Parameters: A = function number
;             DE = parameter
; Returns   : AF = result (carry=0)
; Destroys  : A,F
; ------------------------------------------------------------------------------
BDOS1:		CALL	BDOS0		;*
		JR	NZ,CPMERR	;*
		OR	A		;*
		RET			;*
CPMERR:		LD	A,255		;* CP/M 3
		CALL	EXTERR		;* BDOS ERROR
		DEFM	"CP/M Error"	;*
		DEFB	0		;*

BDOS0:		PUSH	BC
		PUSH	DE
		PUSH	HL
		PUSH	IX
		PUSH	IY
IFDEF MSXDOS
		EXX
		PUSH	BC
		PUSH	DE
		PUSH	HL
		EXX
ENDIF
		LD	C,A
		CALL	BDOS
		INC	H		;* TEST H
		DEC	H		;* CP/M 3 ONLY
IFDEF MSXDOS
		EXX
		POP	HL
		POP	DE
		POP	BC
		EXX
ENDIF
		POP	IY
		POP	IX
		POP	HL
		POP	DE
		POP	BC
		RET

; ------------------------------------------------------------------------------
; WRITE - Write a record to a disk file.
;   Inputs: DE addresses FCB.
;           HL = address to get data.
; Destroys: A,F
; ------------------------------------------------------------------------------
dosWrite:	CALL	dosSetDMA
		LD	A,40
		CALL	BDOS1
		JR	Z,dosIncRec
		LD	A,198
		CALL	EXTERR
		DEFM	"Disk full"
		DEFB	0

; ------------------------------------------------------------------------------
; INCSEC - Increment random record number.
;   Inputs: DE addresses FCB.
; Destroys: F
; ------------------------------------------------------------------------------
dosIncRec:	PUSH	HL
		LD	HL,33
		ADD	HL,DE
INCS1:		INC	(HL)
		INC	HL
		JR	Z,INCS1
		POP	HL
		RET

; ------------------------------------------------------------------------------
; OPEN - Open a file for access.
;   Inputs: FCB set up.
;  Outputs: DE = FCB
;           A=0 & Z-flag set indicates Not Found.
;           Carry = 0
; Destroys: A,D,E,F
; ------------------------------------------------------------------------------
dosFopen:	LD	DE,FCB
		LD	A,15
		CALL	BDOS1
		INC	A
		RET

; ------------------------------------------------------------------------------
; CREATE - Create a disk file for writing.
;   Inputs: FCB set up.
;  Outputs: DE = FCB
;           A=0 & Z-flag set indicates directory full.
;           Carry = 0
; Destroys: A,D,E,F
; ------------------------------------------------------------------------------
dosFcreate:	CALL	CHKAMB
		LD	DE,FCB
		LD	A,19
		CALL	BDOS1		; DELETE
		LD	A,22
		CALL	BDOS1		; MAKE
		INC	A
		RET

; ------------------------------------------------------------------------------
; CHKAMB - Check for ambiguous filename.
; Destroys: A,D,E,F
; ------------------------------------------------------------------------------
CHKAMB:		PUSH	BC
		LD	DE,FCB
		LD	B,12
CHKAM1:		LD	A,(DE)
		CP	'?'
		JR	Z,AMBIG		;AMBIGUOUS
		INC	DE
		DJNZ	CHKAM1
		POP	BC
		RET
AMBIG:		LD	A,204
		CALL	EXTERR
		DEFM	"Bad name"
		DEFB	0

; ------------------------------------------------------------------------------
; Subroutine: Set "DMA" address.
; Parameters: HL = address
; ------------------------------------------------------------------------------
dosSetDMA:	LD	A,26
		EX	DE,HL
		CALL	BDOS0
		EX	DE,HL
		RET

; ------------------------------------------------------------------------------
;FIND - Find file parameters from channel.
;   Inputs: E = channel
;  Outputs: DE addresses FCB
;           HL addresses pointer byte (FCB+37)
; Destroys: A,D,E,H,L,F
; ------------------------------------------------------------------------------
FIND:		CALL	FIND1
		LD	HL,37
		ADD	HL,DE
		RET	NZ
		LD	A,222
		CALL	EXTERR
		DEFM	"Channel"
		DEFB	0

; ------------------------------------------------------------------------------
; FIND1 - Look up file table.
;   Inputs: E = channel
;  Outputs: Z-flag set = file not opened
;           If NZ, DE addresses FCB
;                  HL points into table
; Destroys: A,D,E,H,L,F
; ------------------------------------------------------------------------------
FIND1:		LD	A,E
		AND	7
		ADD	A,A
		LD	E,A
		LD	D,0
		LD	HL,TABLE
		ADD	HL,DE
		LD	E,(HL)
		INC	HL
		LD	D,(HL)
		LD	A,D
		OR	E
		RET

; ------------------------------------------------------------------------------
; SETUP - Set up File Control Block.
;   Inputs: HL addresses filename
;           Format  [A:]FILENAME[.EXT]
;           Device defaults to current drive
;           Extension defaults to .BBC
;           A = fill character
;  Outputs: HL updated
;           A = terminator
;           BC = 128
; Destroys: A,B,C,H,L,F
; ------------------------------------------------------------------------------
; FCB FORMAT (36 BYTES TOTAL):
; 0      0=SAME DISK, 1=DISK A, 2=DISK B (ETC.)
; 1-8    FILENAME, PADDED WITH SPACES
; 9-11   EXTENSION, PADDED WITH SPACES
; 12     CURRENT EXTENT, SET TO ZERO
; 32-35  CLEARED TO ZERO
; ------------------------------------------------------------------------------
SETUP0:		LD	A,' '
SETUP:		PUSH	DE
		PUSH	HL
		LD	DE,FCB+9
		LD	HL,BBC
		LD	BC,3
		LDIR
		LD	HL,FCB+32
		LD	B,4
SETUP1:		LD	(HL),C
		INC	HL
		DJNZ	SETUP1
		POP	HL
		LD	C,A
		XOR	A
		LD	(DE),A
		POP	DE
		CALL	SKIPSP
		CP	'"'
		JR	NZ,SETUP2
		INC	HL
		CALL	SKIPSP
		CALL	SETUP2
		CP	'"'
		INC	HL
		JP	Z,SKIPSP
BADSTR:		LD	A,253
		CALL	EXTERR
		DEFM	"Bad string"
		DEFB	0

PARSE:		LD	A,(HL)
		INC	HL
		CP	'`'
		RET	NC
		CP	'?'
		RET	C
		XOR	40H
		RET

SETUP2:		PUSH	DE
		INC	HL
		LD	A,(HL)
		CP	':'
		DEC	HL
		LD	A,B
		JR	NZ,DEVICE
		LD	A,(HL)		;DRIVE
		AND	31
		INC	HL
		INC	HL
DEVICE:		LD	DE,FCB
		LD	(DE),A
		INC	DE
		LD	B,8
COPYF:		LD	A,(HL)
		CP	'.'
		JR	Z,COPYF1
		CP	' '
		JR	Z,COPYF1
		CP	CR
		JR	Z,COPYF1
		CP	'='
		JR	Z,COPYF1
		CP	'"'
		JR	Z,COPYF1
		LD	C,'?'
		CP	'*'
		JR	Z,COPYF1
		LD	C,' '
		INC	HL
		CP	'|'
		JR	NZ,COPYF2
		CALL	PARSE
		JR	COPYF0
COPYF1:		LD	A,C
COPYF2:		CALL	UPPRC
COPYF0:		LD	(DE),A
		INC	DE
		DJNZ	COPYF
COPYF3:		LD	A,(HL)
		INC	HL
		CP	'*'
		JR	Z,COPYF3
		CP	'.'
		LD	BC,3*256+' '
		LD	DE,FCB+9
		JR	Z,COPYF
		DEC	HL
		POP	DE
		LD	BC,128
		JP	SKIPSP

BBC:		DEFM	"BBC"

; ------------------------------------------------------------------------------
; Subroutine: Erase file
; ------------------------------------------------------------------------------
bbxDosErase:	CALL	SETUP0		;*ERA, *ERASE
		LD	C,19
		JP	XEQDOS

; ------------------------------------------------------------------------------
; Subroutine: Reset disk
; MSXDOS not implemented / not required
; ------------------------------------------------------------------------------
IFDEF MSXDOS
bbxDosResDisk:	EQU	SORRY
ELSE
bbxDosResDisk:	LD	C,13		;*RESET
		JP	XEQDOS
ENDIF

; ------------------------------------------------------------------------------
; Subroutine: Set/get drive (disk)
; ------------------------------------------------------------------------------
IFDEF MSXDOS
bbxDosDrive:	EQU	SORRY
ELSE
bbxDosDrive:	CALL	SETUP0		;*DRIVE
		LD	A,(FCB)
		DEC	A
		JP	M,HUH
		LD	E,A
		LD	C,14
		JP	XEQ0
ENDIF

dosGetDrive:	LD	A,(FCB)
		DEC	A
		LD	C,25
		CALL	M,BDC
		RET

; ------------------------------------------------------------------------------
; Subroutine: Rename file
; ------------------------------------------------------------------------------
bbxDosRename:	CALL	SETUP0		;*REN, *RENAME
		CP	'='
		JP	NZ,HUH
		INC	HL		;SKIP "="
		PUSH	HL
		CALL	EXISTS
		LD	HL,FCB
		LD	DE,FCB+16
		LD	BC,12
		LDIR
		POP	HL
		CALL	SETUP0
		CALL	CHKAMB
		LD	C,23
		JP	XEQDOS

; -----------------------------------------------------------------
; Subroutine: Execute CP/M Command
; -----------------------------------------------------------------
XEQDOS:		LD	DE,FCB
XEQ0:		LD	A,(HL)
		CP	CR
		JP	NZ,HUH
BDC:		LD	A,C
		CALL	BDOS1
		RET	P
		JP	HUH

; ------------------------------------------------------------------------------
EXISTS:		LD	HL,DSKBUF
		CALL	dosSetDMA
		LD	DE,FCB
		LD	A,17
		CALL	BDOS1		;SEARCH
		INC	A
		RET	Z
		LD	A,196
		CALL	EXTERR
		DEFM	"File exists"
		DEFB	0

; ------------------------------------------------------------------------------
SAVLOD:		CALL	SETUP0		;PART OF *SAVE, *LOAD
		CALL	HEX
		CP	'+'
		PUSH	AF
		PUSH	DE
		JR	NZ,SAVLO1
		INC	HL
SAVLO1:		CALL	HEX
		CP	CR
		JP	NZ,HUH
		EX	DE,HL
		POP	DE
		POP	AF
		RET	Z
		OR	A
		SBC	HL,DE
		RET	NZ
		JP	HUH

; ------------------------------------------------------------------------------
; Directory i.e. list files
; ------------------------------------------------------------------------------
bbxDosDot:	INC	HL
bbxDosDir:	LD	A,'?'		;*DIR
		CALL	SETUP
		CP	CR
		JP	NZ,HUH
		LD	C,17		; Search first file
IFDEF MSXDOS
DIR0:		LD	B,2
ELSE
DIR0:		LD	B,4
ENDIF
DIR1:		CALL	LTRAP
		LD	DE,FCB
		LD	HL,DSKBUF
		CALL	dosSetDMA
		CALL	dosSearch
		JP	M,CRLF
		RRCA
		RRCA
		RRCA
		AND	60H
		LD	E,A
		LD	D,0
		LD	HL,DSKBUF+1
		ADD	HL,DE
		PUSH	HL
		LD	DE,8		;**
		ADD	HL,DE
		LD	E,(HL)		;**
		INC	HL		;**
		BIT	7,(HL)		;SYSTEM FILE?
		POP	HL
		LD	C,18		; Search next file
		JR	NZ,DIR1
		PUSH	BC
		CALL	dosGetDrive
		ADD	A,'A'
		CALL	OSWRCH
		LD	B,8
		LD	A,' '		;**
		BIT	7,E		;** READ ONLY?
		JR	Z,DIR3		;**
		LD	A,'*'		;**
DIR3:		CALL	CPTEXT
		LD	B,3
		LD	A,' '		;**
		CALL	SPTEXT
		POP	BC
		DJNZ	DIR2
		CALL	CRLF
		JR	DIR0
DIR2:		PUSH	BC
		LD	B,5
PAD:		LD	A,' '
		CALL	OSWRCH
		DJNZ	PAD
		POP	BC
		JR	DIR1

; ------------------------------------------------------------------------------
; Set output stream
; ------------------------------------------------------------------------------
bbxDosOpt:	CALL	HEX		;*OPT
		LD	A,E
		AND	3
SETOPT:		LD	(OPTVAL),A
		RET

bbxDosReset:	XOR	A
		JR	SETOPT

; ------------------------------------------------------------------------------
; Set input stream (exec) / printer spooler
; ------------------------------------------------------------------------------
bbxDosExec:	LD	A,00000001B	;*EXEC
		DEFB	1		;SKIP 2 BYTES (LD BC)
bbxDosSpool:	LD	A,00000010B	;*SPOOL
		PUSH	AF
		PUSH	HL
		CALL	SESHUT		;STOP SPOOL/EXEC
		POP	HL
		POP	BC
		LD	A,(HL)
		CP	CR		;JUST SHUT?
		RET	Z
		LD	A,(FLAGS)
		OR	B
		LD	(FLAGS),A	;SPOOL/EXEC FLAG
		RRA			;CARRY=1 FOR EXEC
		CALL	OPENIT		;OPEN SPOOL/EXEC FILE
		RET	Z		;DIR FULL / NOT FOUND
		POP	IX		;RETURN ADDRESS
		LD	HL,(HIMEM)
		OR	A
		SBC	HL,SP		;SP=HIMEM?
		ADD	HL,SP
		JR	NZ,JPIX		;ABORT
		LD	BC,-FCBSIZ
		ADD	HL,BC		;HL=HL-FCBSIZ
		LD	(HIMEM),HL	;NEW HIMEM
		LD	(TABLE),HL	;FCB/BUFFER
		LD	SP,HL		;NEW SP
		EX	DE,HL
		CALL	OPEN3		;FINISH OPEN OPERATION
JPIX:		JP	(IX)		;"RETURN"

; ------------------------------------------------------------------------------
; *ESC COMMAND
; ------------------------------------------------------------------------------
bbxDosEscCtl:	LD	A,(HL)
		CALL	UPPRC		;**
		CP	'O'
		JR	NZ,ESCC1
		INC	HL
ESCC1:		CALL	HEX
		LD	A,E
		OR	A
		LD	HL,FLAGS
		RES	6,(HL)		;ENABLE ESCAPE
		RET	Z
		SET	6,(HL)		;DISABLE ESCAPE
		RET

; ------------------------------------------------------------------------------
; PTEXT - Print text
;   Inputs: HL = address of text
;            B = number of characters to print
; Destroys: A,B,H,L,F
; ------------------------------------------------------------------------------
CPTEXT:		PUSH	AF		;**
		LD	A,':'
		CALL	OSWRCH
		POP	AF		;**
SPTEXT:		CALL	OSWRCH		;**
PTEXT:		LD	A,(HL)
		AND	7FH
		INC	HL
		CALL	OSWRCH
		DJNZ	PTEXT
		RET

; ------------------------------------------------------------------------------
; OSINIT - Initialise RAM mapping etc.
; If BASIC is entered by BBCBASIC FILENAME then file
; FILENAME.BBC is automatically CHAINed.
;
; Outputs: DE = initial value of HIMEM (top of RAM)
;          HL = initial value of PAGE (user program)
;          Z-flag reset indicates AUTO-RUN.
;  Destroys: A,B,C,D,E,H,L,F
; ------------------------------------------------------------------------------
bbxHostInit:	CALL	dosErrMode

		; Init DOS variables
		XOR	A
		LD	B,INILEN
		LD	HL,TABLE
CLRTAB:		LD	(HL),A			; CLEAR FILE TABLE ETC.
		INC	HL
		DJNZ	CLRTAB

		; Copy commandline parameter (if exists)
		LD	DE,ACCS
		LD	HL,DSKBUF
		LD	C,(HL)
		INC	HL
		CP	C			; N.B. A=B=0
		JR	Z,NOBOOT
		LDIR				; COPY TO ACC$
NOBOOT:		EX	DE,HL
		LD	(HL),CR

		; Set HIMEM
		LD	DE,(6)			; CP/M: HIMEM
		LD	E,A			; PAGE BOUNDARY
		RET

; ------------------------------------------------------------------------------
; Subroutine: Stop interrupts and return to CP/M. 
; ------------------------------------------------------------------------------
bbxHostExit:	RST	0

; ------------------------------------------------------------------------------
; Subroutine: Search first/next file
; ------------------------------------------------------------------------------
dosFSfirst:	LD	C,17
		JR	dosSearch
dosFSnext:	LD	C,18
dosSearch:	LD	A,C
		JP	BDOS1

; ------------------------------------------------------------------------------
; Subroutine: Set action on hardware error
; Sets error mode to: error code is returned in H and error message is printed.
; ------------------------------------------------------------------------------
dosErrMode:	LD	C,45
		LD	E,254
		JP	BDOS

; ------------------------------------------------------------------------------
; Subroutine: Close file
; ------------------------------------------------------------------------------
dosFclose:	LD	A,16
		JP	BDOS1
		INC	A
		RET	NZ
		LD	A,200
		CALL	EXTERR
		DEFM	"Close error"
		DEFB	0

; ------------------------------------------------------------------------------
; Subroutine: Compute file size
; ------------------------------------------------------------------------------
dosFsize:	LD	A,35
		JP	BDOS1

; ------------------------------------------------------------------------------
; Subroutine: Direct console I/O
; Return a key (char) without echoing if one is waiting; zero if none available.
; ------------------------------------------------------------------------------
dosGetKey:	LD	A,6
		LD	E,0FFH
		JP	BDOS0

; -----------------------------------------------------------------
; Subroutine: Console out character
; Parameters: A = Character
; -----------------------------------------------------------------
dosOutChar:	LD	E,A
		LD	A,(OPTVAL)	;FAST ENTRY
		ADD	A,3
		CP	3
		JR	NZ,WRCH1
		ADD	A,E
		LD	A,2
		JR	C,WRCH1
		LD	A,6
WRCH1:		CALL	BDOS0
		LD	HL,FLAGS
		BIT	2,(HL)
		LD	A,5		;PRINTER O/P
		CALL	NZ,BDOS0
		BIT	1,(HL)		;SPOOLING?
		RET	Z
		RES	1,(HL)
		LD	A,E		;BYTE TO WRITE
		LD	E,8		;SPOOL/EXEC CHANNEL
		PUSH	BC
		CALL	OSBPUT
		POP	BC
		SET	1,(HL)
		RET

; --------------------------------------------------------
;EXECIN - Read byte from EXEC file
;  Outputs: A = byte read
; Destroys: A,F
; --------------------------------------------------------
bbxDosExecIn:	PUSH	BC		;SAVE REGISTERS
		PUSH	DE
		PUSH	HL
		LD	E,8		;SPOOL/EXEC CHANNEL
		LD	HL,FLAGS
		RES	0,(HL)
		CALL	OSBGET
		SET	0,(HL)
		PUSH	AF
		CALL	C,SESHUT	;END EXEC IF EOF
		POP	AF
		POP	HL		;RESTORE REGISTERS
		POP	DE
		POP	BC
		RET

; -------------------------------
; Dynamic RAM variables for CP/M
; -------------------------------

		SECTION	BBX80RAM

TABLE:		DEFS	16		; FILE BLOCK POINTERS
OPTVAL:		DEFB	0
INILEN:		EQU	$-TABLE

