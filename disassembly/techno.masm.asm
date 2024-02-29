; TECHNO.COM (payload only) Disassembly by a dinosaur 2022, 2024 (original author unknown)
; Binary MD5: 4CB859537BCD7BFB9FC5BFD6D74F4782
;     SHA256: BA33A41BA51C3D56B27107A94EF7842235B6D80A3A5B8710AEBDD87EB3A1905C
;
; Assemble with Microsoft Macro Assembler: ml.exe /W3 techno~1.asm /Fotechno.com
; Assemble with JWasm: jwasmd.exe -bin -Fo techno.com techno~1.asm
; Assemble with Turbo Assembler: tasm.exe techno~1.asm techno.obj
;                                tlink.exe /t techno.obj, techno.com

		.model	tiny
		.8086
		.code
		org		100h

start:
		push	cs						; https://stackoverflow.com/a/53604793
		pop		ds
		jmp		main
ifndef ??version						; Only pad if we're not Turbo Assembler (which will pad anyway)
		nop
endif

exit:
		call	disable_timer2
		mov		ah, 4Ch					; Quit with exit code (AL)
		int		21h

; Params: SI=Bigchar Pointer
;         DI=Screen pos
;         AL=Character
;         AH=Cell Attrib
; Side effects: SI += 7
draw_bigchar:
		push	di
		push	bx
		push	cx
		mov		cx, 7
next_line:								; for (j=0; j<7; ++j):
		push	cx
		push	di
		mov		cx, 8
		mov		bl, [si]				;   BL = (*SI++)
		inc		si
cont_line:								;   for (i=0; i<8; ++i):
		shl		bl, 1					;     if (0x100 & BL <<= 1):
		jb		plot_char				;       plot_char()
		inc		di						;       DI += 2
		inc		di
		loop	cont_line
end_line:
		pop		di
		pop		cx
		add		di, 2 * 80				;   Next line
		loop	next_line
		pop		cx
		pop		bx
		pop		di
		ret
plot_char:								; fn plot_char(AX, DI):
		stosw							;   ES:[DI] = AX
		loop	cont_line
		jmp		end_line

; Arguments: DX = timer2 frequency
beep:
		push	ax
		mov		al, 10110110b			; 0   - 16 bit mode
										; 1-3 - Mode 3 (Square wave generator)
										; 4-5 - Access mode: lobyte/hibyte
										; 6-7 - Channel 2
		out		43h, al					; Timer 8253-5 control bits
		mov		al, dl
		out		42h, al					; Timer 8253-5 lo byte
		mov		al, dh
		out		42h, al					; Timer 8253-5 hi byte
		in		al, 61h					; Read 8255 port B state
		or		al, 00000011b			; Enable Timer 2 Speaker
		out		61h, al					; Write 8255 B state
		pop		ax
		ret

disable_timer2:
		push	ax
		in		al, 61h					; Read 8255 port state
		and		al, 11111100b			; Disable Timer 2 Speaker
		out		61h, al					; Write 8255 state
		pop		ax
		ret

; Return: AX = 0040:006C - BIOS Counter
get_counter:
		push	ds
		mov		ax, 40h					; Segment 0040 (BIOS)
		mov		ds, ax
		mov		ax, [ds:006Ch]			; AX = 0040:006C - BIOS Counter
		pop		ds
		ret

; Wait for next BIOS counter tick
wait_nexttick:
		push	ax
		push	bx
		call	get_counter
		mov		bx, ax
busywait:
		call	get_counter				; AX=BIOS counter
		cmp		bx, ax
		jz		busywait
		pop		bx
		pop		ax
		ret

main:
		mov		ah, 0Fh
		int		10h						; Get current video mode (AL=mode, BH=curent page)
		mov		bl, al
		mov		ax, 0B800h				; Colour displays have their text buffer at B800:0000
		cmp		bl, 7					; Check if video mode is monochrome
		jnz		not_mda
		mov		ax, 0B000h				; Monochrome displays' buffer begins at B000:0000
not_mda:
		mov		es, ax					; Store video segment in Extra Segment
		mov		ax, 07DCh				; Initial character Light Grey on Black, 0xDC
		mov		dx, 0DFDCh				; Dancing cursor character pair, Lower half block, Upper half block
		mov		bx, offset phrase
		mov		cx, 80 * 25
		mov		si, offset str_techno	; "  TECHNO "
		xor		di, di					; DI = 0
main_loop:
		mov		es:[di], ax				; Write cursor character
		test	cl, 1					; Skip over on odd cycles
		jnz		odd_skip				;  to run music code at half-speed
		push	dx
		cmp		byte ptr [bx], 0		; FZ at the end of the musical phrase
		jnz		goto_beep
		push	ax
		push	cx
		mov		bx, offset freqtbl
		mov		ax,	[mangler]
		mov		cx, 4
