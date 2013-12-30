;
; arch/amd64/boot/multiboot.s - multiboot bootstrap code and long mode initialization
;
; Copyright 2012-2013 Samuel Holland <samuel@sholland.net>
;

format elf64

include "asm/constants.inc"
include "asm/linker.inc"
include "asm/macros.inc"
include "asm/memmap.inc"

extrn	setup_longmode			; Defined in longmode.s

section '.loader'
use32

align 4					; Must be dword-aligned
mbheader:dd	MBOOT_MAGIC		; Beginning of multiboot header
	 dd	MBOOT_FLAGS		;   Flags
	 dd	MBOOT_CHECKSUM		;   Checksum
	 dd	mbheader		;   Physical address of header
	 dd	__start			;   Beginning of the kernel
	 dd	__multiboot_data_end	;   .text/.data fill the whole file
	 dd	__multiboot_bss_end	;   Reserve 512 KiB of high memory
	 dd	multiboot		;   Multiboot entry point

panic32:				; Routine to print a message and quit
	mov	edi,	0xB8520		;   Dest is middle of video memory
	mov	esi,	.msg		;   Source is address of string above
	mov	ecx,	48		;   Number of characters
	mov	ah,	0x40		;   Black on red color
	cld				;   Going up
    @@:	lodsb				;   Load character
	stosw				;   Store character and its color
	loop	@r			;   Loop
	hlt				;   Halt
 .msg	db	" PANIC: Unsupported bootloader or no long mode! "

multiboot:				; Multiboot entry point
	cmp	eax,	0x2BADB002	;   Check required multiboot magic
	jne	panic32			;   Panic if it's not there
	mov	ebp,	ebx		;   Save mbinfo ptr (cpuid clobbers ebx)

					; Test for long mode
	mov	eax,	0x80000000	;   Extended-function 0x8000000.
	mov	esi,	eax		;   Save it in esi
	cpuid				;   Get largest extended function
	cmp	eax,	esi		;   Is there any function > 0x80000000?
	jbe	panic32			;   If not, no long mode, so panic
	mov	eax,	esi		;   Put 0x80000000 back in eax
	inc	eax			;   Now we need function 0x8000001
	cpuid				;   EDX = extended-features flags.
	bt	edx,	29		;   Test if long mode is supported.
	jnc	panic32			;   Panic if it is not supported.

					; Move mbinfo to a safe location in bss
	mov	esi,	ebp		;   Source is mbinfo ptr
	mov	edi,	mbinfo		;   Dest is 'virtual' mbinfo struct
	mov	ecx,	22		;   Length is 88 bytes, or 22 dwords
	cld				;   Make sure we go the right direction
	rep	movsd			;   Move 4 bytes at a time

					; Also save some pointed-to values
	mov	edx,	[mbinfo]	;   Put mbinfo flags in edx

					; Save the command line
	bt	edx,	2		;   Is the command line present?
	jnc	.mods			;   If not, go to the next section
	mov	esi,	[mbinfo.cmdline];   Source is string pointed to
	dalign	edi,	4		;   Align destination to dword
	mov	[mbinfo.cmdline], edi	;   Set pointer to new location
	mov	ebx,	edi		;   Save it for later
	add	edi,	4		;   Reserve space for length dword
					;   Direction flag is already clear
	xor	ecx,	ecx		;   Clear count register
    @@:	lodsb				;   Load byte into al
	and	al,	al		;   Set flags
	jz	@f			;   If it is NUL, break from the loop
	stosb				;   Else, save it to the new location
	inc	ecx			;   And increment the count
	jmp	@r			;   And jump back to loop again
    @@:	mov	[ebx],	ecx		;   Save count in reserved space

 .mods:					; Save the module list
	bt	edx,	3		;   Are the module info fields valid?
	jnc	.mmap			;   If not, go to the next section
	mov	ecx, [mbinfo.mods_count];   Get number of module info structs
	and	ecx,	ecx		;   Set flags
	jz	.mmap			;   If there are 0, don't copy anything
	shl	ecx,	2		;   4 dwords (16 bytes) per struct
	mov	esi, [mbinfo.mods_addr]	;   Source is pointed to in mbinfo
	dalign	edi,	4		;   Align destination to dword
	mov	[mbinfo.mods_addr], edi	;   Set pointer to new location
	rep	movsd			;   Copy $ecx dwords

 .mmap:					; Save the memory map
	bt	edx,	6		;   Are the mmap fields valid?
	jnc	.cfgtbl			;   If not, go to the next one
	mov	ecx, [mbinfo.mmap_len]	;   Get size of mmap info
	and	ecx,	ecx		;   Set flags
	jz	.cfgtbl			;   If length is 0, don't copy anything
	shr	ecx,	2		;   Copy 4 bytes at a time
	mov	esi, [mbinfo.mmap_addr]	;   Source is value of pointer
	dalign	edi,	4		;   Align destination to dword
	mov	[mbinfo.mmap_addr], edi	;   Set pointer to new location
	rep	movsd			;   Copy $ecx dwords

 .cfgtbl:				; Save the BIOS config.
	bt	edx,	8		;   Is the BIOS configuration present?
	jnc	.loadername		;   If not, go to the next section
	mov	esi, [mbinfo.bios_cfg]	;   Source is the pointer value
	movzx	ecx,	word [esi]	;   Count is the first word at the ptr
	add	ecx,	2		;   Add because we copy the count too
	dalign	edi,	4		;   Align destination to dword
	mov	[mbinfo.bios_cfg], edi	;   Set pointer to new location
	rep	movsb			;   Copy $ecx bytes (not always mod 4)

 .loadername:				; Save the bootloader name
	bt	edx,	9		;   Is the bootloader name present?
	jnc	.apmtbl			;   If not, go to the next section
	mov	esi,[mbinfo.boot_loader];   Source is string pointed to
	dalign	edi,	4		;   Align destination to dword
	mov	[mbinfo.boot_loader],edi;   Set pointer to new location
	mov	ebx,	edi		;   Save it for later
	add	edi,	4		;   Reserve space for length dword
					;   Direction flag is already clear
	xor	ecx,	ecx		;   Clear count register
    @@:	lodsb				;   Load byte into al
	and	al,	al		;   Set flags
	jz	@f			;   If it is NUL, break from the loop
	stosb				;   Else, save it to the new location
	inc	ecx			;   And increment the count
	jmp	@r			;   And jump back to loop again
    @@:	mov	[ebx],	ecx		;   Save count in reserved space

 .apmtbl:				; Save the APM table
	bt	edx,	10		;   Is the APM table present?
	jnc	.saved			;   If not, go to the next step
	mov	ecx,	5		;   20 bytes, or 5 dwords
	mov	esi, [mbinfo.apm_table]	;   Source is value of pointer
	dalign	edi,	4		;   Align destination to dword
	mov	[mbinfo.apm_table], edi	;   Set pointer to new location
	rep	movsd			;   Copy a dword at a time

 .saved:				; Now we have saved all multiboot data,
	mov	ebx,	0xB8000		;   so all low memory is available. We
	mov	[ebx],	byte '1'	;   use it to set up page tables and an
					;   information table like pure64 does.
					;   Also, all registers are free to use

 .infotable:				; Fill out boot info table

