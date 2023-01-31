@echo  off
rem Make z80 binary from asm source with z88dk tools
rem When switching targets do a make clean first!

set bbc=..\bbc-z80\
set common=..\common\
set bin=.\bin\

if "%1"=="vt100" goto vt100
if "%1"=="basic" goto future
if "%1"=="advanced" goto future
if "%1"=="ultimate" goto future

if "%1"=="test" goto test
if "%1"=="clean" goto clean

echo Usage: make [abcpm^|test^|clean]
goto end

:vt100
echo Assembling vt100 edition..
set obj=.\obja\
set app=.\app\
set target=BBX80A
set exsection="BASICRAM BBX80VAR BBX80RAM"
goto assemble

:future
echo Reserved for a future edition..
goto end

:assemble
del /q %obj%
z80asm -b -d -l -m -D%target% -O%obj% -o=bbx80.bin bbx80.asm bbx80con.asm cpm.asm %common%basic.asm %bbc%main.asm %bbc%exec.asm %bbc%eval.asm %bbc%fpp.asm %bbc%ram.asm  
z88dk-appmake +glue -b %obj%bbx80 --filler 0x00 --clean --exclude-sections %exsection%
copy /b %obj%bbx80__.bin %bin%%target%.COM
echo done
goto end

:test
echo Compiling test..
set obj=.\objtest\
z80asm -b -d -l -m -DTEST -O%obj% -o=bbx80.bin bbx80.asm bbx80con.asm %common%basic.asm %bbc%main.asm %bbc%exec.asm %bbc%eval.asm %bbc%fpp.asm %bbc%ram.asm 
z88dk-appmake +glue -b %obj%bbx80 --filler 0x00 --clean --exclude-sections "BOOT BASIC BASICRAM BBX80VAR BBX80RAM"
goto end

:clean
del /q obja
del /q objtest
del /q bbc-z80
echo Cleanup done

:end

