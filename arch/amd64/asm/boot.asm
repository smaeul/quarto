;
; bootshim.asm - Tripath Environment Initialization; 16>32>64-bit Jump
;
; Copyright © 2012-2014 Samuel Holland <samuel@sholland.net>
;

; Start off the file by specifying the type.
format elf64

; These symbols, defined by ld while linking, tell us where the code and data
; will end up in RAM, and how big they are. We need this information to con-
; struct a multiboot header.
extrn __multiboot_file_start
extrn __multiboot_text_end
extrn __multiboot_data_end
extrn __multiboot_bss_start
extrn __multiboot_bss_end

; The next step on our architecture-independent initialization journey.
extrn common

; The default handler for interrupts and exceptions
extrn isr.null

; This symbol tells the linker where to find the "entry point" into our code,
; or the first instruction to run.
public __entry

; This helpful macro aligns the value in a register to the specified number
; of bytes.
macro dalign reg*, num* {
	add	reg,	num-1
	and	reg,	-num
}

; These constants represent the offset between physical and virtual addresses
; mentioned above that goes into effect once we enable paging and long mode.
HMD		equ 0xFFFFFF80
HM		equ 0xFFFFFF8000000000

; Some of the fields in the multiboot header are predefined, either by the
; standard, or by how quarto works.
MBOOT_MAGIC	equ 0x1BADB002
MBOOT_FLAGS	equ 0x00010003
MBOOT_CHECKSUM	equ -(MBOOT_MAGIC + MBOOT_FLAGS)

; Here is the big memory map. It places variables at known locations in RAM.
; Note that we generally have to initialize this memory ourselves. By using
; a "virtual" directive, we can create names for these locations without
; adding any size to the kernel binary. Also, they allow FASM to perform all
; of the relocations before sending the code to ld, since ld cannot handle
; mixed 32- and 64-bit code very well.
virtual at 0				; Page tables
idt:		rq 512			;   4KiB in 256 16-byte descriptors
gdt:		rq 512			;   4KiB in 512 8-byte descriptors
pml4t:		rq 512			;   4KiB in 512 8-byte entries
pdpt:		rq 512			;   4KiB in 512 8-byte entries

org 0x4000
meminfo:				; E820 Memory Map
 ; http://www.returninfinity.com/pure64-manual.html
 .addr		dq ?			;   Arbitrary number of these structs
 .len		dq ?
 .typd		dw ?
 .null		dq 0,0			;   Null terminating struct
		db 0

org 0x5000
bootinfo:				; Boot information table from pure64
 ; http://www.returninfinity.com/pure64-manual.html
 .acpi_tbls	dq ?			;   0x5000
 .bspid		dd ?			;   0x5008
		dd 0			;   0x500C (Reserved - padding)
 .cpu_mhz	dw ?			;   0x5010
 .cores_active	dw ?			;   0x5012
 .cores_detect	dw ?			;   0x5014
		dw 0			;   0x5016
		dq 0			;   0x5018
 .ram_mib	dw ?			;   0x5020
		dp 0			;   0x5022
		dq 0			;   0x5028
 .mbr		db ?			;   0x5030
 .ioapic_count	db ?			;   0x5031
		dp 0			;   0x5032
		dq 0			;   0x5038
 .video_base	dd ?			;   0x5040
 .video_width	dw ?			;   0x5044
 .video_height	dw ?			;   0x5046
		dq 0			;   0x5048
		dq 0			;   0x5050
		dq 0			;   0x5050
 .lapic		dq ?			;   0x5060
 .ioapics	dq ?			;   0x5068 (Start of a list)
org 0x5100
 .apic_ids	db ?			;   0x5100 (Start of a list)

org 0x5C00
vesainfo:
 ; http://www.ctyme.com/intr/rb-0274.htm
		rb 256			; FIXME: Define

org 0x10000
init_stack:				; Grows down from here; 32KiB is safe
pdt:		rq 32768		; 256KiB in 64 PDTs (512 entries each)
kmsgbuf:	rq 16384		; 128KiB ring buffer for debug messages
end virtual

; Okay, now we begin actual code. The boot shim goes in a special ".loader"
; section to make sure it shows up at the beginning of the file. Otherwise, the
; bootloader may not be able to find it.
section '.loader'

; If we come straight from a Master Boot Record (or Partition Boot Record), the
; CPU will be in real mode, so we have to start off with 16-bit code.
use16

; Here's that entry point again. For now, it doesn't do anything. Real mode
; booting is not necessary at this point, since QEMU and GRUB can get into
; protected mode for us.
__entry:

; Now we are at the protected mode section.
use32

align 4					; Must be dword-aligned
mbheader:dd	MBOOT_MAGIC		; Beginning of multiboot header
	 dd	MBOOT_FLAGS		;   Flags
	 dd	MBOOT_CHECKSUM		;   Checksum
	 dd	mbheader		;   Physical address of header
	 dd	__multiboot_file_start	;   Beginning of the kernel
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

lowmem:					; Fill out structures in low memory
 .idt:					; First is the IDT at 0x0
	mov	edi,	idt		;   Clear the destination index
	mov	ecx,	1024		;   256 entries * 4 dwords (16 bytes)
	mov	ax,	gdt.kc		;   ISR code segment
	shl	eax,	16		;   Stick in high word
	mov	ebx,	isr.null	;   Load address of default "null" ISR
	mov	ax,	bx		;   Split off low word
	mov	bx,	0x8E00		;   Flags: intr., present, CPL 0
	mov	edx,	HMD		;   Top DWORD of ISR address
	xor	esi,	esi		;   Final four zero bytes
    @@: mov	[edi],	eax		;   Store Data
	mov	[edi+4], ebx
	mov	[edi+8], edx
	mov	[edi+12], esi
	add	edi,	16		;   Next Entry
	loop	@r			;   Loop through the table

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
	mov	edx,	HMD		; Save kernel base in fs/gs/KernelGSBase
	xor	eax,	eax		; High dword is HMD; low dword is 0
	mov	ecx,	0xC0000100	; FS.Base MSR
	wrmsr				; Save it from edx:eax
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

; These descriptors are offsets into the gdt_data table.
gdt.null	= 0x00
gdt.kc32	= 0x08
gdt.kd32	= 0x10
gdt.kc		= 0x18
gdt.kd		= 0x20
gdt.uc		= 0x28
gdt.ud		= 0x30
gdt.tss		= 0x38


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
