#include "aetheron.h"

static void delay(void)
{
    for (volatile int i = 0; i < 50000; ++i)
        ;
}

int main(void)
{
    uint32_t pat = 1u;

    for (;;)
    {
        GPIO_OUT = pat;           // write pattern
        pat = (pat << 1) ? pat << 1 : 1u;
        delay();

        (void)GPIO_IN;            // exercise read logic
    }
}