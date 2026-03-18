; This program is a resident program which displays register values in a frame
; after pressing of key combination (control + left shift + ...)
;
; by LMD
;----------------------File Contents Start After This Line----------------------


.model tiny
.code
org 100h

locals @@

activation_key_scan_code = 15d
frame_height = 15			; height of frame
frame_width = 11 			; width of frame
frame_x	 = 1				; coords counted from top left corner
frame_y	 = 1				; coords of frame = coords of frame
					; top left corner

;----------------------------------- MACROS ------------------------------------

CopyStr		macro

@@DisplayLoop:
		lodsb
		stosw
		loop @@DisplayLoop

		endm

;-------------------------------------------------------------------------------

;---------------------------------- Main Body ----------------------------------

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

		; pushf
		; push cs
		; call ResidentMain
		

		mov ax, 3100h		; makes program stay resident
		mov dx, offset EndOfProg
		mov cl, 4
		shr dx, cl
		inc dx			; dx stores memory in paragraphs
		int 21h


SavedSP		dw 0			; saved value of sp
FrameDisplay	db 0			; 0 - if frame not shown, 1 - overwise
Color_Attr	db 4eh			; color of frame
FrameStyle	db 0cdh, 0bah, 0c9h, 0bbh, 0c8h, 0bch			
					; frame style arr
SaveBuffer	dw frame_height dup(frame_width dup(4e03h))
DrawBuffer	dw frame_height dup(frame_width dup(4e03h))
RegString	db ' AX ', ' BX ', ' CX ', ' DX ', ' SI ', ' DI ', ' BP '
		db ' SP ', ' DS ', ' ES ', ' SS ', ' CS ', ' IP '
RegOffsets	db 8d, 10d, 12d, 14d, 16d, 18d, 20d, 28d, 22d, 24d, 26d, 4d, 6d
		; offsets for saved register in stack

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
; Destroyed: -
;-------------------------------------------------------------------------------

ResidentMain	proc
		cli


		; when int happens Flags, CS, IP are pushed in stack
		; so SP is decremented by 6 as pushed regs are 2 bytes each

		push ax				; saves ax
		mov ax, sp
		add ax, 8			; 3 int pushes + ax push
		mov cs:[SavedSP], ax		; saves original sp

		push bx cx dx si di bp ds es ss	ax	; saves other regs
						; ax <=> sp

		; registers are stored in this order: 
		; [old] Flags, CS, IP, AX, BX, CX, DX, SI, DI, BP, DS, ES, SS
		; <---------------- SP grows in this direction ----------------
		; ^SP^ = SavedSP

		mov ax, cs
		mov ds, ax

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

		push ds
		pop es
		call DrawFrame		; draws frame in draw buffer

		push 0b800h
		pop es
		mov di, (80d * frame_y + frame_x) * 2
		mov si, offset DrawBuffer
		push di
		call FlushBuffer	; copies draw buffer to screen
		pop di

		mov FrameDisplay, 1
		jmp @@Ret

@@CloseFrame:
		push 0b800h
		pop es
		mov di, (80d * frame_y + frame_x) * 2
		mov si, offset SaveBuffer
		push di
		call FlushBuffer	; copies save buffer to screen
		pop di
		mov FrameDisplay, 0

@@Ret:
		pop ax ss es ds bp di si dx cx bx ax

		sti

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
; Destroyed: -
;-------------------------------------------------------------------------------

TripleBuffering	proc			; updates frame, so it is always on top
					; triple buffering makes everything 
		cli			; behind frame up-to-date

 		push ax bx cx es ds si di dx

		mov ax, cs
		mov ds, ax

 		cmp FrameDisplay, 0	; disables updating if frame is disabled
 		je @@SkipUpdate

		mov ax, 0b800h
		mov es, ax
		call UpdateBuffer

 @@SkipUpdate:	pop dx di si ds es cx bx ax

		sti

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
		sub si, frame_width * 2
		pop cx
		loop @@CopyLoop

		push ds			; swaps back ds and es
		push es
		pop ds
		pop es

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

		cld
		mov cx, frame_height

@@CopyLoop:				; copies buffer data to frame area
		push cx
		mov cx, frame_width
		rep movsw

		add di, 80*2		; moves to next line
		sub di, frame_width * 2
		pop cx
		loop @@CopyLoop

		ret
		endp

;===============================================================================
; UpdateBuffer
;
; Updates draw buffer comparing it with screen
; Entry:     ES - video memory segment
;	     DS - data segment
; Exit:      -
; Expected:  -
; Destroyed: DI, SI, CX, AX, BX, DX
;-------------------------------------------------------------------------------

UpdateBuffer	proc

		mov di, (80d * frame_y + frame_x) * 2	; es:di video mem coords
		mov bx, offset DrawBuffer
		xor si, si			; ds:(bx + si) buffer address
		xor ax, ax			; ax = 0 - no changes made

		mov cx, frame_height

@@CmpFrame:				; compares lines
		push cx
		mov cx, frame_width

@@CmpLine:				; compares symbols in line
		mov dx, es:[di]
		cmp dx, ds:[bx+si]
		je @@Equal

		push bx			; replaces diff words in save buffer
		mov bx, offset SaveBuffer	; not draw buffer!
		mov word ptr ds:[bx+si], dx
		pop bx
		mov ax, 1		; ax shows that replaces were made

