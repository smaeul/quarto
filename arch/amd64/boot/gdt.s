;
; arch/arm64/boot/gdt.s - GDT and friends definition
;
; Copyright 2012-2013 Samuel Holland <samuel@sholland.net>
;

format elf64

include "asm/constants.inc"
include "asm/memmap.inc"

public gdt_data
public gdt_ptr

section '.loaderdata' align 16

align 16			; Beginning of data
gdt_data:			; Prebuilt GDT entries
	dw	0xFFFF,0x0000	;   Kernel 32-bit code
	dw	0x9E00,0x00CF
	dw	0xFFFF,0x0000	;   Kernel 32-bit data
	dw	0x9200,0x00CF
	dw	0x0000,0x0000	;   Kernel 64-bit code
	dw	0x9A00,0x00A0
	dw	0x0000,0x0000	;   Kernel 64-bit data
	dw	0x9200,0x00C0
	dw	0x0000,0x0000	;   User 64-bit code
	dw	0xFA00,0x00A0
	dw	0x0000,0x0000	;   User 64-bit data
	dw	0xF200,0x00C0
	dw	0,0		;   TSS
	dw	0,0
	dw	0,0
	dw	0,0

gdt_ptr:			; GDTR structure
	dw	0x0FFF		;   GDT size (one page)
	dq	gdt+HM		;   GDT starting address


