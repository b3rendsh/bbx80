# Make z80 binary from asm source with z88dk tools
# BBX80 for BIT90

SOURCES := bbx80.asm bbx80con.asm bit90.asm bbx80lib.asm
BASIC	:= ../common/basic.asm ../bbc-z80/main.asm ../bbc-z80/exec.asm ../bbc-z80/eval.asm ../bbc-z80/fpp.asm ../bbc-z80/ram.asm
EXCLUDE	:= "BASICRAM BASICVAR BBX80VAR BBX80RAM BIT90RAM"

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

.PHONY:	all rom cart clean

all:	rom cart

rom:
	@echo Assembling rom edition..
	$(RMF) common$/*
	$(RMF) bbc-z80$/*
	z80asm -b -d -l -m -DBBX80ROM -Oobjrom -o=bbx80.bin $(SOURCES) $(BASIC)
	z88dk-appmake +glue -b objrom/bbx80 --filler 0x00 --clean --exclude-sections $(EXCLUDE)
	z88dk-appmake +rom -b objrom/bbx80__.bin -o rom/bbx80.rom --chipsize 8192 -s 16384 --org 0
	@echo done

cart:
	@echo Assembling cartridge edition..
	$(RMF) common$/*
	$(RMF) bbc-z80$/*
	z80asm -b -d -l -m -DBBX80CART -Oobjcart -o=bbx80.bin $(SOURCES) $(BASIC)
	z88dk-appmake +glue -b objcart/bbx80 --filler 0x00 --clean --exclude-sections $(EXCLUDE)
	z88dk-appmake +rom -b objcart/bbx80__.bin -o cart/bbx80.rom --chipsize 8192 -s 16384 --org 0
	@echo done

clean:
	$(RMF) common$/*
	$(RMF) bbc-z80$/*
	$(RMF) objrom$/*
	$(RMF) objcart$/*
	@echo Cleanup done

	

