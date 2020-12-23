; atoi-itoa.asm
;
; Fetch the user input as ASCII and convert to an usigned 64-bit integer
; via ATOI. Then, convert the integer back to ascii again ITOA and print
; the result, or an error if the number is too large.
;
; Limitations:
;   => right now only handles unsigned 64-bit integers
;   => can add more bad input validation
;
; Use syscalls instead of any C libraries for fun.
; Runs OK on Linux with
; => NASM version 2.15.04 (sudo apt install nasm)
; => MAKE GNU Make 4.3
; => GCC 10.2.0

; printNewline prints a newline.
%macro printNewline 0
        push 0xA
        push 0x1
        call _printStr
%endmacro

; Credit to https://stackoverflow.com/a/47756662 for clever approach
; multiPush pushes the parameters in order
; for saving registers modified in procs.
%macro multiPush 1-*
    %assign i 1
    %rep %0
        push %1
        %rotate 1
    %endrep
%endmacro

; multiPop pops the parameters in reverse order
; for restoring registers modified in procs.
%macro multiPop 1-*
    %assign i 1
    %rep %0
        %rotate -1
        pop %1
    %endrep
%endmacro

; stackEnter sets up the stack frame
%macro stackEnter 0
    push rbp            ; set up stack frame
    mov rbp, rsp
%endmacro

; stackLeve restores the stack frame
%macro stackLeave 0
    mov rsp, rbp        ; restore stack frame
    pop rbp
%endmacro

section .data
    enterNumberMessage: db 'Enter a number: ',0
    enterNumberMessageLen: equ $ - enterNumberMessage

    message:           db 'HELLO THERE! ATOI ITOA converts your input to numeric then back to ASCII. Not so practical \
but so educational.',10,0                            ; 10 = new line, 0 = null terminator
    messageLen:        equ $ - message               ; length of message

    message2:          db 'To prove we are not cheating try entering 18446744073709551615 which \
is 2^64 - 1, the max unsigned 64-bit integer.',10,0
    message2Len:       equ $ - message2

    message3:          db 'Then enter 18446744073709551616 and you will see an error that it is too big.',10,0
    message3Len:       equ $ - message3

    message4:          db 'HERE IS YOUR CONVERTED NUMBER: ',0
    message4Len:       equ $ - message4

    repeat:            db 10,'Would you like to repeat? y for yes anything else to quit: ',0
    repeatLen:         equ $ - repeat

    thisLine:          times 255 db 0
    thisLineLen:       equ $ - thisLine

    convRes:           times 22 db 0                ; conversion result output.
    convResLen:        equ $ - convRes              ; max 21 chars + 1 null byte

    errNumTooBig:      db 'error: number too large to convert, bigger than 2^64 - 1',10,0
    errNumTooBigLen:   equ $ - errNumTooBig

    yesRepeatAnswer:   db 'y',10,0

    exitStatus:        db 0                    ; global exitStatus set after fns return. err != 0

section .text
    global _start

; clrStr clears all bytes in string with length.
; usage:
;   clrStr strAddr, strLen
%macro clrStr 2
    push %1
    push %2
    call _clrStr
%endmacro

_clrStr:
    stackEnter
    multiPush rax, rcx, rdi
    mov rdi, [rbp+24]       ; put null byte in string starting here
    mov rcx, [rbp+16]       ; place null byte rcx times
    xor rax, rax
    mov al, 0               ; null byte
    rep stosb               ; place rcx times into rdi
    multiPop rax, rcx, rdi
    stackLeave
    ret 16                  ; called with 2 QWords * 8 bytes


; strncmp compares the two strings for the first N characters and returns 0 in eax
; if equal, something else if not.

; usage:
;   strncmp str1Addr, str2Addr, numCharsToCompre
;   returns rax == 0 if equal to numCharsToCompare, rax != 0 if not.
%macro strncmp 3
    push %1
    push %2
    push %3
    call _strncmp
%endmacro

_strncmp:
    cld
    stackEnter
    multiPush rcx, rsi, rdi
    mov rcx, [rbp+16]       ; num chars to compare
    mov rsi, [rbp+24]       ; first string
    mov rdi, [rbp+32]       ; second string
    repz cmpsb              ; compare until not equal or rcx reached. if rcx == 0 then match.
    mov rax, rcx            ; return result in rax
    multiPop rcx, rsi, rdi
    stackLeave
    ret 24                  ; called with 3 QWords * 8 bytes


; atoi converts an ASCII string to an integer
; usage:
;   atoi addrForResult, addrToConvert
%macro atoi 2
    push %1
    push %2
    call _atoi
%endmacro

