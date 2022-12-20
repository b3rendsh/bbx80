@echo  off
rem Make z80 binary from asm source with z88dk tools
rem When switching targets do a make clean first!

set bbc=..\bbc-z80\

if "%1"=="rom" goto rom
if "%1"=="cart" goto cart
if "%1"=="test" goto test
if "%1"=="clean" goto clean

echo Usage: make [rom^|cart^|test^|clean]
goto end

:rom
echo Assembling rom edition..
set obj=.\objrom\
set rom=.\rom\
set target=BBX80ROM
set exsection="BASICRAM BBX80VAR BBX80RAM"
goto assemble

:cart
echo Assembling cartridge edition..
set obj=.\objcart\
set rom=.\cart\
set target=BBX80CART
set exsection="BASICRAM BBX80VAR BBX80RAM"
goto assemble


:assemble
del /q %obj%
z80asm -b -d -l -m -D%target% -O%obj% -o=bbx80.bin bbx80.asm bbx80con.asm basic.asm bit90.asm bbx80lib.asm %bbc%main.asm %bbc%exec.asm %bbc%eval.asm %bbc%fpp.asm %bbc%ram.asm  
z88dk-appmake +glue -b %obj%bbx80 --filler 0x00 --clean --exclude-sections %exsection%
z88dk-appmake +rom -b %obj%bbx80__.bin -o %rom%bbx80.rom --chipsize 8192 -s 16384 --org 0
echo done
goto end


:test
echo Compiling test..
set obj=.\objtest\
z80asm -b -d -l -m -DTEST -O%obj% -o=bbx80.bin bbx80.asm bbx80con.asm basic.asm bit90.asm bbx80lib.asm %bbc%main.asm %bbc%exec.asm %bbc%eval.asm %bbc%fpp.asm %bbc%ram.asm 
z88dk-appmake +glue -b %obj%bbx80 --filler 0x00 --clean --exclude-sections "BOOT BASIC BASICRAM BBX80VAR BBX80RAM"
goto end

:clean
del /q objrom
del /q objcart
del /q objtest
del /q bbc-z80
echo Cleanup done

:end

