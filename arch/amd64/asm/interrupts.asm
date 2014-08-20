format elf64
use64

public isr.null

; This must be relocatable by 32-bit code
section '.loader'
isr:	jmp	$
 .null:	jmp	isr
