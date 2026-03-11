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
frame_height 		 = 17		; height of frame
frame_width		 = 11		; width of frame
frame_x			 = 0		; coords counted from top left corner
frame_y			 = 0		; coords of frame = coords of frame
					; top left corner



Start:
		mov ax, 3508h		; get address of 08 int handler in es:bx 
		int 21h
		mov word ptr Old08Offset, bx
		mov word ptr Old08Seg, es

		mov ax, 3509h		; get address of 09 int handler in es:bx 
		int 21h
		mov word ptr Old09Offset, bx
		mov word ptr Old09Seg, es


		xor ax, ax
		mov es, ax

		mov bx, 4*08h		; address of 08 int handler is located 
		mov ax, offset TripleBuffering	     ; at seg 0000h offs 4*09h
		call SetHandler		; intercepts timer with triple buffering 

		mov bx, 4*09h		; address of 09 int handler is located
		mov ax, offset ResidentMain	     ; at seg 0000h offs 4*09h
		call SetHandler		; replaces existing 09 int handler addr 


		push 0b800h
		pop es

		mov si, (80d * frame_y + frame_x) * 2
		mov di, offset SaveBuffer
		push si
		call LoadBuffer		; initializes save buffer before drawing 
		pop si

		call ClearScreen

		mov ax, 0100h		; waits for any key to be pressed
		int 21h

		mov di, (80d * frame_y + frame_x) * 2
		mov si, offset SaveBuffer
		push di
		call FlushBuffer
		pop di

		mov ax, 3100h		; makes program stay resident
		mov dx, offset EndOfProg
		mov cl, 4
		shr dx, cl	
		inc dx			; dx stores memory in paragraphs
		int 21h



FrameDisplay	db 0			; 0 - if frame not shown, 1 - overwise
SaveBuffer	dw frame_height dup(frame_width dup(0))
DrawBuffer	dw frame_height dup(frame_width dup(0))


;===============================================================================
; ClearScreen
;
; Dumps empty chars in video memory page
; Entry:     ES -> video mem segment
; Exit:      -
; Expected:  -
; Destroyed: AX, CX, DI (all regs saved)
;-------------------------------------------------------------------------------

ClearScreen	proc

		push ax			; saves all used registers
		push cx
		push di

		xor di, di		; of video memory
		mov ax, 0		; blank symbol on black bg
		mov cx, 80 * 25		; symbols in video page
		rep stosw

		pop di			; restores used registers values
		pop cx
		pop ax

		ret
		endp

;===============================================================================
; SetHandler
;
; Replace old handler label located at ES:BX with new label located at CS:AX
; Entry:     AX	- new handler offset
;	     CS - new handler segment
;	     BX - old handler offset
;	     Es - old handler label
; Exit:      -
; Expected:  -
; Destroyed: -
;-------------------------------------------------------------------------------

SetHandler	proc

		cli
		mov es:[bx], ax
		mov es:[bx+2], cs
		sti

		ret
		endp

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


		push ax si es		; think about flags

		call CmpKeystroke
		cmp al, 1
		jne @@Ret

		cmp FrameDisplay, 1	; decides to open or close frame
		je @@CloseFrame

@@OpenFrame:
		push 0b800h
		pop es
		mov si, (80d * frame_y + frame_x) * 2
		mov di, offset SaveBuffer
		push si
		call LoadBuffer		; initializes save buffer before drawing 
		pop si

		mov ax, 4e03h
		mov es:[si], ax
		mov FrameDisplay, 1
		jmp @@Ret

@@CloseFrame:
		push 0b800h
		pop es
		mov di, (80d * frame_y + frame_x) * 2
		mov si, offset SaveBuffer
		push di
		call FlushBuffer
		pop di

		mov ax, 0000h
		mov es:[di], ax
		mov FrameDisplay, 0

@@Ret:
; 		in al, 61h		; basic householding is not needed as we
; 		or al, 80h		; redirect to old handler that already
; 		out 61h, al		; has it
; 		and al, not 80h
; 		out 61h, al
; 
; 		mov al, 20h
; 		out 20h, al

		pop es si ax

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

;===============================================================================
; LoadBuffer
;
; Loads ES:SI of area for frame to DS:DI (buffer location)
; Entry:     ES - video memory segment
;	     SI - coordinates of top left corner of frame
;	     DS - data segment
;	     DI - buffer offset
; Exit:      -
; Expected:  -
; Destroyed: DI, SI, CX
;-------------------------------------------------------------------------------

LoadBuffer	proc

		cli

		push ds			; swaps ds and es 
		push es
		pop ds
		pop es

		cld
		mov cx, frame_height

@@CopyLoop:				; copies frame area to dedicated buffer 
		push cx
		mov cx, frame_width
		rep movsw
		add si, 80*2
		pop cx
		loop @@CopyLoop

		push ds
		push es
		pop ds
		pop es

		sti

		ret
		endp

;===============================================================================
; FlushBuffer
;
; Flushes buffer located on DS:SI buffer to ES:DI (frame area)
; Entry:     ES - video memory segment
;	     DI - coordinates of top left corner of frame
;	     DS - data segment
;	     SI - buffer offset
; Exit:      -
; Expected:  -
; Destroyed: DI, SI, CX
;-------------------------------------------------------------------------------

FlushBuffer	proc

		cli

		cld
		mov cx, frame_height

@@CopyLoop:				; buffer data to frame area
		push cx
		mov cx, frame_width
		rep movsw
		add di, 80*2
		pop cx
		loop @@CopyLoop

		sti

		ret
		endp




EndOfProg:
end 		Start

