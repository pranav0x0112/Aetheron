#define TIMER_BASE 0x10018000u
#define UART_BASE  0x10000000u

volatile unsigned int * const TIMER = (unsigned int *)(TIMER_BASE + 0x0);
volatile unsigned int * const UART  = (unsigned int *)(UART_BASE  + 0x0);

static void putc(char c) { *UART = (unsigned)c; }

void main(void)
{
    unsigned last = *TIMER;

    for (;;)
    {
        unsigned now = *TIMER;
        if (now - last >= 100000u)       
        {
            putc('.');
            last = now;
        }
    }
}