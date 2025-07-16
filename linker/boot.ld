ENTRY(_start)

PHDRS
{
  rom PT_LOAD FLAGS(5);  
  ram PT_LOAD FLAGS(7);  
}

MEMORY {
  rom (rx) : ORIGIN = 0x00000000, LENGTH = 32K
  ram (rwx) : ORIGIN = 0x80000000, LENGTH = 32K
}

SECTIONS {
  . = 0x00000000;

  .text : {
    *bootloader.o(.text*)
  } :rom :rom

  . = . + SIZEOF(.text);
  . = ALIGN(4);

  _payload_rom_start = .;
  .payload : AT(ADDR(.text) + SIZEOF(.text)) {
    KEEP(*(.payload))
    _payload_rom_end = .;
  } :rom :rom

  . = 0x80000000;
  _payload_ram_start = .;

  .text.ram : {
    *payload.o(.text*)
  } :ram :ram
}