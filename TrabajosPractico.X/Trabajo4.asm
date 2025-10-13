;*** Directivas de Inclusión ***    
LIST P=16F887                
#include "p16f887.inc"

;**** Configuración General ****    
__CONFIG _CONFIG1, _XT_OSC & _WDTE_OFF & _MCLRE_ON & _LVP_OFF    
    
;**** Definición de Variables ****
CBLOCK 0x20
    W_TEMP         
    STATUS_TEMP     
    DELAY1_2ms
    DELAY2_2ms
    DELAY1_20ms
    DELAY2_20ms
    CONT
    UNI
    DECS
    CEN
    ISR_TECL
    NTECL
    NTECL_CONT
ENDC  

;*** Vectores de Reset e Interrupción ***
ORG 0x00
GOTO INICIO
ORG 0x04
GOTO ISR_INICIO   

;==============================================================
; PROGRAMA PRINCIPAL
;==============================================================
INICIO    
    BANKSEL ANSELH
    CLRF    ANSELH	         ; PORTB digital
    BCF	    ANSEL,5
    BCF	    ANSEL,6
    BCF	    ANSEL,7
    BANKSEL TRISB
    MOVLW b'11110000'         ; RB7-RB4 = entradas (columnas), RB3-RB0 = salidas (filas)
    MOVWF TRISB
    BCF	    TRISE,0
    BCF	    TRISE,1
    BCF	    TRISE,2
    CLRF    TRISD
    
    BANKSEL OPTION_REG
    BCF OPTION_REG,7	         ; Habilita pull-ups en PORTB (RBPU=0)
   
    BANKSEL IOCB
    MOVLW b'11110000'          ; Habilita cambio en RB7?RB4
    MOVWF IOCB
    
    ; Inicializa las filas en alto (sin presionar tecla)
    BANKSEL PORTB
    MOVLW   b'00000000'      ; 
    MOVWF PORTB
    CLRF  PORTD
    CLRF NTECL
    CLRF CONT
    CLRF UNI
    CLRF DECS
    CLRF CEN
     CLRF NTECL_CONT          
   
    ; Habilita interrupciones por cambio en PORTB
    BANKSEL INTCON
    BCF INTCON, RBIF      ; Limpia bandera anterior
    MOVF PORTB, W         ; Lectura obligatoria para armar el latch
    BSF INTCON, RBIE       ; Habilita interrupción en cambio de RB
    BSF INTCON, GIE        ; Habilita interrupciones globales

MAIN_LOOP
LOOP_MUESTREO
    CALL MUESTREO             ; Actualiza displays o salida
    INCF    CONT,F
    MOVLW   .17
    SUBWF   CONT,W
    BTFSS   STATUS,Z
    GOTO    LOOP_MUESTREO
    GOTO    MAIN_LOOP
    
;==============================================================
; RUTINA DE INTERRUPCIÓN
;==============================================================
ISR_INICIO    
    MOVWF   W_TEMP
    MOVFW   STATUS
    MOVWF   STATUS_TEMP

    BTFSS   INTCON,RBIF
    GOTO    ISR_FIN
    
    ; *** ANTIRREBOTE INICIAL ***
    CALL    DELAY_20ms
    
    CLRF    NTECL              
    MOVLW   b'00001110'        ; Activa primera fila
    MOVWF   PORTB
    CALL    DELAY_20ms          ; *** DELAY PARA ESTABILIZAR ***
    GOTO    TEST_COL

;--------------------------------------------------------------
; Detecta columna activa
;--------------------------------------------------------------
TEST_COL
    BTFSS   PORTB,4            
    GOTO    TECL_DELAYC1
    INCF    NTECL,F            
    
    BTFSS   PORTB,5            
    GOTO    TECL_DELAYC2
    INCF    NTECL,F            
    
    BTFSS   PORTB,6            
    GOTO    TECL_DELAYC3
    INCF    NTECL,F            
    
    BTFSS   PORTB,7            
    GOTO    TECL_DELAYC4
    
    INCF    NTECL,F            
    GOTO    TEST_FIL

;--------------------------------------------------------------
; Cambia fila activa para seguir buscando tecla
;--------------------------------------------------------------
TEST_FIL
    BTFSS   PORTB,RB3            
    GOTO    TECL_RES           
    
    BSF     STATUS,C
    RLF     PORTB,F            
    CALL    DELAY_20ms          ; *** DELAY DESPUÉS DE CAMBIAR FILA ***
    GOTO    TEST_COL

