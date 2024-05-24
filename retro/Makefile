# Make z80 binary from asm source with z88dk tools
# BBX80 for Retrocomputer

SOURCES := bbx80.asm ../common/cpm.asm ../common/con_vt100.asm
BASIC	:= ../common/basic.asm ../bbc-z80/main.asm ../bbc-z80/exec.asm ../bbc-z80/eval.asm ../bbc-z80/fpp.asm ../bbc-z80/ram.asm
VDP	:= ../common/vdp_tms.asm
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

.PHONY:	all vt100 basic advanced clean

all:	vt100 basic advanced

vt100:	
	@echo Assembling vt100 edition..
	$(RMF) common$/*
	$(RMF) bbc-z80$/*
	z80asm -b -d -l -m -DBBX80A -Oobja -o=bbx80.bin $(SOURCES) $(BASIC)
	z88dk-appmake +glue -b obja/bbx80 --filler 0x00 --clean --exclude-sections $(EXCLUDE)
	$(CP) obja$/bbx80__.bin bin$/BBX80A.COM
	@echo done

basic:	
	@echo Assembling basic edition..
	$(RMF) common$/*
	$(RMF) bbc-z80$/*
	z80asm -b -d -l -m -DBBX80B -Oobjb -o=bbx80.bin $(SOURCES) $(VDP) $(BASIC)
	z88dk-appmake +glue -b objb/bbx80 --filler 0x00 --clean --exclude-sections $(EXCLUDE)
	$(CP) objb$/bbx80__.bin bin$/BBX80B.COM
	@echo done

advanced:
	@echo Assembling advanced edition..
	$(RMF) common$/*
	$(RMF) bbc-z80$/*
	z80asm -b -d -l -m -DBBX80C -Oobjc -o=bbx80.bin $(SOURCES) $(VDP) $(BASIC)
	z88dk-appmake +glue -b objc/bbx80 --filler 0x00 --clean --exclude-sections $(EXCLUDE)
	$(CP) objc$/bbx80__.bin bin$/BBX80C.COM
	@echo done

clean:
	$(RMF) common$/*
	$(RMF) bbc-z80$/*
	$(RMF) obja$/*
	$(RMF) objb$/*
	$(RMF) objc$/*
	@echo Cleanup done
