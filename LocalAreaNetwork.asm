; Version: 7 
; Author: Shuvechchha Ghimire 
; Date: 05/05/2019 
 
; Error detection - user has to turn off the system and manually do everything again 
; Program requirement:  
;	    1. User has to define master node (node that transmits initial sequence) before switching on the power 
;	    2. Switch values, except for RB0 and RB1 (corresponding data inputs) cannot be changed once power has been applied 
;	    3. This program does not work when RB6 is accidentally turned on (EXCEPT IT CAN - further scope of the project) 
    
    #include <P16F84A.inc> 
    __CONFIG _XT_OSC & _CP_OFF & _WDT_OFF & _PWRTE_ON 
;-------------- ------------------------------------------------------- 
;list of variables 
cblock 0x0C 
 
;Delay variable 
    Delay11	    ; temprorary register for Delay 
    Delay12	    ; another delay 
     
;varibles to store/manipulate/transmit data 
    VAR		    ; receiver puts the data in VAR 
    VAR1	    ;transmitter uses this variable 
    VAR2	    ;temprorary register for bit checks to identify address 
     
;count/loop variable 
    shortdel	    ; loop for receiver AND transmitter 
     
endc 
;----------------------------------------------------------------------- 
ORG 0 
 
Initialise	    BSF STATUS,5		 ;Set to bank 1 
    MOVLW B'00010000'		; Set port A data direction 
    MOVWF TRISA 
    MOVLW B'11111111'		; Set port B data direction  
    MOVWF TRISB 
    BCF OPTION_REG,7		 ; enabled pull up 
    BCF STATUS,5		    ; Set to bank 2   
;----------------------------------------------- 
;start of the main program		     
Main		    MOVLW B'00001000'		; setting all LEDs at logic 0 + transmitter at idle state 
    MOVWF PORTA 
    CALL Additional_Delay 
    BTFSC PORTB,7		; checks if main or slave node 
    GOTO Main1 
    BTFSS PORTB,7  
    GOTO Main2 
 
Main1		    CALL Free_Token 
    CALL TXmain 
    CALL Additional_Delay 
 
Main2		    BTFSC PORTA,4 
    GOTO Main2		 
    CALL RXmain	 
    CALL Additional_Delay 
    CALL Data_Process	    	; to evaluate received data 
    CALL Additional_Delay 
    CALL TXmain 
    CALL Additional_Delay 
    GOTO Main2 
;------------------------------------------------- 
;Check if the source/destination is what we wanted : SLAVES 
 
; detect if the received data is free token	 
;GOTO better than CALL because I want the test to go to receiving end, if trasmitting 
Data_Process	    CALL Transmit_Further	 
    CALL Error_Checker 
    CALL Data_Checker 
    CALL Address_Checker	 
    CALL FreeToken		      
    RETURN 
 
;-------------------------------------------------------		 
;Is the data a free token? - YES 
FreeToken	    MOVLW 0x80	    ; free token : B'10000000' 
    BCF STATUS,2 
    SUBWF VAR,0 
    BTFSC STATUS, 2	    ; identified as free token 
    CALL Transmit_Switch 
    RETURN 
 
;transmit switch values 
Transmit_Switch	    MOVF PORTB,0		    ; read switch data 
    MOVWF VAR1  
    RETURN 
     
;-------------------------------------------------------		     
;Is the destination node my node address? 	 
Address_Checker	    BCF STATUS,0	    ; to rotate - miscellaneous function 
    MOVF PORTB,0		 
    MOVWF VAR2 
    CALL Rotate		    ; to put node address in 7th and 6th bit 
    SWAPF VAR,0		    ; to put destination address of received data in 7th and 6th bit 
    XORWF VAR2,1	    ; if 7th and 6th bit are not 00, the data isnt meant for the node 
    BTFSS VAR2, 7 
    CALL Address_Checker1 
    RETURN 
     
Address_Checker1    BTFSS VAR2,6 
    CALL Receive_Data 
    RETURN 
 
