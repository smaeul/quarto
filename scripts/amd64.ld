/*
 * scripts/kernel.ld - Main quarto linker script
 *
 * Copyright 2012-2013 Samuel Holland <samuel@sholland.net>
 */

OUTPUT_FORMAT(elf32-x86-64)
OUTPUT_ARCH(i386:x86-64)

ENTRY (__entry)

HM_OFFSET = 0xFFFFFF8000000000;

SECTIONS
{
    . = 0x00000000001000A0;	/* Reserve enough space for ELF header */

    __multiboot_file_start = .;

    .loader : ALIGN(0x10)
    {
	*(.loader)		/* BIOS and multiboot loader code */
	*(.loaderdata)		/* GDT, its pointer struct, and friends */
    }

    . += HM_OFFSET;		/* Move to the top of virtual memory */

    .text : AT(ADDR(.text) - HM_OFFSET)
    {
	*(.text*)		/* Normal 64-Bit Code */
	__multiboot_text_end = . - HM_OFFSET;
    }

    .data : AT(ADDR(.data) - HM_OFFSET)
    {
	*(.data*)		/* Global Variables */
	*(.rodata*)		/* String Constants */
	__multiboot_data_end = . - HM_OFFSET;
    }

    .bss : AT(ADDR(.bss) - HM_OFFSET)
    {
	__multiboot_bss_start = . - HM_OFFSET; /* For 32-bit relocations */
	*(.loaderbss)		/* Temporary init data (multiboot struct) */
	*(.bss*)		/* Normal Reserved Memory */
	*(COMMON)		/* Other Uninitialized Data */
	__multiboot_bss_end = . - HM_OFFSET;
    }

    /DISCARD/ :
    {
	*(.comment)
	*(.eh_frame)
	*(.note*)
    }
}
