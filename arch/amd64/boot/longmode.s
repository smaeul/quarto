;
; arch/amd64/boot/longmode.s - PAE and long mode setup code
;
; Copyright 2012-2013 Samuel Holland <samuel@sholland.net>
;

format elf64

include "asm/constants.inc"
include "asm/gdt.inc"
include "asm/memmap.inc"

public	setup_longmode			; Used by multiboot.s and native.s
extrn	common				; Defined in common.rs

section '.loader'

use32
setup_longmode:
lowmem:					; Fill out structures in low memory
 .idt:					; First is the IDT at 0x0
	mov	edi,	idt		;   Clear the destination index
	xor	eax,	eax
	mov	ecx,	1024
	rep	stosd

; DO IT

 .gdt:					; Fill out GDT
	mov	edi,	gdt		;   Destination is GDT in low memory
	xor	eax,	eax		;   Clear register to be stored
	stosd				;   Write the null entry
	stosd				;     (two dwords long of 0)
	mov	esi,	gdt_data	;   Source is the prebuilt GDT entries
	mov	ecx,	16 		;   8 entries * 8 bytes = 16 dwords
	rep	movsd			;   Copy a dword at a time
	mov	ecx,	1006		;   512-9 entries * 2 dwords each
	rep	stosd			;   Zero out unused entries

 .pml4t:				; Create PML4T
	mov	eax,	pdpt+3		;   Physical address of PDPT + flags
	mov	edi,	pml4t		;   Destination pointer
	mov	ebx,	edi		;   Also put it in ebx
	stosd				;   Entry 0 -> PDPT (temporary)
					; **We set only the low dword because
					;   we are working with physical addr-
					;   esses, and the top dword of those
					;   is just 0.
	mov	edx,	eax		;   Save that value for later
	xor	eax,	eax		;   And clear eax
	mov	ecx,	1023		;   512*2 dwords - 1 dword already set
	rep	stosd			;   Zero out the entries
					;   edi is now at PML4T + 0x1000
	mov [edi-16],	ebx		;   Entry 510 -> PML4T (recursive)
	mov [edi-8],	edx		;   Entry 512 -> PDPT
	mov	cr3,	ebx		;   Load PML4T into CR3

 .pdpt:					; Fill out PDPT
	mov	eax,	pdt+3		;   Physical address of PDT's + flags
	xor	edx,	edx		;   High dword of each entry is 0
	mov	ecx,	64		;   64 GiB @ 1 Gib per PDPT entry
	mov	edi,	pdpt		;   Destination pointer (start of PDPT)
    @@:	stosd				;   Low dword of pdpt entry
	add	eax,	0x1000		;   Next PDT (4 KiB higher)
	mov	[edi],	edx		;   Zero out high dword
	add	edi,	4		;   Next pdpt entry address
	loop	@r			;   Decrement ecx and jump back up
	mov	eax,	edx		;   Move the zero into eax
	mov	ecx,	(512-64)*2	;   Clear the rest of the PDPT (all but
	rep	stosd			;     64 entries at 2 dwords each)

 .pdt:					; Fill out PDT's
	mov	eax,	0x183		;   0 MiB+flags RW,Present,Global,Size
	mov	ecx,	512*64		;   Number of entries (first 64 GiB)
	mov	edi,	pdt		;   Destination pointer (start of PDTs)
    @@:	stosd				;   Low dword of page dir entry
	add	eax,	0x200000	;   Next 2 meg page
	mov	[edi],	edx		;   Zero high dword (edx is still 0)
	add	edi,	4		;   Next page dir entry
	loop	@r			;   Loop

longmode:				; Now we actually enter long mode
	mov	eax,	0x20		;   Enable PAE. Disable global pages
	mov	cr4,	eax		;     (until CR3 reloaded in long mode)
	mov	ecx,	0xc0000080	;   EFER MSR number
	mov	eax,	0x900		;   Long mode and no-execute
	xor	edx,	edx		;   Clear edx to not set reserved bits
	wrmsr				;   Write EFER
	mov	eax,	0x80000001	;   Paging and protected mode
	mov	cr0,	eax		;   Write CR0
					; **WE ARE NOW IN COMPATIBILITY MODE

	mov	ebx,	0xB8000		; For debugging, we put a 2 in the top-
	mov	[ebx],	byte '2'	;   left corner of the screen--success!

	lgdt	[gdt_ptr]		;   Load the GDT pointer
	mov	ax,	gdt.kd		;   Load GDT kernel data seg descriptor
	mov	ds,	ax		;   Load all data segment selectors
	mov	es,	ax		;   fs/gs/ss don't matter in 64bit mode
	jmp	gdt.kc:.final		;   Far jump to 64-bit kcode segment

use64					; Now instructions are 64-bit
 .final:				; Do any final native/multiboot setup

	mov	ebx,	0xB8000		; For debugging, we put a 3 in the
	mov	[rbx],	byte '3'	;   top-left corner of the screen

	mov	rax,	trampoline	; Jump to the top PML4T entry
	jmp	rax


section '.text'

use64
trampoline:
	mov	edx,	HMD		; Save kernel base in gs/KernelGSBase
	xor	eax,	eax		; High dword is HMD; low dword is 0
	mov	ecx,	0xC0000101	; GS.Base MSR
	wrmsr				; Save it from edx:eax
	mov	ecx,	0xC0000102	; KernelGSBase
	wrmsr				; Save it

	shl	rdx,	32		; Move HMD to high dword of rdx
	lgdt	[rdx+gdt_ptr]		; Reload GDT (with 64-bit vaddr)

	mov	[rdx+pml4t], rax	; Zero the "identity" low PML4T entry

	mov	eax,	pml4t		; Reload CR3 to flush TLB
	mov	cr3,	rax		;   This prevents stale identity access
	mov	eax,	0xA0		; Enable Global Pages (so kernel-space
	mov	cr4,	rax		;   mappings aren't flushed every time
					;   CR3 is reloaded)

	mov	ebx,	0xB8000		; For debugging, we put a 4 in the
	mov	[gs:ebx], byte '4'	;   top-left corner of the screen

	lea	rsp, [rdx+init_stack]	; Initialize stack pointer before
					;   calling anything

	call	common			; Common initialization routine

idle:
	hlt
	jmp	idle
