all:
	nasm -f elf64 -Wall atoi-itoa.asm -o atoi-itoa.o
	ld -s -o atoi-itoa atoi-itoa.o

debug:
	nasm -g -f elf64 -l atoi-itoa.lst atoi-itoa.asm
	gcc -m64 -o atoi-itoa atoi-itoa.o -nostdlib -no-pie

clean:
	rm -f atoi-itoa atoi-itoa.o

run:
	nasm -f elf64 -Wall atoi-itoa.asm -o atoi-itoa.o
	ld -s -o atoi-itoa atoi-itoa.o
	./atoi-itoa
