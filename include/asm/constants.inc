;
; constants.inc - general definitions and variable declarations
;
; Copyright 2012-2013 Samuel Holland <samuel@sholland.net>
;

; Kernel paging
HMD		equ 0xFFFFFF80		; Upper dword of kernel memory base
HM		equ 0xFFFFFF8000000000	; Base of kernel memory

; Multiboot header
MBOOT_MAGIC	equ 0x1BADB002          ; Multiboot magic value
MBOOT_FLAGS	equ 0x00010003          ; Use kluge, page align modules, and
MBOOT_CHECKSUM	equ -(MBOOT_MAGIC + MBOOT_FLAGS) ; require memory information
