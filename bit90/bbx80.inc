; ------------------------------------------------------------------------------
; BBX80 Include v1.1
;
; Definitions used in BBX80 modules
; ------------------------------------------------------------------------------

; Version
DEFL BBXVERSION = "V1.1"

; System settings
VIDEOHZ:	EQU	50		; 60 for NTSC / 50 for PAL systems (used in timers)
COLUMNS:	EQU	50		; Screen width
SPEED:		EQU	$600		; Processor speed indicator (Z80/3.6Mhz)


;RST Routines
R_dspCRLF:	EQU	$08
R_dspTell:	EQU	$10
R_dspChar:	EQU	$18
R_NMIstop:	EQU	$20
R_NMIstart:	EQU	$28

; I/O Ports (BIT90)
IOCOM0:		EQU	$44		; RS232 Data I/O
IOCOM1:		EQU	$45		; RS232 Command or Read status
IOCOM2:		EQU	$46		; RS232 Select Baud Rate

IORAM0:		EQU	$4E		; Expansion RAM off 
IORAM1:		EQU	$4F		; Expansion RAM on

IOROM0:		EQU	$80		; Select Coleco ROM 
IOROM1:		EQU	$88		; Select BASIC ROM 

IOVDP0:		EQU	$BE		; TMS9929A R/W data
IOVDP1:		EQU	$BF		; TMS9929A Control

IOTAP0:		EQU	$FB		; Audio out to tape
IOTAP1:		EQU	$FF		; Audio in from tape

IOPSG0:		EQU	$FF		; SN74689AN Sound control 

IOKEY0:		EQU	$F8		; Keyboard
IOKEY1:		EQU	$CF		; Keyboard

; ASCII Control Characters
CUU:		EQU	$01		; Ctrl-A Cursor up
CUD:		EQU	$02		; Ctrl-B Cursor down
CUF:		EQU	$03		; Ctrl-C Cursor right
CUB:		EQU	$04		; Ctrl-D Cursor left
KHOME:		EQU	$05		; Ctrl-E Home
KEND:		EQU	$06		; Ctrl-F End
BELL:		EQU	$07		; Ctrl-G Bell
BS:		EQU	$08		; Ctrl-H Backspace (cursor left)
TAB:		EQU	$09		; Ctrl-I Tab
LF:		EQU	$0A		; Ctrl-J Linefeed (cursor down)
ERARIGHT:	EQU	$0B		; Ctrl-K Erase cursor to end
CR:		EQU	$0D		; Ctrl-M Enter (cursor home)
INS:		EQU	$0E		; Ctrl-N Insert space
DEL:		EQU	$0F		; Ctrl-O Delete char
PECHO:		EQU	$10		; Ctrl-P Toggle echo to printer
KCONT:		EQU	$11		; Ctrl-Q Continue scroll
KSCROLL:	EQU	$13		; Ctrl-S Stop scroll
ERALEFT:	EQU	$18		; Ctrl-X Erase to home
ESC:		EQU	$1B		; Ctrl-[ Escape

; Control Characters not used
; $0C Ctrl-L Page Up
; $12 Ctrl-R Redisplay
; $14 Ctrl-T Page Down
; $15 Ctrl-U Cancel line
; $16 Ctrl-V -
; $17 Ctrl-W Recall
; $19 Ctrl-Y -
; $1A Ctrl-Z Terminate input
; $1C Ctrl-\ PF1
; $1D Ctrl-] PF2
; $1E Ctrl-~ PF3
; $1F Ctrl-? PF4
