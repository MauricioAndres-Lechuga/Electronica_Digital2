;*** Directivas de Inclusión ***    
LIST P=16F887                
#include "p16f887.inc"

;**** Configuración General ****    
__CONFIG _CONFIG1, _XT_OSC & _WDTE_OFF & _MCLRE_ON & _LVP_OFF    
    
;**** Definición de Variables ****
CBLOCK 0x20
    W_TEMP         
    STATUS_TEMP     
    NTECL
    COUNT_TMR0
ENDC  

;*** Vectores de Reset e Interrupción ***
ORG 0x00
GOTO INICIO
ORG 0x04
GOTO ISR_INICIO   

;==============================================================
;CONF DE MACROS
;==============================================================
;Confg de puertos
CFG_PORT    MACRO
    BANKSEL	    ANSELH
    CLRF	    ANSELH ;como es ejercicio y mas rapido clear entero
    BANKSEL	    TRISB
    MOVLW	    b'00111000'	    ;Trisb, 0 para filas en salida (RB0 a RB2), 1 para columnas en entrada (RB3 a RB5)
    MOVWF	    TRISB
    BANKSEL	    WPUB    
    MOVWF	    WPUB	   ;Activo las pull up individuales de solo las columnas
    BANKSEL	    IOCB
    MOVWF	    IOCB	   ;Enmascarar	para que solo activen interrupciones las columnas
    BCF	    OPTION_REG,7    
    BANKSEL	    TRISC
    CLRF	    TRISC
ENDM

CFG_TMR0    MACRO
    BANKSEL	    OPTION_REG
    MOVLW	    b'00000111'
    MOVWF	    OPTION_REG
    BANKSEL	    TMR0	    ;Aca hago un calculo de TMR0, con 100ms me da 61, este numero de 61 es donde comienza
    MOVLW	    .61		    ;al comenzar en 61 TMR0 tarda 100ms, ahora como quiero 25s, divido 25s / 100ms para ver cuantas veces
    MOVWF	    TMR0	    ;tiene overflow el TMR0, obligatoriamente tiene que ser menor a 255, porque es el maximo
ENDM

CFG_INT	MACRO
    BANKSEL	    INTCON
    MOVLW	    b'10101000'	    ;Activo GIE, TOIE y RBIE, bajo las flags respectivas
    MOVWF	    INTCON
ENDM

;==============================================================
; PROGRAMA PRINCIPAL
;==============================================================
INICIO    
    CFG_PORT
    CFG_TMR0
    CFG_INT
    BCF	STATUS,RP0
    BCF	STATUS,RP1
    GOTO	$
   
;==============================================================
; RUTINA DE INTERRUPCIÓN
;==============================================================
ISR_INICIO    
;Guardado de contexto
    MOVWF	W_TEMP
    SWAPF	STATUS,W
    MOVWF	STATUS_TEMP
;Testeo de Flag del timer
    BTFSC	INTCON,T0IF
    CALL	ISR_TMR0
    BTFSC	INTCON,RBIF
    CALL	ISR_TECL
    GOTO	ISR_FIN

ISR_FIN
;Reinicio de variables y bajo de banderas
    CLRF    COUNT_TMR0
    BCF	    INTCON,T0IF
    BCF	    INTCON,RBIF
    MOVFW   NTECL
    CALL    TABLA_TECL
    MOVWF   PORTC
    
    SWAPF   STATUS_TEMP,W
    MOVWF   STATUS
    SWAPF   W_TEMP,F
    SWAPF   W_TEMP,W
;==============================================================
; FUNCIONES  TIMER
;==============================================================
    
ISR_TMR0
    INCF    COUNT_TMR0,F
    MOVLW   .250	    ;Este es el numero de veces que se tiene que activar la flag de TMR0 para que sean 25s
    SUBWF   COUNT_TMR0	    
    BTFSS   STATUS,Z
    GOTO    ISR_REFTMR	    ;Refresh del TMR0
    RETURN
    
ISR_REFTMR
    MOVLW   .61		;reinicio el timer a 61 para que vuelva a contar 100ms
    MOVWF   TMR0
    GOTO    ISR_FIN
    
;==============================================================
; FUNCIONES TECLADO
;==============================================================
ISR_TECL
    CLRF    NTECL
    INCF    NTECL,F
    MOVLW   b'00000110'
    MOVWF   PORTB
    NOP

TEST_COL
    BTFSS   PORTB,RB3
    GOTO    TECL_DELAY
    INCF    NTECL,F
    BTFSS   PORTB,RB4
    GOTO    TECL_DELAY
    INCF    NTECL,F
    BTFSS   PORTB,RB5
    GOTO    TECL_DELAY
    INCF    NTECL,F
    GOTO    TEST_FIL
    
TEST_FIL
    BTFSS   PORTB,RB2
    GOTO    TECL_RST	  ;Si estoy en la ultima fila reseteo ntecla
    BSF	    STATUS,C
    RLF	    PORTB
    GOTO    TEST_COL
    
TECL_RST
    CLRF    NTECL
    CLRF    PORTB
    RETURN
    
    
TECL_DELAY
    NOP
    RETURN
;==============================================================
; TABLA DE CONVERSIÓN PARA DISPLAY 7 SEGMENTOS
;==============================================================
TABLA_TECL
    ADDWF PCL,F
    RETLW b'00111111'  ; 0
    RETLW b'00000110'  ; 1
    RETLW b'01011011'  ; 2
    RETLW b'01001111'  ; 3
    RETLW b'01100110'  ; 4
    RETLW b'01101101'  ; 5
    RETLW b'01111101'  ; 6
    RETLW b'00000111'  ; 7
    RETLW b'01111111'  ; 8
    RETLW b'01101111'  ; 9

END


