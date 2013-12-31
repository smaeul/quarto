;
; include/asm/linker.inc - Variables defined by the linker
;
; Copyright 2013 Samuel Holland <samuel@sholland.net>
;

; TODO: Generate these from scripts/kernel.ld

extrn __start
extrn __loader_start
extrn __loader_end
extrn __text_start
extrn __text_end
extrn __data_start
extrn __data_end
extrn __bss_start
extrn __bss_end
extrn __end

extrn __multiboot_text_end
extrn __multiboot_data_end
extrn __multiboot_bss_start
extrn __multiboot_bss_end
