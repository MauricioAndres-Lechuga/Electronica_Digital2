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
    TEMP2
    INDEX
    RESTO
    ADC_DB    
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
   
INI_PORTC MACRO
    BANKSEL TRISC
    BCF	    TRISC,0
    BCF	    TRISC,1
    BCF	    TRISC,2
    BCF	    TRISC,3
    BCF     TRISC,6     ; RC6 como salida para TX
ENDM
    
INI_PORTA MACRO
    BANKSEL ANSEL
    BCF	    ANSEL,2
    BCF	    ANSEL,4
    BANKSEL TRISA
    BCF	    TRISA,2
    BCF	    TRISA,4
    BCF	    TRISA,5
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
   CLRF	PORTA
   CLRF	PORTC
   CLRF	PORTE
   CLRF PORTB
   CLRF PORTD
   CLRF NTECL
   CLRF UNI
   CLRF DECS
   CLRF CEN
   CLRF	ADC_DB
   MOVLW    .90
   MOVWF    MAX_dB
ENDM

INI_UART MACRO
   BANKSEL TXSTA
   BSF     TXSTA, TXEN      ; Transmisión habilitada
   BCF     TXSTA, SYNC      ; Modo asíncrono (comparten clock)
   BSF     TXSTA, BRGH      ; Alta velocidad
   BANKSEL BAUDCTL
   BCF     BAUDCTL, BRG16   ; Generador de Baudrate de 8 bits
   BANKSEL SPBRG
   MOVLW   D'25'            ; 9600 baudios con 4MHz ---> Fosc / (16 × (SPBRG + 1)) --> SPBRG = (4,000,000 / 153,600) - 1 ? 25
   MOVWF   SPBRG    
   BANKSEL RCSTA
   BSF     RCSTA, SPEN      ; Habilita todo el puerto serial (UART)
ENDM

INI_INTER  MACRO
   BANKSEL INTCON
   BCF INTCON, RBIF      ; Limpia bandera anterior
   MOVF PORTB, W         ; Lectura obligatoria para armar el latch
   BSF INTCON, RBIE       ; Habilita interrupción en cambio de RB
   BSF INTCON, GIE        ; Habilita interrupciones globales
ENDM

INI_ADC MACRO
    ; HABILITAR AN0 COMO ANALOGICO
    BANKSEL ANSEL
    BSF     ANSEL,0            ; RA0 analógico

    ; RA0 como entrada
    BANKSEL TRISA
    BSF     TRISA,0

    ; ADCON1 CONFIGURA REFERENCIAS
    BANKSEL ADCON1
    MOVLW   b'00000010'        ; Vref = Vdd/Vss

    ; ADCON0 CONFIGURA CANAL Y CLOCK
    BANKSEL ADCON0
    MOVLW   b'10000001'        ; ADCS=10 (Fosc/32), CHS=000 (AN0), ADON=1
    MOVWF   ADCON0
ENDM

;==============================================================
; PROGRAMA PRINCIPAL
;==============================================================
INICIO   
INI_PUERTOS
INI_PORTB
INI_PORTE
INI_PORTA
INI_PORTC
INI_PORTD
INI_TECL
INI_UART        
INI_ADC
INI_INTER

MAIN_LOOP
    CALL ADC_READ
    CALL TRANS_ADC_DB
    CALL MAXdB_TRANS
    CALL MAXdB_COMP
    CALL MUESTREO
    CALL SEND_ADC
    NOP
    GOTO MAIN_LOOP

;==============================================================
; RUTINA DE INTERRUPCIÓN
;==============================================================
ISR_INICIO    
    MOVWF   W_TEMP
    MOVF    STATUS,W
    MOVWF   STATUS_TEMP		;Guardamos contexto
    BTFSS   INTCON,RBIF		;si hubo interrupcion Salta a CLRF NTECL
    GOTO    ISR_FIN
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
; Guarda valor según la tecla detectada (1 a 16)
;--------------------------------------------------------------
TECL_LOAD
    MOVF    NTECL,W
    ANDLW   0x0F            ; Limita a 0-15
    MOVWF   TEMP1           ; Guarda temporalmente
    
    ; Configurar PCLATH
    MOVLW   HIGH TABLA_MAXdB	;Cargo en W el byte mas alto de tabla max
    MOVWF   PCLATH		;Lo guardo en PCLATH para usarlo cuando se haga la asignacion en el PCL de la tabla
	
    MOVF    TEMP1,W
    CALL    TABLA_MAXdB
    MOVWF   MAX_dB		;Guardo el valor de la tecla presionada
    
    ; Restaurar PCLATH
    CLRF    PCLATH		;limpio el PCLATH para que no me afecte en otras partes del programa
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
    ANDWF   PORTB,W		;Me quedo con RB4?RB7 solamente	(me quedo con las filas)
    SUBLW   b'11110000'         
    BTFSS   STATUS,Z		;si Z=0	entonces hay una tecla presionada
    GOTO    WAIT_RELEASE	;repito hasta que no haya ninguna tecla presionada  
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
    MOVF    STATUS_TEMP,W
    MOVWF   STATUS
    MOVF    W_TEMP,W
    RETFIE
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
;==============================================================
; RUTINA ADC (actualiza ADC)
;==============================================================
ADC_READ
    ; ESPERA DE ADQUISICION (TACQ >= 20us)
    MOVLW   D'50'              ; se carga el 50 para generar un retardo para estabilizar la muestra en el capacitor ~ 20us
    MOVWF   TEMP1
