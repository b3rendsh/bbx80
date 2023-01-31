BBC BASIC for RC2014
====================

In this folder are the sources for customized editions of BBC BASIC for the 
RC2014 ecosystem.


BBX80A
------

System:
- Z80 CPM 2.2
- ANSI / VT100 Terminal
- BBC BASIC Application

This edition is almost the same as the original CP/M version of BBC BASIC V3.0.

Differences:
The DOS code is restructured and put in a separate CP/M module.
The console code is partly redesigned and put in a separate console module.
Implemented VT100 escape codes and redefined control keys for cursor movement.

Extras:
- line edit support for multiple lines, cursor keys and other control keys
- keywords entered in lowercase are converted to uppercase (variables are not)
- CLS command will clear screen
- COLOUR command will set ANSI colors
- PRINT TAB(x,y) or INPUT TAB(x,y) wil move the cursor to position x,y
- POS and VPOS report the current cursor position
- Screen width is automatically detected and set at program start
- Display free memory at program start

Notes:
VT100 escape codes have been tested with Tera Term and Putty.


Future versions
---------------
Ideas for future development:

BBX80B
------
Colecovision / BIT90 compatible edition:
- Z80 24K ROM / 8K-40K RAM
- SCM (BIOS)
- Auto boot into BBC BASIC
- Load/save file (CF/Serial/Other)
- Load/save colecovision game
- Console 80x24 (serial) or 50x24 (tms9929a)
- Colecovision compatible Graphics/Sound/Game port

BBX80C
------
Colecovision, MSX(2) and CP/M OS edition:
- Z80 32K ROM / 64K RAM
- RomWBW (BIOS)
- Boot into CP/M 2.2 (or equal)
- BBC BASIC Application
- BASIC Extensions
- Graphics: Colecovision and MSX(2)
- Sound: Colecovision and MSX
- Game ports

BBX80Z
------
Ultimate future system edition:
- Z180 512K ROM / 512K RAM
- Boot choice (GRUBish)
- Z180 Optimization
- BBC BASIC + MSX BASIC command set
- VGA/USB 80x24 console (or equal)
- Graphics MSX2 / VGA
- Sound Coleco / MSX
- Coleco adapter
- MSX adapter
- Wireless networking (rf433, bluetooth or wifi)
- TCP/IP
- Tape load/save file
- RTC
- NVRAM (bios/boot configuration)
- GP I/O ports (Arduino and Domoticz ecosystem)
- Diagnostics/debug module (with blinkenlights)
- Other