@@Equal:
		add si, 2		; increments si and di
		add di, 2
		loop @@CmpLine

		pop cx
		sub di, frame_width * 2	; new line
		add di, 80 * 2
		loop @@CmpFrame


		cmp ax, 0		; checks if replaces happened
		je @@EndOfProg

		mov di, (80d * frame_y + frame_x) * 2
		mov si, offset DrawBuffer
		call FlushBuffer	; draws frame to make it on top

@@EndOfProg:
		ret
		endp

;===============================================================================
; DrawFrame
;
; Draws frame in buffer
; Entry:     ES -> draw buffer segment
;	     CS -> code segment
; Exit:      -
; Expected:  -
; Destroyed: AX, BX, CX, DI, SI, BP
;-------------------------------------------------------------------------------

DrawFrame	proc

		mov bx, 0
		mov di, offset DrawBuffer
		mov ah, Color_Attr

		call DrawHBorder	; draws horizontal top border

		mov cx, 13
		mov si, offset RegString
		mov bp, offset RegOffsets

@@DisplayLoop:
		push cx
		push si
		mov bx, SavedSP
		xor ax, ax
		mov al, byte ptr cs:[bp]
		sub bx, ax
		
		call ShowReg

		pop si
		pop cx

		add si, 4
		inc bp
		loop @@DisplayLoop


		mov bx, 1		; bx = 1 for bottom border
		call DrawHBorder	; draws horizontal bottom border

		ret
		endp

;===============================================================================
; DrawHBorder
;
; Draws horizontal border in buffer
; Entry:     ES -> draw buffer segment
;	     BX -> 0 - top border, 1 - bottom border
;	     DI -> buffer offset
; Exit:      -
; Expected:  -
; Destroyed: AX, BX, CX, DI
;-------------------------------------------------------------------------------

DrawHBorder	proc

		shl bx, 1		; modificates bx=0 -> bx=2
		add bx, 2		; 	      bx=1 -> bx=4

		mov ah, Color_Attr
		mov al, [FrameStyle + bx]
		stosw			; left corner

		mov cx, frame_width	; middle part of border
		sub cx, 2
		mov al, [FrameStyle]

		rep stosw		; draws mid part of upper hor border

		mov al, [FrameStyle + bx + 1]
		stosw			; right corner

		ret
		endp

;===============================================================================
; DrawEmptyLine
;
; Draws empty line in frame
; Entry:     ES -> video mem segment
;	     DI -> line offset for frame border
;	     CS -> code segment
; Exit:      -
; Expected:  -
; Destroyed: AX, CX, DI (usable after)
;-------------------------------------------------------------------------------

DrawEmptyLine	proc

		mov ah, Color_Attr
		mov al, [FrameStyle + 1]
		stosw			; draws part of left vert border

		mov al, 00h
		mov cx, frame_width
		sub cx, 2

		rep stosw		; fills with blank spaces

		mov al, [FrameStyle + 1]
		stosw			; draws part of right vert border

		ret
		endp

;===============================================================================
; ShowReg
;
; Displays register in frame
; Entry:     BX -> reg offset in SS
;	     DI -> line offset for frame border
;	     SI -> reg str offset
;	     CS -> code segment
; Exit:      -
; Expected:  -
; Destroyed: AX, BX, CX, SI (usable after), DI (usable after)
;-------------------------------------------------------------------------------

ShowReg		proc

		mov ah, Color_Attr
		mov al, [FrameStyle + 1]
		stosw			; draws part of left vert border

		mov cx, 4
		CopyStr			; copies StringAX to DrawBuffer

		push ax
		mov ax, ss:[bx]
		call LoadNumber
		pop ax

		mov al, 00h		; adds space after number
		stosw

		mov al, [FrameStyle + 1]
		stosw			; draws part of right vert border

		ret
		endp

;===============================================================================
; LoadNumber
;
; Displays AX register in frame
; Entry:
;	     SI -> line offset for frame border
;	     AX -> number to load
; Exit:      -
; Expected:  -
; Destroyed: AX, BX
;-------------------------------------------------------------------------------

LoadNumber	proc

		push cx			; save cx
		mov bx, 0f000h
		mov cx, 4		; 4-digit number
		xor dx, dx

@@ParseNum:
		push ax			; save original number
		and ax, bx		; mask off required digit

		push cx			; save cx 
		dec cx
		shl cx, 2		; cx = 4 * (cx - 1)

		shr ax, cl		; move required digit to the right

		call DigitToStr

		shr bx, 4		; bx masks off next digit
		pop cx
		pop ax
		loop @@ParseNum

		pop cx			; restore cx

		ret
		endp

;===============================================================================
; DigitToStr
;
; Converts digit to symbol and displays in buffer
; Entry:
;	     SI -> line offset for frame border
;	     AX -> digit
; Exit:      -
; Expected:  -
; Destroyed: AX
;-------------------------------------------------------------------------------

DigitToStr	proc

		cmp ax, 9
		ja @@IsAlpha

		add al, "0"
		jmp @@EndMacro

@@IsAlpha:	add al, "a"
		sub al, 10

@@EndMacro:	mov ah, Color_Attr
		stosw

		ret
		endp


EndOfProg:
end 		Start

