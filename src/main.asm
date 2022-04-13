.386

; ========== constants
BOOT_RECORD				EQU	446			; offset (to Partition Table or Extended Partition Table)

DSCR_SIZE				EQU 10h			; descriptor size
DSCR_COUNT				EQU	04h			; number of descriptors in MBR-sector

DSCR_F_CHS_END			EQU	05h			; field CHS-Ending
DSCR_F_CODE				EQU	04h			; field System Code
DSCR_F_BEGIN			EQU 08h			; field LBA-Beginning
DSCR_F_SIZE				EQU	0Ch			; filed size (in sectors)

DSCR_F2_REL				EQU 18h			; field Offset to the next EPR
DSCR_F2_CODE			EQU 14h			; field System code in the second descriptor

; ========== data segment
dseg segment use16
	sector1				db	512 dup (0)	; space for sector
	sector2				db	512 dup (0)	; space for sector
	
	; пакет дискового адреса
	packet				db	16			; packet size
						db	0			;
	packet_sec_count	db	1			; number of sectors for reading
						db	0			;
	packet_dest			dw	0			; address of storing area
						dw	dseg		; segment register (from/into)
	packet_lba			dq	0			; sector's number (LBA)

	; вывод количества LD`
	msg_ld_count		db	0Dh, 0Ah, 'Enter first LD for merging: 01 ..  '
	ld_count_ascii		db, ' ', '- 1 : $'

	; ввод номера LD для объединения
	input_ld			db	3, 4 dup (0)	; logical disk number (2 symbols) + Enter (1 symbol)

	; фиксированные
	hd_number			db	0			; hard disk number
	ld_number			db	0			; logical disk number
	ld_count			db	0			; number of logical disks in Extended Partition
	lba_list			dd	23 dup (0)	; array of beginning of EPRs (LBA coordinates)

	; текстовые сообщения
	msg_usage			db	0Dh, 0Ah, 'Usage: <HD number: 0..3>$'
	
	msg_success			db	0Dh, 0Ah, 'Your logical disks were merged$'
	
	msg_err_r_sector	db	0Dh, 0Ah, 'Invalid sector reading$'
	msg_err_w_sector	db	0Dh, 0Ah, 'Invalid sector writing$'
	msg_err_wrong_ld	db	0Dh, 0Ah, 'Invalid logical disk number$'
	msg_err_no_2ld		db	0Dh, 0Ah, 'There are no 2 logical disks$'
	msg_err_diff_code	db	0Dh, 0Ah, 'Your logical disks have diff FS$'
	
	msg_err_no_epart	db	0Dh, 0Ah, 'This HD has no extended partition$'
dseg ends

; ========== error handling macros
throw MACRO message			; unconditional jump
	lea DX, message
	jmp cs_end
endm

throw_c MACRO message		; jump if CF = 1
	lea DX, message
	jc cs_end
endm

throw_e MACRO message		; jump if ZF = 1
	lea DX, message
	jz cs_end
endm

; ========== sector reading macro
read_sector MACRO drive, packet, message
	mov AH, 42h
	mov DL, drive
	lea SI, packet
	
	int 13h
	
	throw_c message			; call throw_c macro
endm

; ========== code segment
cseg segment use16
assume CS:cseg, DS:dseg
start:
	mov AX, dseg
	mov DS, AX
	
; ========== getting and processing a parameter
	mov AL, ES:[82h]		; select a byte following the space (81h + 1)
	call ascii_to_hex_hd	; convert this parameter into hex and write into DS:SI (or CF = 1)

	throw_c DS:msg_usage	; error if CF = 1
	
	mov DS:hd_number, AL	; save the HD number if there's no an error
	
; ========== MBR-sector reading
	lea DI, sector1
	mov DS:packet_dest, DI				; sector storing destination
	mov dword ptr DS:packet_lba, 0		; LBA number of sector
	
	read_sector DS:hd_number, packet, DS:msg_err_r_sector		
	
; ========== looking for an extended partition
	lea SI, sector1
	call find_extended
	
	throw_c DS:msg_err_no_epart			; there's no extended partition
	
	mov EAX, DS:[SI+DSCR_F_BEGIN]		; moving sector's number with EPR1 (LBA) in EAX
	mov dword ptr DS:lba_list, EAX		; saving sector's number with the beginning of extended partition

; ========== looking for logical disks in an extended partition
	mov BP, 0							; address of sector in lba_list (offset)
	mov BX, BOOT_RECORD					; go to Partition table (446 bytes)
	
	; address (destination) for storing sector
	lea DI, sector1							
	mov DS:packet_dest, DI

cs_cycle:	
	; запись в пакет номера сектора для чтения
	mov EAX, dword ptr DS:[lba_list+BP]		; sector's number with EPR
	mov dword ptr DS:packet_lba, EAX		; the first sector's number for reading
	
	read_sector DS:hd_number, packet, DS:msg_err_r_sector	; sector reading
		
	cmp dword ptr DS:[BX+DSCR_F_CODE], 0h	; checking number of LD
	jne short cs_continue					; there's logical disk => go to cs_continue
	
	cmp DS:ld_count, 2h						; checking number of LD
	jge short cs_continue3 					; number of LD >= 2 => success

	throw DS:msg_err_no_2ld					; number of LD < 2 => error

cs_continue:
	add BP, 4								; go to the next cell of array lba_list
	inc DS:ld_count							; we have found logical disk, so increment number of logical disks
	
	cmp byte ptr DS:[BX+DSCR_F2_CODE], 05h	; is descriptor about logical disk (SC = 05)?
	je short cs_continue2					; yes, this descriptor is about logical disk => read it
	
	cmp byte ptr DS:[BX+DSCR_F2_CODE], 0Fh	; is descriptor about logical disk (SC = 0F)?
	je short cs_continue2					; yes, this descriptor is about logical disk => read it
	
	cmp byte ptr DS:ld_count, 2h			; checking number of LD
	jge short cs_continue3					; number of LD >= 2 => success

	throw DS:msg_err_no_2ld					; number of LD < 2 => error
	
cs_continue2:
	mov EAX, DS:lba_list					; EAX <- sector's number with the EPR beginning
	add EAX, dword ptr DS:[BX+DSCR_F2_REL]	; adding offset from this EPR to the logical disk
	
	mov dword ptr DS:[lba_list+BP], EAX		; storing sector's number of follow EPR table
	jmp short cs_cycle						; reading stored sector
	
; ========== selecting a LD for merging
cs_continue3:	
	;convert number of LD into ASCII
	mov BL, byte ptr DS:ld_count
	lea SI, DS:[ld_count_ascii]
	call hex_to_ascii_ld
	
	; print message with number of LD
	mov AH, 9h
	lea DX, msg_ld_count
	int 21h
	
	; input number of LD
	mov AH, 0Ah
	lea DX, input_ld
	int 21h
	
	; converting ASCII logical disk's number into HEX 
	mov DL, byte ptr DS:ld_count			; number of LD in an extended partition
	lea SI, DS:input_ld						; input area
	lea DI, DS:ld_number					; storing logical disk's number
	call ascii_to_hex_ld
	
	throw_c msg_err_wrong_ld
	
; ========== reading both selected sectors
	lea DI, sector1							; destination address for sector reading
	mov DS:packet_dest, DI					
	
	movzx BP, byte ptr DS:ld_number			; the first logical disk for merging
	imul BP, 4h								; AL <- AL * 4 (taking double word from lba_list)
	
	mov EAX, DS:[lba_list+BP-4]
	mov dword ptr DS:packet_lba, EAX		; sector's number in LBA
	
	read_sector DS:hd_number, packet, DS:msg_err_r_sector
	
	lea DI, sector2							; destination address for sector reading
	mov DS:packet_dest, DI				
	
	mov EAX, DS:[lba_list+BP]
	mov dword ptr DS:packet_lba, EAX		; sector's number in LBA
	
	read_sector DS:hd_number, packet, DS:msg_err_r_sector
	
; ========== changing the size of the first logical disk
	lea DI, sector1
	lea SI, sector2
	
	add SI, BOOT_RECORD
	add DI, BOOT_RECORD
	
	mov AL, DS:[SI+DSCR_F_CODE]
	mov AH, DS:[DI+DSCR_F_CODE]
	cmp AL, AH
	
	je short cs_continue4
	
	throw DS:msg_err_diff_code
	
cs_continue4:
	mov EAX, DS:[SI+DSCR_F_SIZE]
	add DS:[DI+DSCR_F_SIZE], EAX
	
	mov EAX, DS:[SI+DSCR_F_BEGIN]
	add DS:[DI+DSCR_F_SIZE], EAX
	
; ========== coopying the CHS-ending coordinates from EPR2 into EPR1
	mov EAX, DS:[SI+DSCR_F_CHS_END-1]
	mov DS:[DI+DSCR_F_CHS_END-1], EAX

; ========== copying the second descriptor
	mov AX, DS
	mov ES, AX
	
	add SI, DSCR_SIZE
	add DI, DSCR_SIZE
	
	mov CX, 4h
	cld
	rep movsd	; 4-byte forwarding 4 times (from DS:[SI] to ES:[DI])
	
; ========== writting updated sector
	lea BX, word ptr sector1
	mov word ptr DS:packet_dest, BX
	
	movzx BP, byte ptr DS:ld_number			; push the first LD for the merging
	imul BP, 4h								; AL <- AL * 4 (looking for in the lba_list)
	mov EAX, DS:[lba_list+BP-4]
	mov dword ptr DS:packet_lba, EAX

	mov AH, 43h
	mov DL, DS:hd_number
	lea SI, packet

	int 13h
	
	throw_c DS:msg_err_w_sector				; throw an error if CF = 1
	
; ========== print a message with result
	lea DX, msg_success
	
cs_end:
	mov AH, 9h
	int 21h
	
; ========== the end of the program
	mov AH, 4Ch
	int 21h
	
; ========== procedure of converting HD number from ASCII to HEX
; ** input: AL (ASCII-code of hard drive)
; ** output: AL (HEX-code of hard drive), flag CF (1 is error)
	ascii_to_hex_hd proc
	
	sub AL, 30h			
	js short athh_error	; AL < 0
	cmp AL, 3			
	ja short athh_error	; AL > 3

	add AL, 80h
	
	clc					; clear flag if there's no errors
	jmp short athh_end	; return
	
athh_error:
	stc
athh_end:
	ret
	ascii_to_hex_hd endp
	
; ========== procedure of looking for an extended partition in MBR-sector
; ** input: SI (address of sector bytes)
; ** output: SI (address of descriptor about extended partition), flag CF (1 is error)
	find_extended proc

	add SI, BOOT_RECORD						; go to Partition Table (446)
	
	mov CX, DSCR_COUNT						; count of descriptors in the table
	
fex_cycle:
	cmp byte ptr DS:[SI+DSCR_F_CODE], 05h	; checking if it's a extended partition (1)
	je short fex_success
	
	cmp byte ptr DS:[SI+DSCR_F_CODE], 0Fh	; checking if it's a extended partition (2)
	je short fex_success
	
	add SI, DSCR_SIZE						; go to the next descriptor in Partition Table
	loop short fex_cycle
	
	stc
	jmp short fex_end
	
fex_success:
	clc										; clear flag if there's no errors
fex_end:
	ret
	find_extended endp

; ========== procedure of converting LD number from ASCII to HEX
; ** input: SI (address of input area), DI (address of byte with logical disk ID), DL (number of logical disks)
; ** output: LD number in DS:DI, flag CF (1 is error)
	ascii_to_hex_ld proc
	
	mov AL, 1
	
	cmp byte ptr DS:[SI+3], 0Dh
	je short athl_digit2
	
	mov BL, DS:[SI+3]
	sub BL, 30h
	mov DS:[DI], BL
	
	mov AX, 10
	
athl_digit2:
	sub byte ptr DS:[SI+2], 30h
	mul byte ptr DS:[SI+2]			; multyply by AL
	add DS:[DI], AL

	cmp byte ptr DS:[DI], 0h
	jle short athl_error

	cmp byte ptr DS:[DI], DL
	jge short athl_error
	
	clc								; clear flag if there's no errors
	jmp short athl_end				; return
	
athl_error:
	stc
athl_end:
	ret
	ascii_to_hex_ld endp
	
; ========== procedure of converting number of HD from HEX to ASCII
; ** input: BL (number of LD)
; ** output: DS:SI (address of ASCII string (result))
	hex_to_ascii_ld proc
	
	mov BH, 10	; divider
	mov AL, BL	; copying the number in AL

htal_cycle:
	xor AH, AH	; clear AH
	div BH
	add AH, 30h
	mov DS:SI, AH
	dec SI
	
	cmp AL, 10
	jge short htal_cycle
	
	add AL, 30h
	mov DS:[SI], AL
	
	ret
	hex_to_ascii_ld endp

cseg ends

end start