loop_mangle_freqtbl:					; for (int i=0; i<4; ++i):
		xor		[bx], ax				; Mangle the frequency LUT at the end of every measure
		inc		bx
		inc		bx
		loop	loop_mangle_freqtbl
		pop		cx
		pop		ax
		mov		bx, offset phrase
goto_beep:
		push	bx
		mov		bl, [bx]				; Fetch current note index
		dec		bl						; Phrase uses 1-based indicies because of the 0 terminator
										; So we need to convert it to 0-indexed
		mov		bh, 0					; BX &= 0xFF
		shl		bl, 1					;
		mov		dx,	[freqtbl + bx]		; Store frequency from note index into DX
		call	beep					; Beep with loaded frequency
		pop		bx
		pop		dx
		inc		bx
odd_skip:
		call	wait_nexttick			; Wait for next BIOS counter tick
		lodsb							; AL = DS:[SI] (get character)
		cmp		al, 0
		jnz		skip_nulterm
		mov		si, offset str_techno	; Reset string on null terminator
		lodsb
skip_nulterm:
		stosw							; Write string character
		xchg	dl, dh					; Swap cursor half-blocks
		mov		al, dl
		inc		[mangler]
		push	ax
check_keyboard:
		mov		ah, 1
		int		16h						; Check for keypresses (AH=scan code, AL=char, ZF=1 if buffer empty)
		jz		no_keyboard_input
		mov		ah, 0
		int		16h						; Read char from buffer (AH=scan code, AL=char)
		cmp		al, 1Bh
		jnz		skip_earlyexit
		inc		[esc_counter]			; Exit if escape pressed twice
		cmp		[esc_counter], 2
		jnz		skip_earlyexit
		jmp		exit
skip_earlyexit:
		cmp		si, offset str_notuch	; Avoid restarting notouch prompt if already active
		jnb		notuch_skip
		mov		si, offset str_notuch	; " >>Don't touch the keyboard<< "
notuch_skip:
		jmp		check_keyboard
no_keyboard_input:
		pop		ax
		loop	main_loop				; Loop over every character on the screen
		call	disable_timer2			; Stop beeping
		mov		di, 8 * 160 + 13 * 2	; row=8, col=13
		mov		ax, 07B0h				; FG=Light Grey on Black, Light shade block
		mov		cx, 9
loop_rows:								; for (j=0; j<9; ++j):
		push	cx
		push	di
		mov		cx, 53					;   for (i=0; i<53; ++i):
		rep stosw						;     (*ES:DI) = AX; DI += 2
		pop		di
		pop		cx
		add		di, 80 * 2				; row += 1
		loop	loop_rows
		mov		di, 9 * 160 + 15 * 2	; row=9, col=15
		mov		ah, 70h					; BG=Either Light Grey or White + Blink depending on video mode
		mov		si, offset bigtext
		mov		cx, 6
		mov		bx, offset str_techno+2	; "TECHNO"
loop_bigchar:							; for (i=0; i<6; ++i):
		mov		al, [bx]				;   Load character into accum low
		inc		bx						;   Next character
		call	draw_bigchar
		add		di, 10h
		loop	loop_bigchar
		mov		cx, 20
wait_loop:
		call	wait_nexttick			; Wait for 20 ticks
		loop	wait_loop
		mov		ah, 0
		int		16h						; Wait for keypress
		xor		di, di					; DI = 0
		mov		cx, 80 * 25
		mov		ax, 0720h				; FG=Light Grey on Black, space
		rep stosw						; Clear the whole screen
		jmp		exit

str_techno	db '  TECHNO ',0
str_notuch	db ' ',0AFh,'Don',27h,'t touch the keyboard',0AEh,' ',0

mangler	dw 0404h
freqtbl	dw 5424, 2712, 2416, 2280
phrase	db 3 dup(3, 2, 1, 1, 2, 1, 1, 2, 1, 1), 3, 4, 3 dup(1, 4), 0

bigtext	db 1111111b			; 'T'
		db 0001000b
		db 0001000b
		db 0001000b
		db 0001000b
		db 0001000b
		db 0001000b

		db 1111111b			; 'E'
		db 1000000b
		db 1000000b
		db 1111100b
		db 1000000b
		db 1000000b
		db 1111111b

		db 0111111b			; 'C'
		db 1000000b
		db 1000000b
		db 1000000b
		db 1000000b
		db 1000000b
		db 0111111b

		db 1000001b			; 'H'
		db 1000001b
		db 1000001b
		db 1111111b
		db 1000001b
		db 1000001b
		db 1000001b

		db 1000001b			; 'N'
		db 1100001b
		db 1010001b
		db 1001001b
		db 1000101b
		db 1000011b
		db 1000001b

		db 0111110b			; 'O'
		db 1000001b
		db 1000001b
		db 1000001b
		db 1000001b
		db 1000001b
		db 0111110b

esc_counter	db 0

		END start
