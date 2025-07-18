#pragma once             
#include <stdint.h>

/* ---- Address map ------------------------------------------------ */
#define ROM_BASE   0x00000000u   // 32 KiB
#define RAM_BASE   0x80000000u   // 32 KiB
#define UART_BASE  0x40001000u   // 4 KiB
#define GPIO_BASE  0x40000000u   // 4 KiB
#define TIMER_BASE 0x40002000u   // 4 KiB  

#define UART_TX    (*(volatile uint32_t *)(UART_BASE + 0x0))
#define UART_RX    (*(volatile uint32_t *)(UART_BASE + 0x4))
#define GPIO_OUT   (*(volatile uint32_t *)(GPIO_BASE + 0x0))
#define GPIO_IN    (*(volatile uint32_t *)(GPIO_BASE + 0x4))
#define TIMER_CNT  (*(volatile uint32_t *)(TIMER_BASE + 0x0))

static inline void putc(char c) { UART_TX = (uint32_t)c; }

static inline void delay_cycles(volatile uint32_t n)
{
    while (n--) __asm__ volatile("nop");
}