ENTRY(payload_start)
PROVIDE(__global_pointer$ = 0x80000800);

SECTIONS
{
  . = 0x80000000;

  .text : { *(.text*) }
  .rodata : { *(.rodata*) *(.srodata*) }
  .data : { *(.data*) }
  .sdata : { *(.sdata*) }
  .sbss : { *(.sbss*) }
  .bss : { *(.bss*) }

  . = ALIGN(4);
  _bss_end = .;

  . += 0x1000;     /* 4 KiB stack */
  __stack_top = .;
}