;*** Directivas de Inclusión ***    
LIST P=16F887                
#include "p16f887.inc"

;**** Configuración General ****    
__CONFIG _CONFIG1, _XT_OSC & _WDTE_OFF & _MCLRE_ON & _LVP_OFF      

;**** Definición de Variables ****
CBLOCK 0x20
    DELAY1_150ms
    DELAY2_150ms
    DELAY3_150ms
    DELAY1_2ms
    DELAY2_2ms
    CONT
    UNI
    DECS
    CEN
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
    BCF	    ANSEL,5
    BCF	    ANSEL,6
    BCF	    ANSEL,7
    BCF     STATUS,RP1        ; Banco 1
    CLRF    TRISB             ; PORTB salida
    BCF	    TRISE,0
    BCF	    TRISE,1
    BCF	    TRISE,2
    BCF     STATUS,RP0        ; Banco 0
    CLRF    PORTB
    CLRF    PORTE
    CLRF    UNI
    CLRF    DECS
    CLRF    CEN
    CLRF    CONT
    GOTO    LOOP_UNI
;*** Loop principal ***
LOOP_DECS
    INCF    DECS,F
    MOVLW   .10
    SUBWF   DECS,W
    BTFSC   STATUS,Z
    GOTO    FINALIZACION
LOOP_UNI
    CLRF    CONT
LOOP_M
    BSF	    PORTE,0
    BCF	    PORTE,1
    BCF	    PORTE,2
    MOVF    UNI,W
    CALL    TABLA_DECO
    MOVWF   PORTB
    CALL    DELAY_2ms
    BCF	    PORTE,0
    BSF	    PORTE,1
    BCF	    PORTE,2
    MOVF    DECS,W
    CALL    TABLA_DECO
    MOVWF   PORTB
    CALL    DELAY_2ms
    BCF	    PORTE,0
    BCF	    PORTE,1
    BSF	    PORTE,2
    MOVF    CEN,W
    CALL    TABLA_DECO
    MOVWF   PORTB
    CALL    DELAY_2ms
    INCF    CONT
    MOVLW   .17
    SUBWF   CONT,W
    BTFSS   STATUS,Z
    GOTO    LOOP_M
    MOVLW   .1
    SUBWF   CEN,W
    BTFSC   STATUS,Z
    GOTO    LOOP_PARPADEO
    INCF    UNI,F
    MOVLW   .10
    SUBWF   UNI,W
    BTFSS   STATUS,Z
    GOTO    LOOP_UNI
    CLRF    UNI
    GOTO    LOOP_DECS
    
FINALIZACION
    CLRF    DECS
    INCF    CEN,F
    GOTO    LOOP_UNI
    
LOOP_PARPADEO
	BSF	PORTE,0
	BSF	PORTE,1
	BSF	PORTE,2
	MOVLW	b'00111111'
	MOVWF	PORTB
	CALL	DELAY_150ms
	CLRF	PORTB
	CALL	DELAY_150ms
	GOTO	LOOP_PARPADEO
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


DELAY_2ms
    MOVLW   D'80'         
    MOVWF   DELAY1_2ms
LOOP1_2ms
    MOVLW   D'8'          
    MOVWF   DELAY2_2ms
LOOP2_2ms
    NOP
    DECFSZ  DELAY2_2ms, F
    GOTO    LOOP2_2ms
    DECFSZ  DELAY1_2ms, F
    GOTO    LOOP1_2ms
    RETURN

    
DELAY_150ms
    MOVLW   D'75'
    MOVWF   DELAY1_150ms
LOOP1_150ms
    MOVLW   D'200'
    MOVWF   DELAY2_150ms
LOOP2_150ms
    MOVLW   D'10'
    MOVWF   DELAY3_150ms
LOOP3_150ms
    DECFSZ  DELAY3_150ms, F
    GOTO    LOOP3_150ms
    DECFSZ  DELAY2_150ms, F
    GOTO    LOOP2_150ms
    DECFSZ  DELAY1_150ms, F
    GOTO    LOOP1_150ms
    RETURN

END