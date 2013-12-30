;
; arch/amd64/boot/native.s - Native BIOS boot code
;
; Copyright 2013 Samuel Holland <samuel@sholland.net>
;

format elf64

public __entry

section '.loader'

use16

__entry:
