# Make z80 binary from asm source with z88dk tools
# BBX80 for MSX

SOURCES := bbx80.asm msx.asm ../common/cpm.asm ../common/con_tms.asm ../common/vdp_tms.asm
BASIC	:= ../common/basic.asm ../bbc-z80/main.asm ../bbc-z80/exec.asm ../bbc-z80/eval.asm ../bbc-z80/fpp.asm ../bbc-z80/ram.asm
EXCLUDE	:= "BASICRAM BASICVAR BBX80VAR BBX80RAM"

# system agnostic commands
ifdef ComSpec
	RMF	:= del /f /q
	SEARCH	:= find
	CP	:= copy /b
	/	:= $(strip \)
else
	RMF	:= rm -f 
	SEARCH	:= grep
	CP	:= cp
	/	:= /
endif 

.PHONY:	all msx clean

all:	msx

msx:	
	@echo Assembling MSX edition..
	$(RMF) common$/*
	$(RMF) bbc-z80$/*
	z80asm -b -d -l -m -DBBX80M -Oobj -o=bbx80.bin $(SOURCES) $(BASIC)
	z88dk-appmake +glue -b obj/bbx80 --filler 0x00 --clean --exclude-sections $(EXCLUDE)
	$(CP) obj$/bbx80__.bin bin$/BBX80M.COM
	@echo done

clean:
	$(RMF) common$/*
	$(RMF) bbc-z80$/*
	$(RMF) obj$/*
	@echo Cleanup done
