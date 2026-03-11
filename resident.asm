; This program is a resident program which displays register values in a frame
; after pressing of key combination (control + left shift + ...)
;
; by LMD
;----------------------File Contents Start After This Line----------------------


.model tiny
.code
org 100h

locals @@

activation_key_scan_code = 15

Start:
		mov ax, 3508h		; get address of 08 int handler in es:bx 
		int 21h
		mov word ptr Old08Offset, bx
		mov bx, es
		mov word ptr Old08Seg, bx

		mov ax, 3509h		; get address of 09 int handler in es:bx 
		int 21h
		mov word ptr Old09Offset, bx
		mov bx, es
		mov word ptr Old09Seg, bx

		; NEW FUNCTION

		xor ax, ax
		mov es, ax
		mov bx, 4*08h		; address of 08 int handler is located at 
					; seg 0000h offs 4*09h
		cli			; intercepts timer with triple buffering 
		mov es:[bx], offset TripleBuffering
		mov ax, cs
		mov es:[bx+2], ax
		sti

		mov bx, 4*09h		; address of 08 int handler is located at 
					; seg 0000h offs 4*09h
		cli			; replaces existing 09 int handler addr 
		mov es:[bx], offset ResidentMain	; with new one
		mov ax, cs
		mov es:[bx+2], ax
		sti

		mov ax, 3100h		; makes program stay resident
		mov dx, offset EndOfProg
		mov cl, 4
		shr dx, cl		; dx stores memory in paragraphs	
		inc dx
		int 21h

FrameDisplay	db 0			; 0 - if frame not shown, 1 - overwise
SaveBuffer	dw 25 dup(80 dup(0))
DrawBuffer	dw 25 dup(80 dup(0))

;===============================================================================
; ResidentMain
;
; Main body of resident
; Entry:     -
; Exit:      -
; Expected:  -
; Destroyed: AX, 
;-------------------------------------------------------------------------------

ResidentMain	proc


		push ax bx es		; think about flags

		call CmpKeystroke
		cmp al, 1
		jne @@Ret

		cmp FrameDisplay, 1	; decides to open or close frame
		je @@CloseFrame

		push 0b800h		; open frame
		pop es
		mov bx, (80d * 5 + 40d) * 2
		mov ax, 4e03h
		mov es:[bx], ax
		mov FrameDisplay, 1
		jmp @@Ret

@@CloseFrame:				; close frame
		push 0b800h
		pop es
		mov bx, (80d * 5 + 40d) * 2
		mov ax, 0000h
		mov es:[bx], ax
		mov FrameDisplay, 0

@@Ret:
; 		in al, 61h		; basic householding not needed as we
; 		or al, 80h		; redirect to old handler that already
; 		out 61h, al		; has it
; 		and al, not 80h
; 		out 61h, al
; 
; 		mov al, 20h
; 		out 20h, al

		pop es bx ax

		db 0eah			; will be translated to jmp
Old09Offset:	dw 0000h		; this part will be modificated
Old09Seg:	dw 0000h		; to jmp OldSeg:OldOffset

		iret			; ret flags???
		endp

;===============================================================================
; CmpKeystroke
;
; Compares if pressed combination is control + shift + ... by reading 60h port
; and flags located at 0040:0017h via int 16h 02h
; Entry:     -
; Exit:      AL <- 0 - false, 1 - true
; Expected:  -
; Destroyed: AX
;-------------------------------------------------------------------------------

CmpKeystroke	proc

		in al, 60h
		cmp al, activation_key_scan_code
		je @@IsActKey
		jmp @@WrongComb
		;jne @@WrongComb

@@IsActKey:				; checking for control+shift pressed
		mov ah, 02h
		int 16h			; puts in al kbd shift status flags
		and al, 04h		; masks of the required flag

		cmp al, 0
		je @@WrongComb

		mov al, 1		; required combination is pressed
		ret

@@WrongComb:				; required combination was not pressed
		mov al, 0
		ret
		endp

;===============================================================================
; TripleBuffering
;
; Keeps up-to-date screen status and updates if any changes happening
; Entry:     -
; Exit:      -
; Expected:  -
; Destroyed: UPDATE
;-------------------------------------------------------------------------------

TripleBuffering	proc



		db 0eah			; will be translated to jmp
Old08Offset:	dw 0000h		; this part will be modificated
Old08Seg:	dw 0000h		; to jmp OldSeg:OldOffset

		iret
		endp

EndOfProg:
end 		Start

