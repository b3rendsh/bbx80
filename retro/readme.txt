BBC BASIC for Z80 RETROCOMPUTER
===============================

In this folder are the sources for customized editions of BBC BASIC for a Z80 
or Z180 retrocomputer.


BBX80A
------

System:
- Z80 CPM 2.2 Compatible
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

BBX80B
------

System:
- Z80 CPM 2.2 Compatible
- ANSI / VT100 Terminal
- BBC BASIC Application
- TMS9918A Compatible (optional)

Differences with VT100 edition:
- Include graphics commands


BBX80C
------

System:
- Z80 / Z180 CPM 2.2 Compatible
- RomWBW Compatible
- ANSI Terminal
- BBC BASIC Application
- TMS9918A Compatible (optional)

This is the advanced edition with the latest experimental features.

Differences with VT100 edition:
- Include graphics commands
- TIME command, timer implemented (returns seconds)
- Hide/display cursor while in input mode (VT510)


