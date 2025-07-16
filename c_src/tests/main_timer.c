#include "aetheron.h"

static void putc(char c) { UART_TX = (uint32_t)c; }

int main(void)
{
    uint32_t last = TIMER_CNT;         

    for (;;)
    {
        uint32_t now = TIMER_CNT;
        if (now - last >= 100000u)     // 100 ms @ 1 MHz
        {
            putc('.');
            last = now;
        }
    }
}