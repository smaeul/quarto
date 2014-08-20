# ╭─╮╷ ╷╭─╮╭─╮─┬─╭─╮   A legacy-free OS
# │ ││ │├─┤├┬╯ │ │ │   framework for the
# ╰─\╰─╯╵ ╵╵╰╴ ╵ ╰─╯   next generation
#
# © 2013-2014 Samuel Holland <samuel@sholland.net>
# MIT Licensed; I reserve the right to relicense.
#

# Parameters
version		:= 0.0

# Build Type
ARCH		?= amd64
CROSS_COMPILE	?=

# Toolchain
FASM		 = $(CROSS_COMPILE)fasm
LD		 = $(CROSS_COMPILE)ld
LDFLAGS		 =
RUSTC		 = $(CROSS_COMPILE)rustc
RUSTFLAGS	 =

# Files
asm_objects	:= $(addprefix arch/$(ARCH)/asm/, boot.o interrupts.o)
final_bin	:= quartoz.elf
linked_bin	:= quarto.elf
linker_script	:= scripts/$(ARCH).ld
rust_deps	:= rustdeps.mk
rust_objects	:= quarto.o

# Goals
quarto: $(final_bin)

# Program depends on arch...
qemu: $(final_bin)
	@qemu-system-x86_64 -kernel $< -monitor stdio

stats: $(final_bin)
	@echo Size:
	@size -x $<
	@readelf -l $< | grep -B3 '0x0'

# Compilation Rules
# Should add gzipping at some point...
$(final_bin): $(linked_bin)
	cp $< $@
	strip --strip-all $@

$(linked_bin): $(asm_objects) $(rust_objects) $(linker_script)
	$(LD) $(LDFLAGS) -T $(linker_script) -z max-page-size=0x1000 -o $@ $^

$(asm_objects): %.o: %.asm
	$(FASM) $< $@

$(rust_deps): $(rust_objects:.o=.rs)
	$(RUSTC) $(RUSTFLAGS) --dep-info rustdeps.mk --emit=obj -o /dev/null $<

$(rust_objects): %.o: %.rs $(rust_deps)
	$(RUSTC) $(RUSTFLAGS) --dep-info rustdeps.mk --emit=obj -o $@ $<

# Other Rules
clean:
	@rm -f *.elf $(asm_objects) $(rust_deps) $(rust_objects)

.PHONY: quarto qemu stats clean

-include $(rust_deps)