ACQ_LOOP
	DECFSZ  TEMP1,F		;Decremento hasta que sea 0, (espero 50microsegundos)
	GOTO    ACQ_LOOP
	
	; COMENZAR CONVERSION
	BANKSEL ADCON0
	BSF     ADCON0,GO_DONE

WAIT_ADC
	BTFSC   ADCON0,GO_DONE
	GOTO    WAIT_ADC

	BANKSEL ADRESH
	MOVF    ADRESH,W           ; LECTURA (JUSTIF IZQ)
	RETURN
	
; ============================================================
;  TRANS_ADC_DB
;  Convierte ADRESH (0?255) -> ADC_DB (0?120 dB)
;  Usa tabla + interpolación discreta.
;
;  REGISTROS USADOS:  TEMP1, TEMP2, INDEX, RESTO
; ============================================================


TRANS_ADC_DB
    ; -------- copiar ADC --------
    BANKSEL ADRESH
    MOVF    ADRESH,W
    MOVWF   TEMP1              ; TEMP1 = ADC (0?255)

    ; -------- índice = ADC/16 --------
    MOVF    TEMP1,W
    ANDLW   0xF0               ; deja nibble alto
    MOVWF   INDEX              ; INDEX = nibble alto
    SWAPF   INDEX,F            ; lo pasa a nibble bajo

    ; -------- resto = ADC % 16 --------
    MOVF    TEMP1,W
    ANDLW   0x0F
    MOVWF   RESTO

    ; -------- cargar tabla[index] --------
    MOVLW   HIGH TABLA_MAXdB
    MOVWF   PCLATH

    MOVF    INDEX,W
    CALL    TABLA_MAXdB
    MOVWF   ADC_DB             ; valor base

    ; -------- delta = tabla[index+1] - tabla[index] --------
    INCF    INDEX,F            ; índice siguiente
    MOVF    INDEX,W
    CALL    TABLA_MAXdB
    MOVWF   TEMP1              ; TEMP1 = tabla[i+1]

    DECF    INDEX,F
    MOVF    INDEX,W
    CALL    TABLA_MAXdB
    SUBWF   TEMP1,F            ; TEMP1 = delta

    ; ahora:
    ;   TEMP1 = delta
    ;   RESTO = resto 0?15

    ; -------- interpolación (delta * resto) --------
    CLRF    TEMP2              ; acumulador = 0

MUL_LOOP
    MOVF    RESTO,F
    BTFSC   STATUS,Z
    GOTO    MUL_DONE

    MOVF    TEMP1,W
    ADDWF   TEMP2,F           ; TEMP2 += delta

    DECF    RESTO,F
    GOTO    MUL_LOOP

MUL_DONE
    ; dividir por 16 ? nibble alto ? nibble bajo
    SWAPF   TEMP2,W           
    ANDLW   0x0F

    BANKSEL ADC_DB
    ADDWF   ADC_DB,F           ; suma interpolación

    CLRF    PCLATH
    RETURN
    
;==============================================================
; TRANSMISION SERIE
;==============================================================
SEND_ADC
    LOOP_SENDADC
    BANKSEL TXSTA
    BTFSS   TXSTA, TRMT      ; Esperar buffer vacío
    GOTO    LOOP_SENDADC
    BANKSEL ADC_DB
    MOVF    ADC_DB, W        ; ADC de 8 bits
    BANKSEL TXREG
    MOVWF   TXREG            ; Enviar 1 byte crudo
RETURN
;==============================================================
; RUTINA Transformacion a UNI,DEC y CEN con TRANSMISION SERIE
;==============================================================
MAXdB_TRANS
    BANKSEL MAX_dB
    MOVF    MAX_dB,W
    MOVWF   TEMP1       ; número 0?255

    CLRF    CEN
    CLRF    DECS
; -------- CENTENAS (100) ---------
CENT_LOOP
    MOVLW   D'100'
    SUBWF   TEMP1,F
    BTFSS   STATUS,C    ; ¿fue negativa?
    GOTO    FIX_CENT
    INCF    CEN,F
    GOTO    CENT_LOOP

FIX_CENT
    MOVLW   D'100'
    ADDWF   TEMP1,F      ; restaurar TEMP1

; -------- DECENAS (10) ---------
DEC_LOOP
    MOVLW   D'10'
    SUBWF   TEMP1,F
    BTFSS   STATUS,C
    GOTO    FIX_DEC
    INCF    DECS,F
    GOTO    DEC_LOOP

