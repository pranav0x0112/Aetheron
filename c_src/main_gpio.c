#define GPIO_BASE 0x40000000u
volatile unsigned int * const GPIO_OUT = (unsigned int *)(GPIO_BASE + 0x0);
volatile unsigned int * const GPIO_IN  = (unsigned int *)(GPIO_BASE + 0x4);

static void delay(void)
{
    for (volatile int i = 0; i < 50000; ++i)
        ;
}

void main(void)
{
    unsigned pat = 0x1;

    for (;;)
    {
        *GPIO_OUT = pat;          
        pat <<= 1;
        if (!pat) pat = 1;
        delay();

        volatile unsigned int val = *GPIO_IN;
        (void)val;
    }
}