
;  Copyright 2024, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


            #include include/bios.inc
            #include include/kernel.inc


          ; Unpublished kernel vector points

d_ideread:  equ   0447h
d_idewrite: equ   044ah


          ; Executable program header

            org   2000h-6
            dw    start
            dw    end-start
            dw    start

start:      br    initial


          ; Build information

            db    11+80h                ; month
            db    5                     ; day
            dw    2024                  ; year
            dw    1                     ; build

            db    'See github.com/dmadole/MiniDOS-sedit for more info',0


initial:    ldi   0
            plo   r8
            phi   r7
            plo   r7

            ldi   %11100000
            phi   r8

            lbr   secread


getline:    sep   scall
            dw    o_inmsg
            db    '> ',0

            ldi   buffer.1
            phi   rf
            ldi   buffer.0
            plo   rf

            ldi   80.1
            phi   rc
            ldi   80.0
            plo   rc

            sep   scall
            dw    o_inputl
            lbnf  noctrlc

            sep   scall
            dw    o_inmsg
            db    '^C',13,10,0

            lbr   getline

noctrlc:    sep   scall
            dw    o_inmsg
            db    13,10,0

            ldi   buffer.1
            phi   ra
            phi   rf
            ldi   buffer.0
            plo   ra
            plo   rf


          ; Pre-process the input line to make it easier to parse. All alpha
          ; characters are changed to lower case, any leading and trailing
          ; spaces removed, and the input is broken into words, separated by
          ; zero bytes, and terminate with an extra zero byte.
       
skipini:    lda   ra                    ; skip any leading spaces on line
            lbz   gotline
            sdi   ' '
            lbdf  skipini

nextchr:    sdi   ' '-'a'               ; fold lower case into upper case
            lsnf
            smi   'a'-'A'
            adi   'a'

            ori   ' '                   ; make lower case and store
            str   rf
            inc   rf

            lda   ra                    ; skip additional word characters
            lbz   gotline
            sdi   ' '
            lbnf  nextchr

            ldi   0                     ; insert zero into string
            str   rf
            inc   rf

skipspc:    lda   ra                    ; skip any additional spaces
            lbz   gotspac
            sdi   ' '
            lbdf  skipspc

            lbr   nextchr               ; get next word in string

gotspac:    dec   rf                    ; if last was space then remove

gotline:    ldi   0                     ; double zero to end the string
            str   rf
            inc   rf
            str   rf


          ; Check the cleaned-up command line buffer agains the list of 
          ; commands one word at a time for a match. A prefix of each word
          ; will be accepted so the table needs to be sorted accorbingly.

            ldi   command.1
            phi   rc
            ldi   command.0
            plo   rc

            ldi   buffer.1
            phi   rf

            sex   rf


          ; Check one command list entry. If at the end of the list, then
          ; the command line was not matched. Otherwise, the first letter in
          ; each word must match, otherwise skip to the next entry.

chknext:    ldi   buffer
            plo   rf

nxtword:    lda   rc
            lbz   unknown

            sm
            lbnz  skipcmd


          ; Check the remaining letters until either the end of the word in
          ; the command list, or until a mismatched character, which can also
          ; mean the end of the command line word.

strcomp:    inc   rf

            lda   rc
            lbz   endword

            sm
            lbz   strcomp


          ; If a mismatch, skip to the end of the command list work, and if
          ; at the end of the command line word, treat as a prefix partial
          ; word match. If at the end of the command list entry, we have a
          ; match, otherwise resume matching with next word.

skpword:    lda   rc
            lbnz  skpword

endword:    lda   rf
            lbnz  chklast

            lda   rc
            lbz   matched

            sm
            lbz   strcomp


          ; If a mismatched word, then skip to the next command list entry
          ; and test again from there.

skipcmd:    lda   rc
            lbnz  skipcmd

chklast:    lda   rc
            lbnz  skipcmd

            inc   rc
            inc   rc

            lbr   chknext


          ; If we have a match, pick up the routine address from the command
          ; list and jump to it. We do this through an intermediate PC.

matched:    sex   r2                    ; set x back to the stack pointer

indjump:    ldi   jump_r3.1             ; temporarily change program counter
            phi   rd
            ldi   jump_r3.0
            plo   rd

            sep   rd                    ; swap program counter to rd

