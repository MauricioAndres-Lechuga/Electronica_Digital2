;*** Directivas de Inclusión ***    
LIST P=16F887                
#include "p16f887.inc"

;**** Configuración General ****    
__CONFIG _CONFIG1, _XT_OSC & _WDTE_OFF & _MCLRE_ON & _LVP_OFF      

;**** Definición de Variables ****
CBLOCK 0x20
    DELAY1 
    DELAY2 
    DELAY3
    CONT
ENDC

;*** Inicialización de Programa ***     
ORG 0x00
    GOTO INICIO       ; reset vector

ORG 0x05          ; vector de interrupción
    RETFIE            ; (si no usás interrupciones)

;*** Inicio del programa ***
INICIO
; Configuración de puertos
    BSF     STATUS,RP0
    BSF     STATUS,RP1        ; Banco 3
    CLRF    ANSELH            ; PORTB digital
    BCF     STATUS,RP1        ; Banco 1
    CLRF    TRISB             ; PORTB salida
    BCF     STATUS,RP0        ; Banco 0
    CLRF    PORTB
    CLRF    CONT

;*** Loop principal ***
LOOP_PRINCIPAL
    MOVF    CONT,W
    CALL    TABLA_DECO
    MOVWF   PORTB
    CALL    DELAY_1s
    INCF    CONT,F
    MOVLW   .10
    SUBWF   CONT,W
    BTFSC   STATUS,Z
    CLRF    CONT
    GOTO    LOOP_PRINCIPAL

;*** Tabla de decodificación usando ADDWF PCL,F ***
TABLA_DECO
    ADDWF PCL,F        ; sumamos W (CONT) al PCL
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

;*** Subrutina de retardo 1s con 3 bucles anidados ***
DELAY_1s
    MOVLW   D'255'
    MOVWF   DELAY1
LOOP1
    MOVLW   D'245'
    MOVWF   DELAY2
LOOP2
    MOVLW   D'4'
    MOVWF   DELAY3
LOOP3
    DECFSZ  DELAY3,F
    GOTO    LOOP3
    DECFSZ  DELAY2,F
    GOTO    LOOP2
    DECFSZ  DELAY1,F
    GOTO    LOOP1
    RETURN

END
