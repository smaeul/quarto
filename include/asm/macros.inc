;
; include/asm/macros.inc - macroinstruction definitions for use in assembly
;
; Copyright 2013 Samuel Holland <samuel@sholland.net>
;

macro dalign reg*, num* {		; Align data reg to num bytes
	add	reg,	num-1
	and	reg,	-num
}