jump_r3:    lda   rc                    ; load routine address into r3
            phi   r3
            lda   rc
            plo   r3

            sep   r3                    ; set program counter back to r3


          ;--------------------------------------------------------------------
          ; If the leading words on the command line cannot be matched to
          ; an entry in the command table, then it is an unknown command.

unknown:    sep   scall
            dw    o_inmsg
            db    'Unknown command or bad syntax',13,10,0

            lbr   getline


          ;--------------------------------------------------------------------
          ; If an argument cannot be parsed, or if there are more arguments
          ; than expected, that that is an argument error.

invalid:    sep   scall
            dw    o_inmsg
            db    'Invalid or unexpected argument',13,10,0

            lbr   getline


          ;--------------------------------------------------------------------
          ; A list of commands for parsing against the command-line input.
          ; First is a list of words separated by zero bytes, then an extra
          ; zero byte to follow the last word, then the address of the code
          ; that implements that command.

command:    db    'set',0,'drive',0,0
            dw    set_drv

            db    'set',0,0
            dw    set_drv

            db    'read',0,'lba',0,0
            dw    readlba

            db    'read',0,'au',0,0
            dw    read_au

            db    'read',0,0
            dw    readsec

            db    'au',0,0
            dw    read_au

            db    'write',0,'lba',0,0
            dw    writlba

            db    'write',0,'au',0,0
            dw    writeau

            db    'write',0,0
            dw    writsec

            db    'edit',0,'high',0,0
            dw    edit_hi

            db    'edit',0,'low',0,0
            dw    edit_lo

            db    'edit',0,0
            dw    edithex

            db    'display',0,'high',0,0
            dw    disp_hi

            db    'display',0,'low',0,0
            dw    disp_lo

            db    'display',0,0
            dw    display

            db    'high',0,0
            dw    disp_hi

            db    'low',0,0
            dw    disp_lo

            db    'next',0,'lba',0,0
            dw    next_lb

            db    'next',0,0
            dw    next_lb

            db    'previous',0,'lba',0,0
            dw    prev_lb

            db    'previous',0,0
            dw    prev_lb

            db    'zero',0,0
            dw    zerosec

            db    'quit',0,0
            dw    quitall

            db    0


          ;--------------------------------------------------------------------
          ; Routine to get a hexidecimal argument up to six digits, or three
          ; bytes, used for inputting LBA addresses. Returns DF set if a
          ; non-hex digit character is encountered.

hexin:      ldi   0                      ; clear result value
            plo   ra
            phi   ra
            plo   rb

hexnext:    lda   rf                     ; get next char, end if null
            lbz   hexend

            smi   1+'f'                  ; if greater than 'f', end
            lbdf  hexend

            adi   1+'f'-'a'              ; if 'a'-'f', make 0-5, keep
            lbdf  hexten

            smi   1+'F'-'a'              ; if greater than 'F', end
            lbdf  hexend

            adi   1+'F'-'A'              ; if 'A'-'F', make 0-5, keep
            lbdf  hexten

            smi   1+'9'-'A'              ; if greater than '9', end
            lbdf  hexend

            adi   1+'9'-'0'              ; if '0'-'9', make 0-9, keep
            lbdf  hexone

hexend:     dec   rf                     ; back to non-hex and return
            sep   sret

hexten:     adi   10                     ; make 'a'-'f' values 10-15

hexone:     str   r2                     ; save value of this digit

            ldi   4                      ; shift left a total of four bits
            plo   re

hexmult:    glo   ra                     ; shift the whole input one bit
            shl
            plo   ra
            ghi   ra
            shlc
            phi   ra
            glo   rb
            shlc
            plo   rb

            lbdf  hexend                 ; overflowed if a one bit shifts out

            dec   re                     ; repeat for all four shifts
            glo   re
            lbnz  hexmult

            glo   ra                     ; merge new nibble into lsb
            or
            plo   ra

            lbr   hexnext                ; loop back and check next char


          ;--------------------------------------------------------------------
          ; Set the drive number 0-31 to operate on. Any other argument is
          ; an  error. The drive number is kept in R8.1.

set_drv:    sep   scall                  ; read decimal input for drive
            dw    f_atoi
            lbdf  invalid

            ghi   rd                     ; if msb is non-zero then error
            lbnz  invalid

            glo   rd                     ; if greater than 31 then error
            ani   %11100000
            lbnz  invalid

            glo   rd                     ; set lba bits for compatibility
            ori   %11100000
            phi   r8

            lbr   secread                ; read sector on drive


          ;--------------------------------------------------------------------
          ; Read the LBA previous to the one currently loaded. This command
          ; takes no argument. Does not underflow past zero.

