.model tiny
.code
org 100h

Start:

		;int 09h		; when this line is uncommented 
					; programm is launched twice, while it 
					; was manually launched once

		xor ax, ax
		mov es, ax
		mov bx, 4*09h

		cli
		mov es:[bx], offset New
		mov ax, cs
		mov es:[bx+2], ax
		sti

		mov ax, 3100h
		mov dx, offset EOPP
		shr dx, 4
		inc dx
		int 21h

New		proc
		push ax bx es

		push 0b800h
		pop es
		mov bx, (80d * 5 + 40d) * 2
		mov ah, 4eh

		in al, 60h
		mov es:[bx], ax

		in al, 61h
		or al, 80h
		out 61h, al
		and al, not 80h
		out 61h, al

		mov al, 20h
		out 20h, al


		pop es bx ax

		db 0eah
		dw 00c1h		; self modificate via variables
		dw 19a4h

		iret
		endp


EOPP:
end 		Start

