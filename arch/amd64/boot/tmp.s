format elf64

section '.loader'

public common

use64
common:
	mov	rax,	common
	jmp	rax
