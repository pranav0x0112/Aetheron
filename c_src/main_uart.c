#define UART_ADDR 0x40000000

void _start() {
    *(volatile unsigned int*)UART_ADDR = 'H';
    *(volatile unsigned int*)UART_ADDR = 'I';
    while(1);
}