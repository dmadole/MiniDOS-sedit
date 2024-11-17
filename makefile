
all: sedit.bin

lbr: sedit.lbr

clean:
	rm -f sedit.lst
	rm -f sedit.bin
	rm -f sedit.lbr

sedit.bin: sedit.asm include/bios.inc include/kernel.inc
	asm02 -L -b sedit.asm
	rm -f sedit.build

sedit.lbr: sedit.bin
	rm -f sedit.lbr
	lbradd sedit.lbr sedit.bin

