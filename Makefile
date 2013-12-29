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
CC		 = $(CROSS_COMPILE)clang
CCOPTS		 = 
LD		 = $(CROSS_COMPILE)ld
LDBINOPTS	 = -T $(linker_script)
LDLIBOPTS	 =
RUSTC		 = $(CROSS_COMPILE)rustc
RUSTCOPTS	 = --emit-llvm

# Parameters
version		:= 0

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
quarto : $(final_bin)

# Should add gzipping at some point...
$(final_bin) : $(linked_bin)
	cp $< $@

$(linked_bin) : $(objects)
	$(LD) $(LDBINOPTS) $(LDFLAGS) -o $@ $^

%.o : %.bc
	$(CC) -c $(CCOPTS) $(CFLAGS) -o $@ $<

%.o : %.c
	$(CC) -c $(CCOPTS) $(CFLAGS) -o $@ $<

%.o : %.s
	$(AS) $< $@

%.bc : %.rs
	$(RUSTC) -c $(RUSTCOPTS) $(RUSTCFLAGS) -o $@ $<

clean : 
	rm -f *.elf $(addsuffix /*.o,$(subdirs)) $(addsuffix /*.bc,$(subdirs))
