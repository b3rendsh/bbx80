#!/usr/bin/env python3
# BBC BASIC Z80 to Ascii BASIC file converter v0.1
#
# Reference: http://benryves.com/bin/bbcbasic/manual/Appendix_Tokeniser.htm


import sys	# needed for the commandline parameter

try:
    if len(sys.argv) != 2:
        print('Usage: bbc2bas.py <filename-without-extension>')
        quit()
    filename = sys.argv[1]
    with open(filename + '.bbc', 'rb') as f, open(filename + '.bas', 'w') as w:
        byte1     = int.from_bytes(f.read(1),'big')
        basline   = ''
        tokentab  = ['AND','DIV','EOR','MOD','OR','ERROR','LINE','OFF','STEP','SPC','TAB(','ELSE','THEN','','OPENIN','PTR',\
                     'PAGE','TIME','LOMEM','HIMEM','ABS','ACS','ADVAL','ASC','ASN','ATN','BGET','COS','COUNT','DEG','ERL','ERR',\
                     'EVAL','EXP','EXT','FALSE','FN','GET','INKEY','INSTR','INT','LEN','LN','LOG','NOT','OPENUP','OPENOUT','PI',\
                     'POINT(','POS','RAD','RND','SGN','SIN','SQR','TAN','TO','TRUE','USR','VAL','VPOS','CHR$','GET$','INKEY$',\
                     'LEFT$(','MID$(','RIGHT$(','STR$','STRING$(','EOF','AUTO','DELETE','LOAD','LIST','NEW','OLD','RENUMBER','SAVE','PUT','PTR',\
                     'PAGE','TIME','LOMEM','HIMEM','SOUND','BPUT','CALL','CHAIN','CLEAR','CLOSE','CLG','CLS','DATA','DEF','DIM','DRAW',\
                     'END','ENDPROC','EVELOPE','FOR','GOSUB','GOTO','GCOL','IF','INPUT','LET','LOCAL','MODE','MOVE','NEXT','ON','VDU',\
                     'PLOT','PRINT','PROC','READ','REM','REPEAT','REPORT','RESTORE','RETURN','RUN','STOP','COLOUR','TRACE','UNTIL','WIDTH','OSCLI']
        while byte1 > 0:
            #read linenumber
            byte1    = int.from_bytes(f.read(1),'big')
            byte2    = int.from_bytes(f.read(1),'big')
            basline += str(byte1 + byte2*256)
            basline += ' '
                    
            #read rest of the line until 0D
            byte2 = int.from_bytes(f.read(1),'big')
            quoted = False
            while  not (byte2 == 0x0D and  not quoted):
                if byte2 == 0x22:
                    quoted =  not quoted
                if byte2 == 0x8D:
                    linb1   = int.from_bytes(f.read(1),'big')
                    linb2   = int.from_bytes(f.read(1),'big')
                    linb3   = int.from_bytes(f.read(1),'big')
                    linb2a  = (linb1 & 32) * 4 + ((linb1 & 16) ^ 16) * 4
                    linb3a  = (linb1 & 8) * 16 + ((linb1 & 4) ^ 4) * 16
                    linenr  = (linb2 - 64) + linb2a
                    linenr += ((linb3 - 64) + linb3a) * 256
                    basline += str(linenr)                 
                elif byte2 > 0x80 and not quoted:
                    basline += tokentab[byte2 - 128]
                elif byte2 >= 32 and byte2 < 127:
                    basline += chr(byte2)
                byte2 = int.from_bytes(f.read(1),'big')
                    
            # print basic line to screen and save to file
            print(basline)
            w.write(basline)
            w.write('\n')
            basline = ''
            byte1 = int.from_bytes(f.read(1),'big')
                  
except IOError:
        print('Error converting file:' + filename + '.bbc')
	





