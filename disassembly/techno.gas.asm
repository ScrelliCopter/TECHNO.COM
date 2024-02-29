# TECHNO.COM (payload only) Disassembly by a dinosaur 2022, 2024 (original author unknown)
# Binary MD5: 4CB859537BCD7BFB9FC5BFD6D74F4782
#     SHA256: BA33A41BA51C3D56B27107A94EF7842235B6D80A3A5B8710AEBDD87EB3A1905C
# Assemble with GAS: as techno.gas.asm -o techno.gas.o
#                    ld -Ttext 0x100 techno.gas.o -o techno.elf
#                    objcopy -O binary techno.elf techno.com

	.code16
	.section .text
#	.org 0x100

	.global start
start:
	push		%cs
	pop		%ds
	jmp		main
	nop

	.global exit
exit:
	call		disable_timer2
	mov		$0x4C, %ah
	int		$0x21

# Params: SI=Bigchar Pointer
#         DI=Screen pos
#         AL=Character
#         AH=Cell Attrib
# Side effects: SI += 7
	.global draw_bigchar
draw_bigchar:
	push		%di
	push		%bx
	push		%cx
	mov		$7, %cx
next_line:					# for (j=0; j<7; ++j):
	push		%cx
	push		%di
	mov		$8, %cx
	mov		(%si), %bl		#   BL = (*SI++)
	inc		%si
cont_line:					#   for (i=0; i<8; ++i):
	shl		$1, %bl			#     if (0x100 & BL <<= 1):
	jb		plot_char
	inc		%di
	inc		%di
	loop		cont_line
end_line:
	pop		%di
	pop		%cx
	add		$(2 * 80), %di		#   Next line
	loop		next_line
	pop		%cx
	pop		%bx
	pop		%di
	ret
plot_char:					# fn plot_char(AX, DI):
	stosw					#   ES:[DI] = AX
	loop		cont_line
	jmp		end_line

# Arguments: DX = timer2 frequency
	.global beep
beep:
	push		%ax
	mov		$0b10110110, %al	# 0   - 16 bit mode
						# 1-3 - Mode 3 (Square wave generator)
						# 4-5 - Access mode: lobyte/hibyte
						# 6-7 - Channel 2
	out		%al, $0x43		# Timer 8253-5 control bits
	{load} mov	%dl, %al
	out		%al, $0x42		# Timer 8253-5 lo byte
	{load} mov	%dh, %al
	out		%al, $0x42		# Timer 8253-5 hi byte
	in		$0x61, %al		# Read 8255 port B state
	or		$0b00000011, %al	# Enable Timer 2 Speaker
	out		%al, $0x61		# Write 8255 B state
	pop		%ax
	ret

	.global disable_timer2
disable_timer2:
	push		%ax
	in		$0x61, %al
	and		$0b11111100, %al
	out		%al, $0x61
	pop		%ax
	ret

# Return: AX = 0040:006C - BIOS Counter
	.global get_counter
get_counter:
	push		%ds
	mov		$0x40, %ax		# Segment 0040 (BIOS)
	mov		%ax, %ds
	mov		0x6C, %ax		# AX = 0040:006C - BIOS Counter
	pop		%ds
	ret


# Wait for next BIOS counter tick
	.global wait_nexttick
wait_nexttick:
	push		%ax
	push		%bx
	call		get_counter
	{load} mov	%ax, %bx
busywait:
	call		get_counter		# AX=BIOS counter
	{load} cmp	%ax, %bx
	jz		busywait
	pop		%bx
	pop		%ax
	ret

	.global main
main:
	mov		$0xF, %ah
	int		$0x10			# Get current video mode (AL=mode, BH=curent page)
	{load} mov	%al, %bl
	mov		$0xB800, %ax		# Colour displays have their text buffer at B800:0000
	cmp		$0x7, %bl		# Check if video mode is monochrome
	jnz		not_mda
	mov		$0xB000, %ax		# Monochrome displays' buffer begins at B000:0000
not_mda:
	mov		%ax, %es		# Store video segment in Extra Segment
	mov		$0x07DC, %ax		# Initial character Light Grey on Black, 0xDC
	mov		$0xDFDC, %dx		# Dancing cursor character pair, Lower half block, Upper half block
	mov		$phrase, %bx
	mov		$(80 * 25), %cx
	mov		$str_techno, %si	# "  TECHNO "
	{load} xor	%di, %di		# DI = 0
main_loop:
	mov		%ax, %es:(%di)		# Write cursor character
	test		$1, %cl			# Skip over on odd cycles
	jnz		odd_skip		#  to run music code at half-speed
	push		%dx
	cmpb		$0, (%bx)		# FZ at the end of the musical phrase
	jnz		goto_beep
	push		%ax
	push		%cx
	mov		$freqtbl, %bx
	mov		mangler, %ax
	mov		$4, %cx
loop_mangle_freqtbl:				# for (int i=0; i<4; ++i):
	xor		%ax, (%bx)		# Mangle the frequency LUT at the end of every measure
	inc		%bx
	inc		%bx
	loop		loop_mangle_freqtbl
	pop		%cx
	pop		%ax
	mov		$phrase, %bx
