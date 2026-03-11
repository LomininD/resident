.model tiny
.code
org 100h

Start:
		int 09h

		mov ax, 3100h
		mov dx, offset EOPP
		shr dx, 4
		inc dx
		int 21h

EOPP:
end 		Start

