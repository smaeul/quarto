#
# /~\ | | /~\ |~) ~T~ /~\   A kernel for the
# \_X \_/ |~| |~\  |  \_/   next  generation
#
# Copyright (C) 2013-2014
# Samuel Holland <samuel@sholland.net>
# MIT Licensed
#

# Build Type
ARCH		?= amd64
CROSS_COMPILE	?=

# Toolchain
AS		 = $(CROSS_COMPILE)fasm
ASENV		 = INCLUDE=include
CC		 = $(CROSS_COMPILE)clang
COPTS		 =
LD		 = $(CROSS_COMPILE)ld
LDOPTS		 = -T $(linker_script) -z max-page-size=0x1000
RUSTC		 = $(CROSS_COMPILE)rustc
RUSTOPTS	 =

# Parameters
version		:= 0.0

# Directories
base_dirs	 = boot exec lib mem udi
arch_dirs	 = $(foreach dir,$(base_dirs),arch/$(ARCH)/$(dir))
subdirs		:= $(base_dirs) $(arch_dirs) $(patsubst %/,%,\
			$(foreach dir,$(base_dirs) $(arch_dirs),\
			$(filter %/, $(wildcard $(dir)/*/))))

# Files
final_bin	:= quartoz.elf
linked_bin	:= quarto.elf
linker_script	:= scripts/kernel.ld
objects		 = $(addsuffix .o,$(basename $(filter %.c %.rs %.s,\
			$(foreach dir,$(subdirs),$(wildcard $(dir)/*)))))

# Goals
quarto: $(final_bin)

# Program depends on arch...
qemu: $(final_bin)
	@qemu-system-x86_64 -kernel $< -monitor stdio

stats: $(final_bin)
	@echo Size:
	@size $<
	@readelf -l $< | grep -B3 '0x0'

# Should add gzipping at some point...
$(final_bin): $(linked_bin)
	cp $< $@
	strip --strip-all $@

$(linked_bin): $(objects) $(linker_script)
	$(LD) $(LDOPTS) $(LDFLAGS) -o $@ $^

%.o: %.bc
	$(CC) -c $(COPTS) $(CFLAGS) -o $@ $<

%.o: %.s
	$(ASENV) $(AS) $< $@

%.bc: %.rs
	$(RUSTC) --emit-llvm $(RUSTOPTS) $(RUSTFLAGS) $<

clean:
	@rm -f *.elf $(addsuffix /*.o,$(subdirs)) $(addsuffix /*.bc,$(subdirs))

.PHONY: quarto qemu stats clean
