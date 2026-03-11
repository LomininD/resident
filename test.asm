.model tiny
.code
org 100h

Start:
		push 0b800h
		pop es
		mov bx, (80d*5 + 40d) * 2
		mov ah, 4eh

Next:
		in al, 60h
		mov es:[bx], ax
		cmp al, 1
		jne Next

		mov ax, 4c00h
		int 21h
	
end 		Start