;--------------------------------------------------------------
; Detecta qué columna se activó y verifica tecla
;--------------------------------------------------------------
TECL_DELAYC1
    CALL    DELAY_20ms
    CALL    DELAY_20ms
    BTFSS   PORTB,4             
    GOTO    TECL_LOAD
    GOTO    TECL_RES

TECL_DELAYC2
    CALL    DELAY_20ms
    CALL    DELAY_20ms
    BTFSS   PORTB,5
    GOTO    TECL_LOAD
    GOTO    TECL_RES

TECL_DELAYC3
    CALL    DELAY_20ms
    CALL    DELAY_20ms
    BTFSS   PORTB,6
    GOTO    TECL_LOAD
    GOTO    TECL_RES

TECL_DELAYC4
    CALL    DELAY_20ms
    CALL    DELAY_20ms
    BTFSS   PORTB,7
    GOTO    TECL_LOAD
    GOTO    TECL_RES

;--------------------------------------------------------------
; Guarda valor según la tecla y fila detectada
;--------------------------------------------------------------
TECL_LOAD
    INCF    NTECL_CONT,F
    
    MOVLW   0x04
    SUBWF   NTECL_CONT,0
    BTFSC   STATUS,Z
    GOTO    TECL_RES

    MOVLW   0x03
    SUBWF   NTECL_CONT,0
    BTFSC   STATUS,Z
    GOTO    TECL_LOAD3

    MOVLW   0x02
    SUBWF   NTECL_CONT,0
    BTFSC   STATUS,Z
    GOTO    TECL_LOAD2

    GOTO    TECL_LOAD1

TECL_LOAD3
    MOVF    NTECL,W        
    MOVWF   UNI
    BCF     INTCON,RBIE         
    BCF     INTCON,GIE          
    GOTO    TECL_RES
    
TECL_LOAD2
    MOVF    NTECL,W
    MOVWF   DECS
    GOTO    TECL_RES
    
TECL_LOAD1
    MOVF    NTECL,W
    MOVWF   CEN
    GOTO    TECL_RES

;--------------------------------------------------------------
; Limpieza final de interrupción
;--------------------------------------------------------------
TECL_RES
    ; *** ACTIVAR TODAS LAS FILAS PARA DETECTAR LIBERACIÓN ***
    MOVLW   b'00001111'         ; Activa todas las filas
    MOVWF   PORTB
    NOP
    NOP
    
WAIT_RELEASE
    MOVLW   b'11110000'
    ANDWF   PORTB,W
    SUBLW   b'11110000'         
    BTFSS   STATUS,Z
    GOTO    WAIT_RELEASE        
    
    CLRF    NTECL        
    MOVLW   b'00000000'         ; Desactiva todas las filas
    MOVWF   PORTB
    NOP
    NOP
    MOVF    PORTB,W             ; Lectura para limpiar mismatch
    BCF     INTCON,RBIF
    GOTO    ISR_FIN

;--------------------------------------------------------------
; Restaura registros y sale de interrupción
;--------------------------------------------------------------
ISR_FIN
    MOVFW   STATUS_TEMP
    MOVWF   STATUS
    MOVFW   W_TEMP
    RETFIE

;==============================================================
; RUTINA MUESTREO (actualiza displays o salidas)
;==============================================================
MUESTREO
    BSF	    PORTE,0
    BCF	    PORTE,1
    BCF	    PORTE,2
    MOVF    UNI,W
    CALL    TABLA_TECL
    MOVWF   PORTD
    CALL    DELAY_2ms

    BCF	    PORTE,0
    BSF	    PORTE,1
    BCF	    PORTE,2
    MOVF    DECS,W
    CALL    TABLA_TECL
    MOVWF   PORTD
    CALL    DELAY_2ms

    BCF	    PORTE,0
    BCF	    PORTE,1
    BSF	    PORTE,2
    MOVF    CEN,W
    CALL    TABLA_TECL
    MOVWF   PORTD
    CALL    DELAY_2ms
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
    RETLW b'01110111'  ; A
    RETLW b'01111100'  ; B
    RETLW b'00111001'  ; C
    RETLW b'01011110'  ; D
    RETLW b'01111001'  ; E
    RETLW b'01110001'  ; F

;==============================================================
; DELAYS
;==============================================================
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

DELAY_20ms
    MOVLW   D'80'          
    MOVWF   DELAY1_20ms
LOOP1_20ms
    MOVLW   D'80'          
    MOVWF   DELAY2_20ms
LOOP2_20ms
    NOP
    DECFSZ  DELAY2_20ms, F
    GOTO    LOOP2_20ms
    DECFSZ  DELAY1_20ms, F
    GOTO    LOOP1_20ms
    RETURN

END