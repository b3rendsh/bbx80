# BBC BASIC for Z80

This is modified source code based on [BBC BASIC (Z80)](http://www.bbcbasic.co.uk/bbcbasic/z80basic.html) by R.T. Russell, who [kindly agreed](http://cowlark.com/2019-06-14-bbcbasic-opensource/index.html) to release the original sources under the [zlib](COPYING) license at the request of David Given.  David published the sources as part of his [cpmish](https://github.com/davidgiven/cpmish) project.

The files I used are [modified sources by J.B.Langston](https://github.com/jblang/bbcbasic-z80):

- Modified sources to assemble with [z88dk](https://github.com/z88dk/z88dk)'s z80asm  
- Fixed a [bug](https://github.com/davidgiven/cpmish/issues/20) that causes the RUN command to hang under emulators.  
  
I made the following additional changes:  
  
- A few more syntax modifications to assemble with z88dk z80asm  
- Include assembler directives to include/exclude sections for different target host configurations.  
- Added a branch table in RAM for the token tables, commands not included and some other routines. This is to retain flexibility while running BASIC from ROM instead of RAM.   
- The files cmos.z80, patch.z80, sorry.z80 and the new branch table are consolidated in one basic.asm file.  
- If I modify anything else it will be recognizable by the IFDEF assembler directive.  
  
The *.asm files are used in the compilation, the other files are used as reference documentation.

