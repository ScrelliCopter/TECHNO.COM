; 100-byte COM sacrificial goat executable (1993, author unknown)
; Binary MD6: 195307045CC39D6B284B60442ECFD202
;     SHA256: D1F60FCA64F1903F8D405109C5AA55A3F3B6DDE622BCFBA15CD95001CAE1DEE2
;
; Assemble with FASM: fasm goat.asm goat.com
; Assemble with NASM or YASM: nasm -fbin goat.asm -o goat.com

			use16
			org 100h

start:
			jmp		short print
			nop

hello_str	db 'Hello - This is a 100   COM test file, 1993', 0Ah, 0Dh, '$'  ; Hello followed by '\n\r'

			db 1Ah						; Pad with substitute
			times 41 db 'A'				;  and 'A' * 41

print:
			mov		ah, 9				; AH: Print string
			mov		dx, hello_str		; DS:DX: String = "Hello - This is a 100   COM test file, 1993"
			int		21h
			int		20h					; Return to DOS
