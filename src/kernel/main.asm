org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A


start:
	jmp main

puts:
	push si
	push ax
	push bx

.loop:
	lodsb
	or al, al
	jz .done

	mov ah, 0x0E 	; bios interrupt
	mov bh, 0 	; page number
	int 0x10

	jmp .loop


.done:
	pop bx
	pop ax
	pop si
	ret

main:
	mov ax, 0
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00
	mov si, msg_hello

	call puts
	call puts
	mov si, msg_keyboard
	call puts
	call puts
	mov si, msg_hello
	call puts
	call puts

msg_hello: db "nastya is a cat", ENDL, 0
msg_keyboard: db "KEYBOARD", ENDL, 0

times 510-($-$$) db 0
dw 0AA55h