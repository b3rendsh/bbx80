﻿# BBX80
BBC BASIC for a Z80 home computer.

## General Information

In this repository you find BBC BASIC (Z80) implementation source code for a Z80 home computer that may not have a Disk OS like CP/M.

#### The system setup consists of three main blocks:
1. BBC BASIC (Z80) implementation from R.T. Russell
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
The implemention is done for the bit90 computer, meaning you could replace the bit90 16K BASIC ROM (2x 8K) with the ROM version of bbx80 or you can load the cartridge version from tape or make a Coleco game cartridge with the cartridge ROM image. 
#### Original ROM BIOS usage
The Game ROM (Coleco compatible) is only used to start the system, the BIT90 ROM is not used or only to boot the system from tape. The Coleco ROM routines will still be avaible after boot, so you can call them from the inline assembler.
#### Features
Included are the core commands as in BBC BASIC Z80, without the CP/M OS commands. Additional commands: save/load to tape, plot, point, draw, move, keyson, keysoff, bye, colour, gcol and cload/csave via rs232. There is a branch table to extend basic and a mixed text/graphics screen with 50x24 characters, 256x192 pixels and 16 colors.   
#### Other computers
Other computers that easily meet the minimum requirements are MSX1, SC3000, SV-328 and Coleco Adam.

## RC2014
As a reference I have implemented the standard CP/M 2.2 (compatible) version of BBC BASIC with some enhancements for a VT100 terminal. 
In the future there may be more enhanced editions for this Z80 platform.
