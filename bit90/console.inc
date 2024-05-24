; ------------------------------------------------------------------------------
; BBX80 Console Include v1.0
;
; Console definitions
; ------------------------------------------------------------------------------

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
