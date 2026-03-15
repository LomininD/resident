.model tiny
.code
org 100h

Start:

	

MainLoop:
	mov ax, 1111h
	mov bx, 2222h
	mov cx, 3333h
	mov dx, 4444h
	mov si, 5555h
	mov di, 6666h
	mov bp, 7777h
	push 9999h
	pop es
	push 8888h
	pop ds
	

	in al, 60h
	cmp al, 2
	je Next
	jmp MainLoop

Next:
	mov ax, 4c00h
	int 21h



	
end 		Start

