ENTRY(_start)

SECTIONS
{
  . = 0x00000000;
  .text : { *(.text*) }

  /* The payload from main.bin will be put in .payload later */
  _payload_src = .;
  .payload : { *(.payload*) }
  _payload_end = .;
}