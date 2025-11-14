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
    UNI
    DECS
    CEN
    ISR_TECL
    NTECL
    MAX_dB
    TEMP1
ENDC  

;*** Vectores de Reset e Interrupción ***
ORG 0x00
GOTO INICIO
ORG 0x04
GOTO ISR_INICIO   

    
;==============================================================
; DEFINICION DE MACROS
;==============================================================
INI_PORTB MACRO
  BANKSEL ANSELH
  CLRF    ANSELH	         ; PORTB digital
  BANKSEL TRISB
  MOVLW b'11110000'         ; RB7-RB4 = entradas (columnas), RB3-RB0 = salidas (filas)
  MOVWF TRISB
ENDM
  
INI_PORTE MACRO
   BANKSEL ANSEL
   BCF	    ANSEL,5
   BCF	    ANSEL,6
   BCF	    ANSEL,7 ;PORTE digital
   BANKSEL  TRISE
   BCF	    TRISE,0
   BCF	    TRISE,1
   BCF	    TRISE,2 ;PORTE salidas
ENDM
   
INI_PORTD MACRO
   BANKSEL  TRISD
   CLRF	    TRISD ;PORTD salida, no tiene ANSEL, solo digital
ENDM
   
INI_TECL MACRO
   BANKSEL OPTION_REG
   BCF OPTION_REG,7	      ; Habilita pull-ups en PORTB (RBPU=0)
   BANKSEL IOCB
   MOVLW b'11110000'          ; Habilita cambio en RB7?RB4
   MOVWF IOCB
ENDM
   
INI_PUERTOS MACRO
   BANKSEL PORTB
   CLRF PORTB
   CLRF PORTD
   CLRF NTECL
   CLRF UNI
   CLRF DECS
   CLRF CEN
   CLRF	MAX_DB
ENDM
   
INI_INTER  MACRO
   BANKSEL INTCON
   BCF INTCON, RBIF      ; Limpia bandera anterior
   MOVF PORTB, W         ; Lectura obligatoria para armar el latch
   BSF INTCON, RBIE       ; Habilita interrupción en cambio de RB
   BSF INTCON, GIE        ; Habilita interrupciones globales
ENDM

INI_ADC MACRO
   BANKSEL ANSEL
   BSF     ANSEL,0        ; AN0 analógico
   BANKSEL TRISA
   BSF     TRISA,0        ; RA0 entrada
   BANKSEL ADCON1
   MOVLW   b'10000000'    ; ADFM=1, Vref=Vdd/Vss
   MOVWF   ADCON1
   BANKSEL ADCON0
   MOVLW   b'01000001'    ; ADCS=01 (Fosc/8), AN0, ADON=1
   MOVWF   ADCON0
ENDM
;==============================================================
; PROGRAMA PRINCIPAL
;==============================================================
INICIO       
INI_PORTB
INI_PORTE
INI_PORTD
INI_TECL
INI_PUERTOS
INI_INTER
INI_ADC

LOOP_MUESTREO
   CALL ADC_READ
   CALL ADC_TRANS
   CALL	MAXdB_COMP
   CALL MUESTREO             ; Actualiza displays o salida
   GOTO LOOP_MUESTREO
    
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
    MOVF    NTECL,W        
    MOVWF   MAX_dB
    BCF     INTCON,RBIE         
    BCF     INTCON,GIE          
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
; RUTINA ADC (actualiza ADC)
;==============================================================
ADC_READ
    NOP
    NOP
    NOP
    NOP
    NOP     ; ~5 us
    BANKSEL ADCON0
    BSF	    ADCON0, GO_DONE

WAIT_ADC
    BTFSC   ADCON0,GO_DONE
    GOTO    WAIT_ADC
    BANKSEL ADRESH
    MOVF    ADRESH,W
RETURN
;==============================================================
; RUTINA Transformacion a UNI,DEC y CEN 
;==============================================================
ADC_TRANS
    BANKSEL ADRESH
    MOVF   ADRESH,W
    MOVWF  TEMP1
    CLRF   CEN
    CLRF   DECS

; -------- CENTENAS ---------
CENT_LOOP
    MOVLW  D'100'
    SUBWF  TEMP1,F
    BTFSS  STATUS,C
    GOTO   FIX_CENT
    INCF   CEN,F
    GOTO   CENT_LOOP

FIX_CENT
    MOVLW  d'100'
    ADDWF  TEMP1,F

; -------- DECENAS ---------
DEC_LOOP
    MOVLW  d'10'
    SUBWF  TEMP1,F
    BTFSS  STATUS,C
    GOTO   FIX_DEC
    INCF   DECS,F
    GOTO   DEC_LOOP

FIX_DEC
    MOVLW  d'10'
    ADDWF  TEMP1,F

; -------- UNIDADES --------
    MOVF   TEMP1,W
    MOVWF  UNI
    RETURN
;==============================================================
; RUTINA COMPARACION ADC 
;==============================================================
MAXdB_COMP
    BCF    PORTA,1
    BCF	   PORTA,2
    BCF	   PORTA,3
    BCF	   PORTA,4
    BCF	   PORTA,5
    BCF	   PORTA,6
    BANKSEL ADRESH
    MOVF    ADRESH,W
    BANKSEL MAXdB
    SUBWF   MAXdB,F
    BTFSS   STATUS,C
    BSF	    PORTA,1 
RETURN
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
    RETLW .20  ; 0
    RETLW .25  ; 1
    RETLW .30  ; 2
    RETLW .35  ; 3
    RETLW .40  ; 4
    RETLW .45  ; 5
    RETLW .50  ; 6
    RETLW .55  ; 7
    RETLW .60  ; 8
    RETLW .65  ; 9
    RETLW .70  ; A
    RETLW .75  ; B
    RETLW .80  ; C
    RETLW .85  ; D
    RETLW .90  ; E
    RETLW .95  ; F

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