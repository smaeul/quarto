;
; include/memmap.inc - Structures that allow assembly procedures to set up RAM
;
; Copyright 2013 Samuel Holland <samuel@sholland.net>
;

virtual at 0				; Page tables
idt:		rq 512			;   4KiB in 256 16-byte descriptors
gdt:		rq 512			;   4KiB in 512 8-byte descriptors
pml4t:		rq 512			;   4KiB in 512 8-byte entries
pdpt:		rq 512			;   4KiB in 512 8-byte entries
org 0x10000
pdt:		rq 32768		;   256KiB in 64 tables of 512 entries

org 0x5000
bootinfo:				; Boot information table from pure64
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
end virtual
