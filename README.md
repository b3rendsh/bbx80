# BBX80
BASIC for a Z80 home computer.

## General Information

In this repository you find BASIC source code and binaries for a Z80 home computer that may not have a Disk OS like CP/M.

#### The system setup consists of three main blocks:
1. BASIC: A derived work of BBC BASIC (Z80) version 3.0 by R.T. Russell
2. BBX80: general host and console functions
3. Host computer specific functions

## BIT90 / Coleco
  
#### Host computer minimum requirements:
* Z80 processor
* TMS9929A / 16KB VRAM or compatible video out
* 16KB ROM or RAM for the bbx80 software
* 2KB RAM
* Keyboard input function

#### ROM and Cartridge version of bbx80
Replace the bit90 16KB BASIC ROM (2x 8KB) with the ROM version of bbx80 or load the cartridge version from tape or make a Coleco game cartridge with the cartridge ROM image. There is also an optional patch for the 8KB Coleco ROM.

#### Original ROM BIOS usage
The Game ROM (Coleco compatible) is only used to start the system, the BIT90 ROM is not used or only to boot the system from tape. The Coleco ROM routines will still be avaible after boot, so you can call them from the inline assembler.
#### Features
Included are the core commands as in BBC BASIC Z80, without the CP/M OS commands. Additional commands: save/load to tape, plot, point, draw, move, keyson, keysoff, bye, colour, gcol and cload/csave via rs232. There is a branch table to extend basic and a mixed text/graphics screen with 50x24 characters, 256x192 pixels and 16 colors.   
#### Limitations
 * I have tested both the rom and cartridge (i.e. tape) version 1.2 on the real hardware, the latest versions are tested with the mame emulator. 
 * Some of the hardware specific commands may work a bit different than the original.
 * The save/load on tape works in my configuration but your mileage may vary.  
 * It is already amazing how much functionality can be squeezed into 16KB of memory, extending the command set any further will require additional ROM or RAM for the system.
## Retrocomputer
There are 3 different editions for a typical Z80/Z180 retrocomputer (e.g. rcbus)

**A: VT100**
As a reference I have implemented the standard CP/M 2.2 (compatible) version of BASIC with some enhancements for a VT100 console. 

**B: Basic**
Includes VT100 console and TMS9918A or compatible graphics card commands.

**C: Advanced**
Includes VT100 console, TMS9918A graphics card commands and the latest additional features . This edition requires a system with RomWBW.
## MSX
Requires MSX1 or MSX2 with MSXDOS 1.0 or higher.  Includes load/save file to disk and graphics commands. Limitation is that only screen 2 is implemented for console and graphics. This is still a work in progress, more features will be added in the future.

## Other computers
Other computers that easily meet the minimum requirements are SC3000, SV-328 and Coleco Adam.

## Credits
A substantial part of this BASIC is derived work of BBC BASIC (Z80) version 3.0, many thanks to R.T.Russell for open sourcing it. 
