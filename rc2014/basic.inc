; ------------------------------------------------------------------------------
; BASIC Include v1.0
;
; Include definitions for BBC BASIC (Z80) modules
; ------------------------------------------------------------------------------

DEFL BASVERSION = "V3.0"

; Directives
		DEFINE	TITLESCREEN	; Credits in title screen
		DEFINE	BBX80		; BBX80 modifications in the BASIC code
		DEFINE	INCDOS		; Comment out to disable DOS (CP/M) functions

; BBX80 routines
		EXTERN	SORRY

; BBX80 variables
		EXTERN	PT_KEYWDS
		EXTERN	PT_KEYWDL
		EXTERN	PT_CMDTAB
		EXTERN	PT_FUNTBL
		
		