prev_lb:    glo   r7                     ; if r7 is not zero just decrement
            lbnz  prev_nz
            ghi   r7
            lbnz  prev_nz

            glo   r8                     ; if lba is zero then do nothing
            lbz   secread

            smi   1                      ; else carry underflow into r8
            plo   r8

prev_nz:    dec   r7                     ; decement lba and go read it
            lbr   secread


          ;--------------------------------------------------------------------
          ; Read the LBA after the one currently loaded. This command takes
          ; no argument. Does not overflow to zero.

next_lb:    inc   r7                     ; increment low 16 bits

            glo   r7                     ; if no overflow then read it
            lbnz  secread
            ghi   r7
            lbnz  secread

            glo   r8                     ; carry overflow into r8.1
            adi   1
            lbnz  next_nz

            dec   r7                     ; undo increment of r7:r8.0
            lbr   secread

next_nz:    plo   r8                     ; save and read next sector
            lbr   secread


          ;--------------------------------------------------------------------
          ; Read a hex allocation unit number from the command line ar RF and
          ; set r8.0:R7 to the corresponding LBA. Return DF if an error.

inputau:    ldn   rf                     ; if the end of the input then error
            lbz   sreterr

            sep   scall                  ; convert hex to integer in rd
            dw    hexin

            lda   rf                     ; if not the end of input then error
            lbnz  sreterr
            ldn   rf
            lbnz  sreterr

            glo   rb
            ani   %11100000
            lbnz  sreterr

            glo   rb
            plo   r8
            ghi   ra
            phi   r7
            glo   ra
            plo   r7

            ldi   3                      ; shift right total of three times
            plo   re

autosec:    glo   r7                     ; shift 24 bits to the left
            shl
            plo   r7
            ghi   r7
            shlc
            phi   r7
            glo   r8
            shlc
            plo   r8

            dec   re                     ; complete shifts to multiply by 8
            glo   re
            lbnz  autosec

            sep   sret                   ; return success with df clear

sreterr:    smi   0                      ; return failure with df set
            sep   sret


          ;--------------------------------------------------------------------
          ; Read a sector from disk that is at the start of the allocation
          ; unit provided on the command line.

read_au:    sep   scall                  ; get the au and read first sector
            dw    inputau

            lbdf  invalid                ; error if au is improper else read
            lbr   secread


          ;--------------------------------------------------------------------
          ; Read a sector from disk that is at the start of the allocation
          ; unit provided on the command line.

writeau:    sep   scall                  ; get the au and read first sector
            dw    inputau

            lbdf  invalid                ; error if au is improper else read
            lbr   secwrit



inputlb:    ldn   rf
            lbz   sreterr

            sep   scall
            dw    hexin

            lda   rf
            lbnz  sreterr
            ldn   rf
            lbnz  sreterr

            shr

            glo   rb
            plo   r8
            ghi   ra
            phi   r7
            glo   ra
            plo   r7

            sep   sret


display:    ldn   rf
            lbnz  invalid

            sep   scall                 ; output first part of message
            dw    o_inmsg
            db    'Editing drive ',0

            sep   scall                 ; output drive, lba, and au
            dw    dispsec

            sep   scall                 ; indicate success
            dw    o_inmsg
            db    13,10,0

            lbr   getline


          ;--------------------------------------------------------------------
          ; Read a sector from disk from the LBA named on the command line.

readsec:    ldn   rf
            lbz   secread

readlba:    sep   scall
            dw    inputlb
            lbdf  invalid

secread:    sep   scall                 ; output first part of message
            dw    o_inmsg
            db    'Reading drive ',0

            sep   scall                 ; output drive, lba, and au
            dw    dispsec

            ldi   sector.1              ; pointer to sector buffer
            phi   rf
            ldi   sector.0
            plo   rf

            sep   scall                 ; read sector
            dw    d_ideread
            lbdf  diskerr

disk_ok:    sep   scall                 ; indicate success
            dw    o_inmsg
            db    ' ok',13,10,0

            lbr   getline


          ;--------------------------------------------------------------------
          ; Read a sector from disk from the LBA named on the command line.

writsec:    ldn   rf
            lbz   secwrit

writlba:    sep   scall
            dw    inputlb
            lbdf  invalid

