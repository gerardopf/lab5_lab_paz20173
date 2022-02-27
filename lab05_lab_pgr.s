/*	
    Archivo:		lab04_pre_pgr.s
    Dispositivo:	PIC16F887
    Autor:		Gerardo Paz 20173
    Compilador:		pic-as (v2.30), MPLABX V6.00

    Programa:		Displays simultáneos 
    Hardware:		Botones en puerto B
			Leds en puerto A
			7 segmentos en puerto C
			Pines selectores en puerto E

    Creado:			14/02/22 
    Última modificación:	15/02/22	
*/
    
PROCESSOR 16F887
#include <xc.inc>

; CONFIG1
CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
CONFIG  LVP = OFF              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)
    
 /*---------------- Macros ---------------*/
 reset_timer0 macro		    //siempre hay que volver a asignarle el valor al TMR0
    BANKSEL TMR0
    MOVLW   251		    //Cargamos N en W
    MOVWF   TMR0	    //Cargamos N en el TMR0, listo el retardo de 100ms
    
    BCF	T0IF		    //Limpiar bandera de interrupción

    ENDM
    
 /*---------------- RESET ----------------*/
 PSECT resVect, class=CODE, abs, delta=2	
 ORG 00h					
 resVect:
       PAGESEL main
       GOTO    main
       
 /*--------------- Variables --------------*/  
 UP	EQU 0
 DOWN	EQU 1
	
 PSECT udata_bank0
 VALOR:	    DS	1
 SELECTOR:  DS	1	
 NIBBLE:    DS	2
 DISPLAY:   DS	2
	
 PSECT udata_shr		    //Memoria compartida
 W_TEMP:	    DS  1	    
 STATUS_TEMP:	    DS  1	
 CONT:		    DS	1
    
 
 /*-------------- Interrupciones ---------------*/   
 PSECT intVect, class=CODE, abs, delta=2    
 ORG 04h
 
 push:
    MOVWF   W_TEMP	    //Movemos W en la temporal
    SWAPF   STATUS, W	    //Pasar el SWAP de STATUS a W
    MOVWF   STATUS_TEMP	    //Guardar STATUS SWAP en W	
    
 isr:        
    BTFSC   RBIF	    //Revisar la interrupción de puerto B
    CALL    int_iocb 
    
    BTFSC   T0IF	    //Revisar bandera Timer0
    CALL    int_timer0
    
 pop:
    SWAPF   STATUS_TEMP, W  //Regresamos STATUS a su orden original y lo guaramos en W
    MOVWF   STATUS	    //Mover W a STATUS
    SWAPF   W_TEMP, F	    //Invertimos W_TEMP y se guarda en F
    SWAPF   W_TEMP, W	    //Volvemos a invertir W_TEMP para llevarlo a W
    RETFIE
    
    
 /*------------ Subrutinas de interrupción ------------*/
 int_iocb:	
    BANKSEL PORTB
    BTFSS   PORTB, UP
    INCF    CONT	//Incremento
    MOVF    CONT, W
    MOVWF   PORTA
    
    BTFSS   PORTB, DOWN
    DECF    CONT	//Decremento
    MOVF    CONT, W
    MOVWF   PORTA
    
    BCF	    RBIF	//Limpiar bandera
    RETURN
    
 int_timer0:
    reset_timer0    
    CLRF    PORTE		    //Para que no exista contención    
    BTFSC   SELECTOR, 0
    GOTO    display1
  
 display0:
    MOVF    DISPLAY+1, W
    MOVWF   PORTC
    BSF	    PORTE, 1	    //Mostrar decenas
    GOTO    cambio_display
    
 display1:  
    MOVF    DISPLAY, W
    MOVWF   PORTC
    BSF	    PORTE, 0	    //Mostrar unidades
    GOTO    cambio_display   
    
 cambio_display:
    MOVLW   1
    XORWF   SELECTOR, F	    // 
    RETURN
    
 /*----------------- COONFIGURACIÓN uC --------------------*/
 PSECT code, delta=2, abs	
 ORG 100h			//Dirección 100% seguro de que ya pasó el reseteo
 
 main:
    CALL    setup_io
    CALL    setup_io_ocB
    CALL    reloj
    CALL    timer0
    CALL    setup_int
    BANKSEL PORTC
    
 loop:
    MOVF    CONT, W
    MOVWF   VALOR
    CALL    separar_nibbles
    CALL    preparar_7seg
    GOTO    loop   
    
 /*------------ Subrutinas -----------------*/
 separar_nibbles:
    MOVF   VALOR, W
    ANDLW   0x0F	//Solo agarra primeros 4 bits
    MOVWF   NIBBLE	//Nibble bajo
    
    SWAPF   VALOR, W
    ANDLW   0x0F
    MOVWF   NIBBLE+1	//Nibble alto   
    RETURN
    
 preparar_7seg:
    MOVF    NIBBLE, W
    CALL    tabla	    //Codificación
    MOVWF   DISPLAY	    //Preparar Display con nibble ajo
    
    MOVF    NIBBLE+1, W
    CALL    tabla
    MOVWF   DISPLAY+1	    //Display preparado con nibble alto y bajo
    RETURN

