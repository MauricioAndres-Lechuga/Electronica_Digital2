;*** Directivas de Inclusión ***    
LIST P=16F887			
#include "p16f887.inc"	

;**** Configuración General ****	
	__CONFIG _CONFIG1, _XT_OSC & _WDTE_OFF & _MCLRE_ON & _LVP_OFF	    
;**** Definición de Variables ****
	    CBLOCK  0X20
		    DELAY1 
		    DELAY2 
		    DELAY3
		    DELAY4
		    DELAY5
		    DELAY6
		    DELAYRB1
		    DELAYRB2
		    DELAYRB3
	    ENDC
    
;*** Inicialización de Programa ***	    
	    ORG	    0x00
	    GOTO    INICIO
INICIO 	    ORG	    0x05
;*** Configuración de Puertos ***
INICIO	    
	    BSF	    STATUS,RP0
	    BSF	    STATUS,RP1	    ;Banco 3
	    CLRF    ANSELH	    ;PORTB digital
	    BCF	    ANSEL,5	    ;RE0 digital
	    BCF	    STATUS,RP1	    ;Banco 1
	    CLRF    TRISB	    ;PORTB salida
	    BSF	    TRISE,0	    ;RE0 entrada
	    BCF	    STATUS,RP0	    ;Banco 0
	    CLRF    PORTB

TRE0
	    CALL DELAY_RB
	    BTFSC   PORTE,0
	    GOTO    LOOP_B
	    GOTO    LOOP_RL
LOOP_B
	MOVLW	.255
	MOVWF	PORTB
	CALL	DELAY_1s
	CLRF	PORTB
	CALL	DELAY_1s
	GOTO	TRE0
	    

LOOP_RL	    
	    BSF	    PORTB,RB0	    ;RB0 en 1
	    CALL    DELAY_200ms
	    BTFSC   PORTE,0
	    GOTO    TRE0
	    BCF	    PORTB,RB0	    ;RB0 en 0
	    BSF	    PORTB,RB1	    ;RB1 en 1
	    CALL    DELAY_200ms
	    BTFSC   PORTE,0
	    GOTO    TRE0
	    BCF	    PORTB,RB1	    ;RB1 en 0
	    BSF	    PORTB,RB2	    ;RB2 en 1
	    CALL    DELAY_200ms
	    BTFSC   PORTE,0
	    GOTO    TRE0
	    BCF	    PORTB,RB2	    ;RB2 en 0
	    BSF	    PORTB,RB3	    ;RB3 en 1
	    CALL    DELAY_200ms
	    BTFSC   PORTE,0
	    GOTO    TRE0
	    BCF	    PORTB,RB3	    ;RB3 en 0
	    BSF	    PORTB,RB4	    ;RB4 en 1
	    CALL    DELAY_200ms
	    BTFSC   PORTE,0
	    GOTO    TRE0
	    BCF	    PORTB,RB4	    ;RB4 en 0
	    BSF	    PORTB,RB5	    ;RB5 en 1
	    CALL    DELAY_200ms
	    BTFSC   PORTE,0
	    GOTO    TRE0
	    BCF	    PORTB,RB5	    ;RB5 en 0
	    BSF	    PORTB,RB6	    ;RB6 en 1
	    CALL    DELAY_200ms
	    BTFSC   PORTE,0
	    GOTO    TRE0
	    BCF	    PORTB,RB6	    ;RB6 en 0
	    BSF	    PORTB,RB7	    ;RB7 en 1
	    CALL    DELAY_200ms
	    BTFSC   PORTE,0
	    GOTO    TRE0
	    BCF	    PORTB,RB7	    ;RB7 en 0
	    CALL    DELAY_200ms
	    GOTO    TRE0
	    
;*** Subrutinas ***	    
; Subrutina de Retardo con 3 Bucles Anidados para 1s 
DELAY_1s    MOVLW   D'255'	    ; 255 -> W
	    MOVWF   DELAY1	    ; W -> DELAY1
    LOOP1   MOVLW   D'245'	    ; 245 -> W
	    MOVWF   DELAY2	    ; W -> DELAY2
    LOOP2   MOVLW   D'4'	    ; 4 -> W
    	    MOVWF   DELAY3	    ; W -> DELAY3
    LOOP3   DECFSZ  DELAY3,F
	    GOTO    LOOP3
	    DECFSZ  DELAY2,F
	    GOTO    LOOP2
	    DECFSZ  DELAY1,F
	    GOTO    LOOP1
	    RETURN
	    
DELAY_200ms MOVLW   .200	    ; 200 -> W
	    MOVWF   DELAY4	    ; W -> DELAY1
    LOOP4   MOVLW   .50		    ; 50 -> W
	    MOVWF   DELAY5	    ; W -> DELAY2
    LOOP5   MOVLW   .10		    ; 10 -> W
    	    MOVWF   DELAY6	    ; W -> DELAY3
    LOOP6   DECFSZ  DELAY6,F
	    GOTO    LOOP6
	    DECFSZ  DELAY5,F
	    GOTO    LOOP5
	    DECFSZ  DELAY4,F
	    GOTO    LOOP4
	    RETURN

	    
DELAY_RB    MOVLW   .200	    ; 200 -> W
	    MOVWF   DELAYRB1	    ; W -> DELAY1
    LOOPRB1 MOVLW   .25		    ; 25 -> W
	    MOVWF   DELAYRB2	    ; W -> DELAY2
    LOOPRB2 MOVLW   .2		    ; 2 -> W
    	    MOVWF   DELAYRB3	    ; W -> DELAY3
    LOOPRB3 DECFSZ  DELAYRB3,F
	    GOTO    LOOPRB3
	    DECFSZ  DELAYRB2,F
	    GOTO    LOOPRB2
	    DECFSZ  DELAYRB1,F
	    GOTO    LOOPRB1
	    RETURN
	    
	    END