goto_beep:
	push		%bx
	mov		(%bx), %bl		# Fetch current note index
	dec		%bl			# Phrase uses 1-based indicies because of the 0 terminator
						# So we need to convert it to 0-indexed
	mov		$0, %bh			# BX &= 0xFF
	shl		$1, %bl
	mov		freqtbl(%bx), %dx	# Store frequency from note index into DX
	call		beep			# Beep with loaded frequency
	pop		%bx
	pop		%dx
	inc		%bx
odd_skip:
	call		wait_nexttick		# Wait for next BIOS counter tick
	lodsb					# AL = DS:[SI] (get character)
	cmp		$0, %al
	jnz		skip_nulterm
	mov		$str_techno, %si	# Reset string on null terminator
	lodsb
skip_nulterm:
	stosw					# Write string character
	#FIXME: Every GAS seems swap the operands no matter what
	.byte 0x86, 0xD6			# xchg %dh, %dl # Swap cursor half-blocks
	{load} mov	%dl, %al
	incw		mangler
	push		%ax
check_keyboard:
	mov		$1, %ah
	int		$0x16			# Check for keypresses (AH=scan code, AL=char, ZF=1 if buffer empty)
	jz		no_keyboard_input
	mov		$0, %ah
	int		$0x16			# Read char from buffer (AH=scan code, AL=char)
	cmp		$0x1B, %al
	jnz		skip_earlyexit
	incb		esc_counter 		# Exit if escape pressed twice
	cmpb		$2, esc_counter
	jnz		skip_earlyexit
	jmp		exit
skip_earlyexit:
	cmp		$str_notuch, %si	# Avoid restarting notouch prompt if already active
	jnb		notuch_skip
	mov		$str_notuch, %si	# " >>Don't touch the keyboard<< "
notuch_skip:
	jmp		check_keyboard
no_keyboard_input:
	pop		%ax
	loop		main_loop		# Loop over every character on the screen
	call		disable_timer2		# Stop beeping
	mov		$(8*160+13*2), %di	# row=8, col=13
	mov		$0x07B0, %ax		# FG=Light Grey on Black, Light shade block
	mov		$9, %cx
loop_rows:					# for (j=0; j<9; ++j):
	push		%cx
	push		%di
	mov		$53, %cx		#   for (i=0; i<53; ++i):
	rep stosw				#     (*ES:DI) = AX; DI += 2
	pop		%di
	pop		%cx
	add		$(80 * 2), %di		# row += 1
	loop		loop_rows
	mov		$(9*160+15*2), %di	# row=9, col=15
	mov		$0x70, %ah		# BG=Either Light Grey or White + Blink depending on video mode
	mov		$bigtext, %si
	mov		$6, %cx
	mov		$(str_techno + 2), %bx	# "TECHNO"
loop_bigchar:					# for (i=0; i<6; ++i):
	mov		(%bx), %al		#   Load character into accum low
	inc		%bx			#   Next character
	call		draw_bigchar
	add		$0x10, %di
	loop		loop_bigchar
	mov		$20, %cx
wait_loop:
	call		wait_nexttick		# Wait for 20 ticks
	loop		wait_loop
	mov		$0, %ah
	int		$0x16			# Wait for keypress
	{load} xor	%di, %di		# DI = 0
	mov		$(80 * 25), %cx
	mov		$0x0720, %ax		# FG=Light Grey on Black, space
	rep stosw				# Clear the whole screen
	jmp		exit

str_techno: .string "  TECHNO "
str_notuch: .string " \257Don't touch the keyboard\256 "

mangler: .word 0x0404

freqtbl: .word 5424, 2712, 2416, 2280

phrase:	.byte 3, 2, 1, 1, 2, 1, 1, 2, 1, 1, 3, 2, 1
	.byte 1, 2, 1, 1, 2, 1, 1, 3, 2, 1, 1, 2, 1
	.byte 1, 2, 1, 1, 3, 4, 1, 4, 1, 4, 1, 4, 0

bigtext:
	.byte 0b1111111		# 'T'
	.byte 0b0001000
	.byte 0b0001000
	.byte 0b0001000
	.byte 0b0001000
	.byte 0b0001000
	.byte 0b0001000

	.byte 0b1111111		# 'E'
	.byte 0b1000000
	.byte 0b1000000
	.byte 0b1111100
	.byte 0b1000000
	.byte 0b1000000
	.byte 0b1111111

	.byte 0b0111111		# 'C'
	.byte 0b1000000
	.byte 0b1000000
	.byte 0b1000000
	.byte 0b1000000
	.byte 0b1000000
	.byte 0b0111111

	.byte 0b1000001		# 'H'
	.byte 0b1000001
	.byte 0b1000001
	.byte 0b1111111
	.byte 0b1000001
	.byte 0b1000001
	.byte 0b1000001

	.byte 0b1000001		# 'N'
	.byte 0b1100001
	.byte 0b1010001
	.byte 0b1001001
	.byte 0b1000101
	.byte 0b1000011
	.byte 0b1000001

	.byte 0b0111110		# 'O'
	.byte 0b1000001
	.byte 0b1000001
	.byte 0b1000001
	.byte 0b1000001
	.byte 0b1000001
	.byte 0b0111110

esc_counter: .byte 0