setup_io_ocB:
    BANKSEL IOCB
    BSF	    IOCB, UP
    BSF	    IOCB, DOWN
    
    BANKSEL PORTA
    MOVF    PORTB, W	//Se termina la condición de mismatch
    BCF	    RBIF	//Limpiar bandera
    
    RETURN  
 
 setup_io:
    
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH	//Digital in/out on A and B
    
    BANKSEL TRISB
    BSF	    TRISB, UP	//RB0 in
    BSF	    TRISB, DOWN	//RB1 in
    
    BANKSEL TRISA
    CLRF    TRISC	//Port C out
    CLRF    TRISA	//Port A out
    
    BCF	    TRISE, 0
    BCF	    TRISE, 1	//E out, selectores
    
    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7   //Pul up Port B enabled
    
    BANKSEL WPUB
    CLRF    WPUB	    //weak pull up disabled on all Port B
    BSF	    WPUB, UP
    BSF	    WPUB, DOWN	    //weak pull up enabled only on RB0 - RB1

    BANKSEL PORTA
    CLRF    PORTA
    CLRF    PORTC
    CLRF    PORTE
    CLRF    PORTB	//Puertos limpios
    
    CLRF    CONT	//Contador en 0
    
    RETURN
    
 setup_int:
    BSF	    GIE		    //Global interruptions Enabled
    
    BSF	    RBIE	    //PORTB change interrupt enabled
    BCF	    RBIF	    //Limpiar bandera 
    
    BSF	    T0IE	    //Habilitar interrupción Timer0
    BCF	    T0IF	    //Limpiar bandera timer 0
    RETURN
    
 reloj:
    BANKSEL OSCCON
    BSF	SCS		//Activar oscilador interno
    
    // 1 MHz
    BSF IRCF2		
    BCF IRCF1		
    BCF IRCF0		
    RETURN 
    
 timer0:
    // retraso de 5 ms
    // Fosc = 1MHz
    // PS = 256
    // T = 4 * Tosc * TMR0 * PS
    // Tosc = 1/Fosc
    // TMR0 = T * Fosc / (4 * PS) = 256-N
    // N = 256 - (5ms * 1MHz / (4 * 256))
    // N = 251 aprox
    
    BANKSEL OPTION_REG
    
    BCF T0CS	    //Funcionar como temporizador
    BCF PSA	    //Asignar Prescaler al Timer0
    
    //Prescaler de 1:256
    BSF PS2	    
    BSF PS1	    
    BSF PS0	    
    
    //Asignar el retardo
    BANKSEL PORTA
    reset_timer0
    RETURN  
 
 ORG 200h   
 tabla:
    CLRF    PCLATH
    BSF	    PCLATH, 1	//LATH en posición 1
    
    ANDLW   0x0F	//No sobrepasar el tamaño de la tabla (<16)
    ADDWF   PCL		//PC = PCLATH + PCL 
    
    RETLW   00111111B	//0
    RETLW   00000110B	//1
    RETLW   01011011B	//2
    RETLW   01001111B	//3
    RETLW   01100110B	//4
    RETLW   01101101B	//5
    RETLW   01111101B	//6
    RETLW   00000111B	//7
    RETLW   01111111B	//8
    RETLW   01101111B	//9
    RETLW   01110111B	//A
    RETLW   01111100B	//B
    RETLW   00111001B	//C
    RETLW   01011110B	//D
    RETLW   01111001B	//E
    RETLW   01110001B	//F
    
 END