secwrit:    sep   scall                 ; output first part of message
            dw    o_inmsg
            db    'Writing drive ',0

            sep   scall                 ; output drive, lba, and au
            dw    dispsec

            ldi   sector.1              ; pointer to sector buffer
            phi   rf
            ldi   sector.0
            plo   rf

            sep   scall                 ; write sector
            dw    d_idewrite
            lbnf  disk_ok

diskerr:    sep   scall                 ; indicate failure
            dw    o_inmsg
            db    ' ERROR <<<',13,10,0

            lbr   getline


dispsec:    

          ; Output all of the address arguments into a buffer in decimal or
          ; hex format as appropriate, separated by zero bytes.

            ldi   buffer.1              ; pointer into output buffer
            phi   rf
            ldi   buffer.0
            plo   rf

            ldi   0                     ; get the drive number as 5 bits
            phi   rd
            ghi   r8
            ani   %11111
            plo   rd

            sep   scall                 ; convert to integer number
            dw    f_intout

            ldi   0                     ; put zero separator
            str   rf
            inc   rf

            glo   r8                    ; get highest 8 bits of lba address
            plo   rd

            sep   scall                 ; convert to hex into buffer
            dw    f_hexout2

            ghi   r7                    ; get lowest 16 bits of lba address
            phi   rd
            glo   r7
            plo   rd
 
            sep   scall                 ; convert to hex into buffer
            dw    f_hexout4

            ldi   0                     ; put zero terminator
            str   rf
            inc   rf

            glo   r8                    ; copy lba into temporary registersA
            plo   rd
            ghi   r7
            phi   rc
            glo   r7
            plo   rc

            ldi   3                     ; divide by 8 to get au is 3 shifts
            plo   re

dividau:    glo   rd                    ; shift temporary copy right once
            shr
            plo   rd
            ghi   rc
            shrc
            phi   rc
            glo   rc
            shrc
            plo   rc

            dec   re                    ; repeat for 3 shifts
            glo   re
            lbnz  dividau

            sep   scall                 ; convert au to hex into buffer
            dw    f_hexout2

            ghi   rc
            phi   rd
            glo   rc
            plo   rd

            sep   scall                 ; convert au to hex into buffer
            dw    f_hexout4

            ldi   '.'                   ; add decimal point to au
            str   rf
            inc   rf

            glo   r7                    ; get sector offset into au
            ani   7

            adi   '0'                   ; add as octal digit
            str   rf                    
            inc   rf

            ldi   0                     ; put a zero terminator
            str   rf

            ldi   buffer                ; pointer to start of conversions
            plo   rf

            sep   scall                 ; output drive number
            dw    o_msg

            sep   scall                 ; output next part of message
            dw    o_inmsg
            db    ' lba ',0

skpzero:    ldn   rf                    ; skip any leading zeros on lba
            lbz   endzero
            inc   rf
            smi   '0'
            lbz   skpzero
endzero:    dec   rf

            sep   scall                 ; output lba address
            dw    o_msg

            sep   scall                 ; else output next part of message
            dw    o_inmsg
            db    ' (au ',0

sauzero:    ldn   rf                    ; skip any leading zeroes on au
            smi   '.'
            lbz   eauzero
            inc   rf
            smi   '0'-'.'
            lbz   sauzero
eauzero:    dec   rf

            sep   scall                 ; output the au address
            dw    o_msg

            ldi   ')'                   ; finish au output
            sep   scall
            dw    o_type

            sep   sret






disp_lo:    ldi   sector.1
            lskp

disp_hi:    ldi   1+sector.1
            phi   r9

            ldi   sector.0
            plo   r9

            ldi   buffer                ; display line from carriage return
disloop:    sep   scall
            dw    lineout

            glo   r9
            adi   16
            plo   r9

            ldi   buffer-2
            lbnf  disloop

            sep   scall
            dw    o_inmsg
            db    13,10,0

            lbr   getline


          ; R8.0:R7 - sector address
          ; R8.1    - drive numver
          ; R9      - pointer into sector
          ; RA.0    - nibble counter
          ; RB      - pointer into buffer


zerosec:    ldi   sector.1
            phi   rf
            ldi   sector.0
            plo   rf

            ldi   0
            plo   rc

zerloop:    ldi   0
            str   rf
            inc   rf
            str   rf
            inc   rf

            dec   rc
            glo   rc
            lbnz  zerloop

            lbr   getline


