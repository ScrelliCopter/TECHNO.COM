# TECHNO.COM Disassemblies

The following are full disassemblies of the (Payload isolated) TECHNO.COM MS-DOS binary, and are intended to be
bit-exact with the original.
```
TECHNO.COM (Payload only)
MD5     = 4CB859537BCD7BFB9FC5BFD6D74F4782
SHA-1   = A2FB99D873912AC8B7CD05E15659F65DA5D119BF
SHA-256 = BA33A41BA51C3D56B27107A94EF7842235B6D80A3A5B8710AEBDD87EB3A1905C
```

### techno.nasm.asm
Netwide Assembler syntax, tested to work under [NASM](https://www.nasm.us/), [FASM](https://flatassembler.net/), and
[YASM](https://yasm.tortall.net/).

None of these assemblers have the ability to produce the original opcodes from mnemonics, so `db`'s are used where
needed and documented with the actual mnemonic.

### techno.masm.asm
Microsoft Macro Assembler syntax, tested and works under MASM 6.11, [JWasm v2.11](https://www.japheth.de/JWasm.html),
and Borland Turbo Assembler 5.0 (in MASM mode).

This [fork](https://github.com/JWasm/JWasm) of JWasm v2.12pre is recommended for assembling on modern platforms.

### techno.gas.asm
GNU Assembler (AT&T) syntax, tested with [IA-16 DJGPP](https://gitlab.com/tkchia/build-ia16/-/releases),
and i386-elf-binutils. mingw's `as` appears to work too but not its `ld`.