; DO IT

next:
	jmp	setup_longmode		; Set up & enter long mode (longmode.s)


section '.loaderbss'
	rb	(mbextra.end-mbinfo)	; This is the actual reservation; the
					;   virtual block is needed so we only
					;   ask the linker for low addresses.
					;   The memory actually ends up at 1+
					;   MiB, but the linker doesn't know
					;   that. We have to use a separate
					;   variable here (not __bss_start)
					;   so that the linker does the math
					;   and can guarantee the address fits.

virtual at __multiboot_bss_start
mbinfo:					; Reserve space for a guaranteed safe
					;   place to put multiboot info
 .flags		dd ?			; 0x00
 .mem_lower	dd ?			; 0x04 (In KiB)
 .mem_upper	dd ?			; 0x08 (In KiB)
 .boot_device	db ?			; 0x0C (Disk)
 .boot_device_1	db ?			; 0x0D (Partition)
 .boot_device_2	db ?			; 0x0E (Sub-partition)
 .boot_device_3	db ?			; 0x0F (Sub-sub-partition)
 .cmdline	dd ?			; 0x10 (Pointer to C-style string)
 .mods_count	dd ?			; 0x14 (Number of 16-byte entries)
 .mods_addr	dd ?			; 0x18
 .syms		rd 4			; 0x1C-0x28
 .mmap_len	dd ?			; 0x2C (Total size of memory map)
 .mmap_addr	dd ?			; 0x30
 .drives_len	dd ?			; 0x34 (Total size of drive structs)
 .drives_addr	dd ?			; 0x38
 .bios_cfg	dd ?			; 0x3C
 .boot_loader	dd ?			; 0x40 (Pointer to C-style string)
 .apm_table	dd ?			; 0x44
 .vbe_ctl_info	dd ?			; 0x48
 .vbe_mode_info	dd ?			; 0x4C
 .vbe_mode	dw ?			; 0x50
 .vbe_iface_seg	dw ?			; 0x52
 .vbe_iface_off	dw ?			; 0x54
 .vbe_iface_len	dw ?			; 0x56
 .end:					; 0x58
mbextra:
		rb 0x100		; Variable length structures are put
 .end:					;   after the fixed mbinfo; for now,
					;   just reserve 256 bytes. FIXME
end virtual