quitall:    ldi   0
            sep   sret



edit_hi:    ldn   rf
            lbnz  invalid

            plo   rd
            ldi   256.1
            phi   rd

            lbr   editzer



edit_lo:    ldn   rf
            lbnz  invalid

            plo   rd
            phi   rd

            lbr   editzer


          ; Display the first line of the sector and position cursor on first
          ; byte to start the edit process.

edithex:    ldn   rf                    ; if no argument then edit at zero
            lbz   editzer

            sep   scall                 ; get address offset to edit at
            dw    f_hexin

            ghi   rd                    ; if offset above 1ff then error
            ani   %11111110
            lbnz  invalid

            lda   rf                    ; if not end of word then error
            lbnz  invalid

            ghi   rd                    ; set address of sector pointer
            adi   sector.1
            phi   r9
            glo   rd
            plo   r9

            ldn   rf                    ; if end of input then editor mode
            lbz   editadr


editbyt:    sep   scall
            dw    f_hexin

            lda   rf
            lbnz  invalid

            ghi   r9
            smi   2+sector.1
            lbdf  skpbyte

            glo   rd
            str   r9
            inc   r9

skpbyte:    ldn   rf
            lbnz  editbyt

            lbr   getline


editzer:    ldi   sector.1
            phi   r9
            ldi   sector.0
            plo   r9

editadr:    ghi   re                    ; save current echo flag and clear
            stxd
            ani   %11111110
            phi   re

            ldi   buffer.1              ; set high byte of buffer pointers
            phi   rb
            phi   rf
 
            ldi   0                     ; set nibble offset to zero
            plo   ra

            glo   r9                    ; get byte in line, multiply by 3
            ani   15
            str   r2
            add
            add

            adi   6+buffer              ; add length of offset prefix
            plo   rb

            ldi   buffer
            sep   scall                 ; output the line and write to buffer
            dw    lineout

            glo   rb                    ; position cursor if near start
            smi   35+buffer
            lbnf  dissame

            adi   backspc-1             ; else position if near end
            plo   rf

            sep   scall                 ; output backspaces to position
            dw    o_msg


          ; Editor move

readkey:    sep   scall
            dw    o_readkey

            str   r2

            ldi   keytab.1
            phi   rc
            ldi   keytab.0
            plo   rc

            lbr   lookkey


          ; 

lastkey:    inc   rc
            inc   rc

lookkey:    lda   rc
            lbz   readkey

            sm
            lbz   skipkey

nextkey:    lda   rc
            lbz   lastkey

            sm
            lbnz  nextkey

skipkey:    lda   rc
            lbnz  skipkey

            lbr   indjump


          ; Table of keystrokes and actions. Each entry starts with a string
          ; of characters to match any of, which is terminated with a zero, 
          ; and then followed by the address of the handler for those keys.
          ; The end of the list is marked with a zero (a null string).

keytab:     db    'ABCDEF',0
            dw    upprkey

            db    'abcdef',0
            dw    lowrkey

            db    '0123456789',0
            dw    digikey

            db    'X'&31,'C'&31,'Xx',0
            dw    endedit

            db    'R'&31,'Rr',0
            dw    refresh

            db    'M'&31,0
            dw    linekey

            db    'L'&31,'Ll ',0
            dw    forwkey

            db    'K'&31,'Kk',0
            dw    prevkey

            db    'J'&31,'Jj',0
            dw    downkey

            db    'H'&31,'Hh',0
            dw    backkey

            db    'I'&31,0
            dw    bytekey

            db    0


          ; If return is pressed, move to the first byte of the next line by
          ; resetting pointer to start of line then jumping into the next
          ; line code. If we are in the last line, just move to the first
          ; byte of the currentl line by re-outputting from buffer.

linekey:    plo   ra                    ; always reset to high nibble

            glo   r9                    ; move to the start of this line
            ani   %11110000 
            plo   r9

            glo   r9                    ; if not last line, move down
            adi   16
            lbnf  nextlin

            ghi   r9                    ; if last, move to first byte of line
            smbi  sector.1
            lbnz  disleft

nextlin:    glo   r9                    ; not last, so move down to next line
            adi   15
            plo   r9
            inc   r9

disnext:    ldi   buffer-2              ; output line feed before line


          ; Output the line from position in RB and then move to first byte.

disline:    sep   scall                 ; output the line and write to buffer
            dw    lineout

