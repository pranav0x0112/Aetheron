#include "aetheron.h"

int main(void) {
    UART_TX = 0xCAFEBABE;
    delay_cycles(1000000); 
    while (1);
}