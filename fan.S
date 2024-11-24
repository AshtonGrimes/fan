.include "m328Pdef.inc"

; Memory addresses for global variables
.equ DEBOUNCE_COUNT = 0x0100
.equ POWER_STATE = 0x0102
.equ TOGGLE_COUNT = 0x0104

; Constants
.equ DEBOUNCE_MAX = 255 ; Use 255 for 16 MHz
.equ RELAY_DELAY_MAX = 4 ; Use 4 for 16 MHz
.equ RELAY_LOW = 35
.equ RELAY_HIGH = 150

.org 0x0000
    rjmp main

.org 0x0002 
    rjmp int0_isr

.org 0x0012 
    rjmp timer2_ovf_isr

.org 0x0020 
    rjmp timer0_ovf_isr

int0_isr: ; Handles button press (except during debounce delay)
    lds r16, POWER_STATE ; 0xFF if 100% duty cycle
    cpi r16, 0
    breq power_on

    lds r16, TIMSK0 ; TOIE0 set if 50% duty cycle
    cpi r16, 0
    brne power_off

    ldi r16, RELAY_LOW
    sts OCR1AL, r16
    ldi r16, 1 << TOIE0 
    sts TIMSK0, r16
    rjmp exit_int0_isr

power_off:
    ldi r16, 0
    sts TIMSK0, r16
    sts POWER_STATE, r16
    sts OCR1AL, r16
    rjmp exit_int0_isr

power_on:
    ldi r16, 0xFF
    sts POWER_STATE, r16
    sts OCR1AL, r16

exit_int0_isr: ; Begins debounce timer 
    ldi r16, 0
    sts DEBOUNCE_COUNT, r16
    ldi r16, 1 << TOIE2
    sts TIMSK2, r16
    rjmp timer2_ovf_isr

timer0_ovf_isr: ; 50% duty cycle; frequency / delay max
    lds r16, TOGGLE_COUNT
    cpi r16, RELAY_DELAY_MAX
    brsh toggle

    inc r16
    sts TOGGLE_COUNT, r16
    reti

toggle: ; Uses specific PWM levels to reduce contact noise
    ldi r16, 0
    sts TOGGLE_COUNT, r16
    lds r16, OCR1AL
    ldi r17, RELAY_LOW ^ RELAY_HIGH
    eor r16, r17
    sts OCR1AL, r16    
    reti

timer2_ovf_isr: ; Prevents button interrupt until count >= max
    lds r16, DEBOUNCE_COUNT
    cpi r16, DEBOUNCE_MAX
    brsh unblock_button 
    
    inc r16
    sts DEBOUNCE_COUNT, r16
    cbi PORTB, 5
    cbi EIMSK, INT0 
    reti

unblock_button: ; Enables button interrupt and disable debounce timer interrupt
    sbi EIMSK, INT0 
    sbi PORTB, 5
    ldi r16, 0
    sts TIMSK2, r16
    reti

main:
    ldi r16, LOW(RAMEND)
    out SPL, r16
    ldi r16, HIGH(RAMEND)
    out SPH, r16

    ldi r16, 1 << SE ; Sleep enable
    out SMCR, r16

    ldi r16, 0xFF
    sts DEBOUNCE_COUNT, r16

    ldi r16, 0 ; Initializing variables and configuring timer 0
    sts POWER_STATE, r16
    sts TOGGLE_COUNT, r16
    out TCNT0, r16
    out TCCR0A, r16 ; Normal mode (page 84)    
    sts TIMSK0, r16 
    ldi r16, (1 << CS02) | (1 << CS00) 
    out TCCR0B, r16 ; 1024 prescaler (page 87)

    sbi DDRB, 1 ; Initializing timer 1
    cbi PORTB, 1
    ldi r16, (1 << COM1A1) | (1 << WGM10) ; 8 bit pwm (pages 108-109)    
    sts TCCR1A, r16
    ldi r16, 1 << CS10 ; No prescaler (page 110)
    sts TCCR1B, r16
    ldi r16, 0
    sts OCR1AL, r16
    sts OCR1AH, r16
    
    sts TCNT2, r16 ; Initializing timer 2
    sts TIMSK2, r16
    sts TCCR2A, r16 ; Normal mode (page 128)
    ldi r16, 1 << CS22
    sts TCCR2B, r16 ; 64 prescaler (page 131)
    
    cbi DDRD, 2
    sbi PORTD, 2 
    sbi DDRB, 5
    sbi PORTB, 5

    sbi EIMSK, INT0 ; INT0 interrupt (page 55)
    ldi r16, 0
    sts EICRA, r16 ; Interrupt on low logic level (using internal pullup resistor)
    sei

loop:
    sleep
    rjmp loop