FIX_DEC
    MOVLW   D'10'
    ADDWF   TEMP1,F      ; restaurar TEMP1

; -------- UNIDADES --------
    MOVF    TEMP1,W      ; el resto final
    MOVWF   UNI
    RETURN

;==============================================================
; RUTINA COMPARACION ADC - BARGRAPH
;==============================================================
MAXdB_COMP
    ; limpiar LEDs
    BANKSEL PORTA
    BCF PORTA,4     
    BCF PORTA,2     ; LED MAX
    BANKSEL PORTC
    BCF PORTC,0
    BCF PORTC,1
    BCF PORTC,2	    ;LED MIN
    BCF PORTC,3
    BCF	STATUS,C

    ; copiar MAX_dB
    MOVF MAX_dB,W
    MOVWF TEMP1

;-------------------------------
; LED MAX (A2)
    BANKSEL ADC_DB
    MOVF ADC_DB,W
    SUBWF TEMP1,W
    BTFSS STATUS,C
    BSF PORTA,2
    BCF	STATUS,C

;-------------------------------
; LED A4 
    MOVLW .10
    SUBWF TEMP1,F
    BANKSEL ADC_DB
    MOVF ADC_DB,W
    SUBWF TEMP1,W
    BTFSS STATUS,C
    BSF PORTA,4
    BCF	STATUS,C

;-------------------------------
; LED C0
    MOVLW .10
    SUBWF TEMP1,F
    BANKSEL ADC_DB
    MOVF ADC_DB,W
    SUBWF TEMP1,W
    BTFSS STATUS,C
    BSF PORTC,0
    BCF	STATUS,C

;-------------------------------
; LED C1
    MOVLW .10
    SUBWF TEMP1,F
    BANKSEL ADC_DB
    MOVF ADC_DB,W
    SUBWF TEMP1,W
    BTFSS STATUS,C
    BSF PORTC,1
    BCF	STATUS,C

;-------------------------------
; LED C2
    MOVLW .10
    SUBWF TEMP1,F
    BANKSEL ADC_DB
    MOVF ADC_DB,W
    SUBWF TEMP1,W
    BTFSS STATUS,C
    BSF PORTC,2
    BCF	STATUS,C

;-------------------------------
; LED MIN (C3)
    MOVLW .10
    SUBWF TEMP1,F
    BANKSEL ADC_DB
    MOVF ADC_DB,W
    SUBWF TEMP1,W
    BTFSS STATUS,C
    BSF PORTC,3
    BCF	STATUS,C
    
    RETURN

;==============================================================
; RUTINA MUESTREO (actualiza displays o salidas)
;==============================================================
MUESTREO
    ; ===== DIGITO UNIDADES =====
    BANKSEL PORTE
    BCF	    PORTE,0
    BCF	    PORTE,1
    BCF	    PORTE,2
    BANKSEL PORTA
    BSF	    PORTA,5
    
    MOVLW HIGH TABLA_TECL   ; <<< cargar página
    MOVWF PCLATH
    MOVF    UNI,W
    CALL    TABLA_TECL
    CLRF    PCLATH          ; <<< restaurar
    MOVWF   PORTD
    CALL    DELAY_2ms

    ; ===== DIGITO DECENAS =====
    BANKSEL PORTE
    BCF	    PORTE,0
    BCF	    PORTE,1
    BSF	    PORTE,2
    BANKSEL PORTA
    BCF	    PORTA,5

    MOVLW HIGH TABLA_TECL
    MOVWF PCLATH
    MOVF    DECS,W
    CALL    TABLA_TECL
    CLRF    PCLATH
    MOVWF   PORTD
    CALL    DELAY_2ms

    ; ===== DIGITO CENTENAS =====
    BANKSEL PORTE
    BSF	    PORTE,0
    BCF	    PORTE,1
    BCF	    PORTE,2
    BANKSEL PORTA
    BCF	    PORTA,5

    MOVLW HIGH TABLA_TECL
    MOVWF PCLATH
    MOVF    CEN,W
    CALL    TABLA_TECL
    CLRF    PCLATH
    MOVWF   PORTD
    CALL    DELAY_2ms
    
    ; ===== GUARDA (LETRA ?dE?) =====
    BANKSEL PORTE
    BCF	    PORTE,0
    BSF	    PORTE,1
    BCF	    PORTE,2
    BANKSEL PORTA
    BCF	    PORTA,5

    MOVLW b'11011110'
    MOVWF PORTD
    CALL DELAY_2ms
    
RETURN

;==============================================================
; TABLA DE CONVERSIÓN PARA MAX_dB
;==============================================================
TABLA_MAXdB
    ADDWF PCL, F
    RETLW .50
    RETLW .54
    RETLW .58
    RETLW .62	
    RETLW .66
    RETLW .70
    RETLW .74
    RETLW .78
    RETLW .82
    RETLW .86
    RETLW .90
    RETLW .94
    RETLW .98
    RETLW .105
    RETLW .110
    RETLW .115

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