disleft:    ldi   buffer+6              ; position of the first data byte
            plo   rb


           ; Output the first part of the buffer up to the address in RB.

dissame:    ldn   rb                    ; save the character at cursor
            stxd

            ldi   0                     ; zero terminate at the cursor
            str   rb

            ldi   buffer-1              ; pointer to carriage return
            plo   rf

            sep   scall                 ; output line from the start
            dw    o_msg

            irx                         ; restore the saved character
            ldx
            str   rb

            lbr   readkey               ; get next key entry


          ; Move down one line, keeping the column position the same, as long
          ; as we are not in the last line. If we are, then just ignore.

downkey:    glo   r9                    ; ignore if we are in the last line
            adi   16
            lbnf  downlin

            ghi   r9
            smbi  sector.1
            lbnz  readkey

downlin:    glo   r9                    ; add 16 to sector byte pointer
            adi   16
            plo   r9
            ghi   r9
            adci  0
            phi   r9

            lbr   movdown               ; output the new current line


          ; Move back one line, keeping the column position the same, as long
          ; as we are not in the first line. If we are, then just ignore.

prevkey:    glo   r9                     ; ignore if we are in the first line
            smi   16
            lbdf  prevlin

            ghi   r9
            smi   sector.1
            lbz   readkey

prevlin:    glo   r9                     ; subtract 16 from sector pointer
            smi   16
            plo   r9
            ghi   r9
            smbi  0
            phi   r9                     ; falls through to show next line


          ; Add return, newline, and terminating zero to buffer and output,
          ; then compose the next line to display.

movdown:    ldi   10                    ; move down to next line
            sep   scall
            dw    o_type

refresh:    glo   rb
            sep   scall                 ; output line past the cursor point
            dw    lineout

            lbr   dissame               ; outline line before the cursor


          ; If a hex input key was pressed, update the data in the sector
          ; buffer, output digit, and move cursor as needed.

lowrkey:    ldn   r2
            smi   32
            str   r2

upprkey:    ldi   9
            lskp

digikey:    ldi   0
            add
            ani   15 
            phi   ra

disphex:    ldn   r2
            str   rb
            inc   rb

            sep   scall                 ; output character to screen
            dw    o_type

            glo   ra                    ; if the low (right) nibble of byte
            lbnz  lownibl


          ; If we were positioned on the high (left) nibble of the byte.

            inc   ra                    ; advance nibble counter to right

            ldn   r9                    ; get existing low nibble digit
            ani   15
            str   r2

            ghi   ra                    ; move new value into left nibble
            shl
            shl
            shl
            shl
            or
            str   r9

            lbr   readkey               ; get next key input


          ; If we were positioned on the low (right) nibble of the byte.

lownibl:    dec   ra                    ; update nibbler counter to left
            inc   rb

            ldn   r9                    ; get existing high nibble value
            ani   255-15
            str   r2

            ghi   ra                    ; merge new low nibble into existing
            or
            str   r9

            inc   r9                    ; if end of line, move to next line
            glo   r9
            ani   15
            lbz   movdown

            ldi   ' '                   ; else move to next byte with space
            sep   scall
            dw    o_type

            lbr   readkey               ; get next key input


          ; If the tab key is pressed, skip ahead to the next byte.

bytekey:    glo   r9                    ; if not at end of buffer then move
            smi   255
            lbnf  notlast

            ghi   r9                    ; if at end of buffer then ignore
            smbi  sector.1
            lbnz  readkey

notlast:    inc   r9                    ; update offset, next line if wrap
            glo   r9
            ani   15
            lbz   disnext

            glo   ra                    ; if nibble column is odd move two
            lbnz  forwtwo

forwthr:    lda   rb                    ; copy characters to move right
            sep   scall
            dw    o_type

forwtwo:    lda   rb                    ; copy characters to move right
            sep   scall
            dw    o_type

            ldi   0                     ; make nibble column zero
            plo   ra

forwone:    lda   rb                    ; copy characters to move right
            sep   scall
            dw    o_type

            lbr   readkey


          ; If ^L or space is pressed, skip ahead to the next nibble.

forwkey:    glo   ra                    ; if nibble is odd then check end
            lbnz  forwodd

            inc   ra                    ; else make even and output character
            lbr   forwone

forwodd:    glo   r9                    ; if not at end then advance
            smi   255
            lbnf  advance

            ghi   r9                    ; if at end then ignore
            smbi  sector.1
            lbnz  readkey

