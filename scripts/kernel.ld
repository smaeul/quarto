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

    __start = .;

    .loader : ALIGN(0x10)
    {
	__loader_start = .;
	*(.loader)		/* BIOS and multiboot loader code */
	*(.loaderdata)		/* GDT, its pointer struct, and friends */
	__loader_end = .;
    }

    . += HM_OFFSET;		/* Move to the top of virtual memory */

    .text : AT(ADDR(.text) - HM_OFFSET)
    {
	__text_start = .;
	*(.init)		/* The springboard we jump to in high RAM */
	*(.text*)		/* Normal 64-Bit Code */
	__text_end = .;
	__multiboot_text_end = . - HM_OFFSET;
    }

    .data : AT(ADDR(.data) - HM_OFFSET)
    {
	__data_start = .;
	*(.data*)		/* Global Variables */
	*(.rodata*)		/* String Constants */
	__data_end = .;
	__multiboot_data_end = . - HM_OFFSET;
    }

    .bss : AT(ADDR(.bss) - HM_OFFSET)
    {
	__bss_start = .;
	__multiboot_bss_start = . - HM_OFFSET; /* For 32-bit relocations */
	*(.loaderbss)		/* Temporary init data (multiboot struct) */
	*(.bss*)		/* Normal Reserved Memory */
	*(COMMON)		/* Other Uninitialized Data */
	__bss_end = .;
	__multiboot_bss_end = . - HM_OFFSET;
    }

    __end = .;

    /DISCARD/ :
    {
	*(.comment)
	*(.eh_frame)
	*(.note*)
    }
}