; YES - puts data in LED corresponding to PORTA1 and PORTA0 
Receive_Data	    BTFSC VAR,0	    ; port A bit 0- logic high or low based on received data 
    BSF PORTA,0 
    BTFSS VAR,0 
    BCF PORTA,0 
    BTFSC VAR,1	     ; port A bit 1- logic high or low based on received data 
    BSF PORTA,1 
    BTFSS VAR,1 
    BCF PORTA,1 
    BSF VAR,6	    ; Set confirmation bit to signal that the data has been received 
    MOVF VAR,0	     
    MOVWF VAR1 
    RETURN 
    	   
;Subroutine to rotate through left for address check 
 
Rotate		    MOVLW D'2' 
    MOVWF count 
Rotatemain	    RLF VAR2, 1 
    DECFSZ count, 1 
    GOTO Rotatemain 
    RETURN  
 
;------------------------------------------------------------- 
;Did I transmit this data?  
Data_Checker	    MOVF PORTB, 0 
    MOVWF VAR2 
    MOVF VAR,0 
    XORWF VAR2,1 
    BTFSS VAR2,5 
    CALL Data_Checker1 
    RETURN 
 
Data_Checker1	    BTFSS VAR2,4 
    CALL Data_Checker2 
    RETURN 
 
;YES - Is the confirmation bit set?  
Data_Checker2	    BTFSC VAR,6 
    CALL Free_Token 
    BTFSS VAR,6 
    CALL Error_Occured  
    RETURN 
 
;YES - free token		 
Free_Token	    MOVLW 0x80	    ; B'10000000' 
    MOVWF VAR1 
    RETURN 
     
;NO - error has occured 
Error_Occured	    MOVLW 0x7F		;error sequence: B'01111111' 
    MOVWF VAR1 
    BSF PORTA,2 
    RETURN	 
     
;------------------------------------------------------------- 
;Is it an error message? - YES	     
Error_Checker	    MOVLW 0x7F		    ;error sequence: B'01111111' 
    BCF STATUS,2 
    SUBWF VAR,0 
    BTFSC STATUS, 2 
    CALL Error_Occured 
    RETURN 
;-------------------------------------------------------------- 
; Transmit further - YES 
     
Transmit_Further    MOVF VAR,0 
    MOVWF VAR1 
    RETURN		     
 
;-------------------------------------------------- 
;Subroutine to receive data 
 
RXmain		CALL Standard_Delay		    ; delay required after reception of start bit 
CALL Sample_Delay	    ; (1/2 of Delay2) additional delay to ensure sampling is done in the middle  
MOVLW D'8'    
MOVWF shortdel 
CALL RX 
CALL Standard_Delay		    ;stop bit equivalent of  
RETURN 
 
RX		BTFSC PORTA,4		    ;bit check of carry status 
BSF STATUS,0 
BTFSS PORTA,4  
BCF STATUS, 0 
RRF VAR, 1		    ;rotate through carry 
CALL Standard_Delay 
DECFSZ shortdel,1	    ;calls subroutine 8 times 
GOTO RX 
RETURN 
 
;----------------------------------------------------		 
;Subroutine to transmit data	 
 
TXmain		CALL Sample_Delay	    ;time delay to prepare the receiver for reception 
BCF PORTA,3		    ;start bit 
CALL Standard_Delay 
MOVLW D'8'	     
MOVWF shortdel 
CALL TX 
BSF PORTA,3		    ; stop bit 
CALL Standard_Delay	   
CALL Sample_Delay	    ; to ensure reception and transmission take similar time span 
RETURN 
 
TX		RRF VAR1, 1		    ;rotate through carry 
BTFSS STATUS, 0		    ;transmit logic 0 
BCF PORTA,3  
BTFSC STATUS,0		    ;transmit logic 1 
BSF PORTA,3 
CALL Standard_Delay 
DECFSZ shortdel, 1 
GOTO TX 
RETURN		 
 
;---------------------------------------------------- 
;Delays	 
Additional_Delay	MOVLW D'4'		    ;additional multi-purpose time delay 
MOVWF Delay11				 
Delay			CALL Standard_Delay		     
DECFSZ Delay11,1 
GOTO Delay 
RETURN  
 
Sample_Delay		MOVLW D'125'		    ; additional delay for sampling purposes 
MOVWF Delay12 
CALL DELAY 
RETURN 
 
Standard_Delay		MOVLW D'250'		    ;standard time delay 
MOVWF Delay12  
 
DELAY			DECFSZ Delay12,1	 
GOTO DELAY 
RETURN 
END 
 
 
 
