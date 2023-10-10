org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A

;
; FAT32 header
;
jmp short start
nop


bdb_oem:                    db 'MSWIN4.1'
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_secotrs:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880
bdb_media_descriptor_type:  db 0F0h           ; F0 - 3,5 дискета
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0


; расширенная загрузочная запись
ebr_drive_number:           db 0
                            db 0              ; зарезервированный байт (нужен для windows NT)
ebr_signature:              db 29h
ebr_volume_id:              db 02h, 04h, 06h, 08h
ebr_volume_label:           db 'FUNNY OS   '
ebr_system_id:              db 'FAT12   '


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

  ; прочитаем что нибудь с диска
  ; биос должен установить номер диска, с которого грузимся
  mov [ebr_drive_number], dl

  mov ax, 1
  mov cl, 1
  mov bx, 0x7E00
  call disk_read

	mov si, msg_hello
	call puts

  cli 
  hlt
  

;
; Обработка ошибок
;
floppy_read_error:
  mov si, msg_read_failed
  call puts
  jmp wait_any_key_and_reboot


wait_any_key_and_reboot:
  mov ah, 0
  int 16h                             ; ждем нажатия на клавишу
  jmp 0FFFFh:0                        ; прыгаем в начало биоса, что должно перезагрузить машину

.halt:
  cli
  htl

lba_to_chs:

  push ax
  push dx

  xor dx, dx                          ; dx = 0
  div word [bdb_sectors_per_track]    ; ax = LBA / bdb_sectors_per_track
                                      ; dx = LBA % bdb_sectors_per_track
  inc dx                              ; dx = (LBA % bdb_sectors_per_track + 1) = sector
  mov cx, dx                          ; cx = sector

  xor dx, dx
  div word [bdb_heads]                ; ax = (LBA / bdb_sectors_per_track) / bdb_heads = cylinder
                                      ; dx = (LBA / bdb_sectors_per_track) % bdb_heads = heads
  mov dh, dl
  mov ch, al
  shl ah, 6
  or cl, ah

  pop ax
  mov dl, al
  pop ax
  ret

disk_read:

  push ax                             ; сохраняем все регистры которые мы будем менять
  push bx
  push cx
  push dx
  push di

  push cx
  call lba_to_chs
  pop ax

  mov ah, 02h
  mov di, 3

.retry:
  pusha
  stc                                 ; set carry flag
  int 13h
  jnc .done

  ; если чтение не удалось
  popa
  call disk_reset

  dec di
  test di, di
  jnz .retry

.fail:
  ; если все попытки неудачные, показываем ошибку
  jmp floppy_read_error

.done:
  popa

  pop di                             ; восстанавливаем все регистры которые мы поменяли
  pop dx
  pop cx
  pop bx
  pop ax
  ret

;
; Сбрасываем контроллер диска
;
disk_reset:
  pusha
  mov ah, 0
  stc
  int 13h
  jc floppy_read_error
  popa
  ret



msg_hello:          db "Funny kernel has booted", ENDL, 0
msg_read_failed:    db "Read failed", ENDL, 0


times 510-($-$$) db 0
dw 0AA55h