_atoi:
    stackEnter
    multiPush rax, rbx, rdx, rdi, rsi

    mov rsi, [rbp+16]
    mov rbx, 10
    xor rax, rax
    xor rcx, rcx

    cld                     ; clear the direction flag
    atoi_looptop:
        xor rax, rax
        lodsb

        cmp rax, 0          ; quit at a null byte
        je atoi_done
        cmp rax, 0xA        ; or a newline
        je atoi_done

        sub al, 0x30        ; decimal val = ascii char - 30h

        mov rdx, rax
        push rdx
        mov rax, rcx
        mul rbx
        pop rdx
        add rax, rdx
        jc atoi_toobig      ; if carry flag set, too big for rax
        mov rcx, rax        ; (for now just doing unsigned ints)
        jmp atoi_looptop

    atoi_toobig:
        push errNumTooBig
        push errNumTooBigLen
        mov DWORD [exitStatus], 1
        call _printStr
        jmp atoi_quit

    atoi_done:
        mov [rbp+24], rcx

    atoi_quit:
        multiPop rax, rbx, rdx, rdi, rsi
        stackLeave
        ret 16             ; called with 2 QWords * 8 bytes


; itoa converts an integer to an ASCII string
; usage:
;   itoa addrForResult, intToConvert
%macro itoa 2
    push %1
    push %2
    call _itoa
%endmacro

_itoa:
    stackEnter
    multiPush rax, rbx, rdx, rdi, rsi

    xor rdx, rdx
    xor rax, rax
    mov rax, [rbp+16]       ; int to convert
    mov rdi, [rbp+24]       ; beginning of the string to output
    add rdi, convResLen
    std                     ; set direction flag so we can write the string backwards
    dec rdi                 ; null byte
    mov rbx, 10             ; conversion multiplier
    itoa_looptop:           ; write the ascii chars right-to-left w/trailing null byte
        xor rdx, rdx
        cmp rax, 0
        je itoa_done

        div rbx
        add rdx, 30h        ; ascii char = 30h + int value

        push rax
        mov al, dl
        stosb
        pop rax

        jmp itoa_looptop

    itoa_done:
        cld                 ; clear direction flag now that we're done writing
                            ; in reverse!
        multiPop rax, rbx, rdx, rdi, rsi
        stackLeave

        ret 16              ; called with 2 QWords * 8 bytes


; readLine fetches a single line of input from the user.
; usage:
;   readLine addrForResult, numCharsToFetch
%macro readLine 2
    push %1
    push %2
    call _readLine
%endmacro

_readLine:
    stackEnter
    multiPush rax, rdx, rdi, rsi
    mov rax, 0          ; read syscall
    mov rdi, 0          ; stdin file descriptor

    mov rsi, [rbp+24]   ; input buffer
    mov rdx, [rbp+16]   ; input buffer size
    dec rdx             ; minus 1 for null terminator

    syscall
    multiPop rax, rdx, rdi, rsi
    stackLeave
    ret 16              ; called with 2 QWords * 8 bytes


; printString prints the string passed with specified length.
; usage:
;   printString addrOfString, lenOfString
%macro printString 2
    push %1
    push %2
    call _printStr
%endmacro

_printStr:
    stackEnter
    multiPush rax, rdx, rdi, rsi
    mov rax, 1              ; WRITE is syscall 1
    mov rdi, 1              ; file descriptor stdout
    mov rsi, [rbp+24]       ; pointer to string
    mov rdx, [rbp+16]       ; string length in bytes

    syscall
    multiPop rax, rdx, rdi, rsi
    stackLeave
    ret 16                  ; called with 2 QWords * 8 bytes


; _start is the entrypoint of atoi-itoa
_start:
    mov DWORD[exitStatus], 0

    printString message, messageLen
    printString message2, message2Len
    printString message3, message3Len

; fetch the user's number
_start_fetch_input:
    printString enterNumberMessage, enterNumberMessageLen
    clrStr thisLine, thisLineLen
    readLine thisLine, thisLineLen

    atoi rcx, thisLine                        ; convert to integer, store res in rcx
    clrStr thisLine, thisLineLen              ; clear out for next go-around

    cmp DWORD [exitStatus], 0                 ; print conversion if atoi successful
    je _start_atoi_printRes
    jmp _start_atoi_failed                    ; otherwise print an error

_start_atoi_printRes:
        itoa convRes, rcx

        printString message4, message4Len
        printString convRes, convResLen
        printNewline

        clrStr convRes, convResLen

        printString repeat, repeatLen

        readLine thisLine, 3
        strncmp thisLine, yesRepeatAnswer, 2  ; loop if go again
        cmp rax, 0
        je _start_fetch_input
        jmp _start_exit                       ; otherwise exit

_start_atoi_failed:
    mov DWORD [exitStatus], 0                 ; show err message
    jmp _start_fetch_input                    ; loop again

_start_exit:
    mov rax, 60                               ; exit syscall
    mov rdi, 0                                ; return value
    syscall
