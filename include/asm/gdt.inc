;
;
;
;
;

; Defined in arch/$ARCH/boot/gdt.s
extrn gdt_data
extrn gdt_ptr

; Also defined there; should be generated automatically
; or guaranteed to be constant
gdt.null	= 0x00
gdt.kc32	= 0x08
gdt.kd32	= 0x10
gdt.kc		= 0x18
gdt.kd		= 0x20
gdt.uc		= 0x28
gdt.ud		= 0x30
gdt.tss		= 0x38