advance:    inc   r9                    ; update offset, next line if wrap
            glo   r9
            ani   15
            lbnz  forwtwo

            dec   ra                    ; make nibble zero and display line
            lbr   disnext


          ; If ^H or backspace is pressed, skip backwards to prior nibble.

backkey:    glo   ra                    ; if nibble is even then check end
            lbz   evennib

            dec   ra                    ; else if odd then backup just one
            lbr   backone

evennib:    glo   r9                    ; go back if not at begining
            lbnz  backtwo

            ghi   r9                    ; if at beginning then ignore
            smbi  sector.1
            lbz   readkey

backtwo:    inc   ra                    ; make nibble column odd

            glo   r9                    ; if line wrap move to previous
            dec   r9
            ani   15
            lbz   reverse

            dec   rb                    ; backup pointer one space

            ldi   8                     ; backup cursor one character
            sep   scall
            dw    o_type

backone:    dec   rb                    ; backup pointer one space

            ldi   8                     ; backup cursor one character
            sep   scall
            dw    o_type

            lbr   readkey               ; output buffer to move cursor


          ; Display the line that R7 points within, and then position the
          ; cursor to the last data byte on the line. We do this by printing
          ; the entire line from the start, and then backspacing.

reverse:    ldi   buffer-2              ; output line preceeded by lf/cr
            sep   scall
            dw    lineout

            sep   scall                 ; backspace to last hex data byte
            dw    o_inmsg
            db    8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,0

            ldi   buffer+4+1+1+15*3+1   ; point buffer to cursor position
            plo   rb

            lbr   readkey               ; get next input key


          ; Compose a hex edit line into a memory buffer to output at end.
          ; First put the offset address followed by a colon, then 16 hex
          ; data bytes, then the same data in ASCII. When called, D contains
          ; the LSB of the buffer address to start outputting from.

lineout:    stxd                        ; save the location to print from

            ldi   buffer                ; put output after line feed/return
            plo   rf

            glo   r9                    ; offset of the start of the line
            ani   %11110000
            plo   rc
            plo   rd
            ghi   r9
            phi   rc
            smi   sector.1
            phi   rd

            sep   scall                 ; compose line offset into buffer
            dw    f_hexout4

            ldi   ':'                   ; compose colon after the offset
            str   rf
            inc   rf


          ; Next put 16 data bytes in hex with a space preceeding each.

hexbyte:    lda   rc                    ; get the byte we are at
            plo   rd

            ldi   ' '                   ; for each byte output a space
            str   rf
            inc   rf

            sep   scall                 ; followed by the value in hex
            dw    f_hexout2

            glo   rc                    ; loop for all 16 bytes in line
            ani   15
            lbnz  hexbyte


          ; Output two separator spaces and rewind to start of the line.

            ldi   ' '                   ; for each byte output a space
            str   rf
            inc   rf
            str   rf
            inc   rf

            dec   rc                    ; back to beginning of the line
            glo   rc
            smi   15
            plo   rc


          ; Output 16 ASCII bytes but translate unprintables to a period.

ascbyte:    lda   rc                    ; if delete or higher not printable
            smi   127
            lbdf  noprint

            smi   ' '-127               ; if less than a space not printable
            lbdf  isprint

noprint:    ldi   '.'-' '               ; make original character a period

isprint:    adi   ' '                   ; write original character to buffer
            str   rf
            inc   rf

            glo   rc                    ; continue for 16 characters
            ani   15
            lbnz  ascbyte

            str   rf                    ; zero terminate the line

            irx                         ; recover starting print position
            ldx
            plo   rf

            sep   scall                 ; jump to output and then return
            dw    o_msg

            sep   sret


          ; Return to exit, but first restore the original console echo flag
          ; that we saved at start, before disabling echo.

endedit:    irx                         ; restore original console echo
            ldx
            phi   re

            sep   scall                 ; output newline
            dw    o_inmsg
            db    13,10,0

            lbr   getline






          ; The following buffer is used to compose the output data in memory
          ; before sending to the console. To simplify pointer manipulation
          ; it is aligned to lie entirely within one memory page.

            org   (($-1)|255)+1

backspc:    db    8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8
            db    8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,0
            db    10
            db    13
buffer:     ds    0

            org   (($-1)|255)+1

sector:     ds    512

end:        end   begin

