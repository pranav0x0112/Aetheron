void main() {
    volatile int *gpio = (int*)0x10012000;
    *gpio = 0xF00D1234;  
    while (1);
}