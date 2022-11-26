	cpu	186
	org	0xe000

;;;; PREPARE STACK AND FILL INTERRUPT VECTOR TABLE ;;;;

	cli

	xor	di, di
	mov	es, di
	xor	ax, ax
	mov	cx, 32768
	rep	stosw

	xor	di, di
	mov	es, di
	mov	ax, cs
	mov	cx, 0xff
	rep	stosw

	mov	sp, 0x30
	mov	ss, sp
	mov	sp, 0xfe

;;;; FINNISH FILLING UP THE  INTERRUPT VECTOR TABLE ;;;;
	
	xor	di, di
	xor	si, si
	mov	es, di
	mov	ds, si
	mov	word [es:0x08*4], INT08 ; TIMER HANDLER
	mov     word [es:0x09*4], INT09 ; KEYBOARD HANDLER
	mov	word [es:0x12*4], INT12 ; MEMORY SERVICE
	mov	word [es:0x13*4], INT13 ; DISK SERVICE
	mov	word [es:0x16*4], INT16 ; KEYBOARD SERVICE
	mov	word [es:0x1a*4], INT1A ; TIME SERVICE

;;;; INITIALIZE 8259 INTERRUPT CONTROLLER ;;;;

	mov	al, 0x11
	out	0x20, al
	mov	al, 8
	out	0x21, al
	xor	al, al
	out	0x21, al
	mov	al, 3
	out	0x21, al

;;;; INITIALIZE 8253 TIMER ;;;;

	mov	al, 0x36
	out	0x43, al
	mov	al, 0
	out	0x40, al
	out	0x40, al
	sti

;;;; INITIALIZE VGA ADAPTER ;;;;

	call	0xc000:3

;;;; INITIALIZE BIOS DATA AREA ;;;;

	mov	di, 0x40
	mov	es, di
	mov	word [es:0x1a], 0x1e
	mov	word [es:0x1c], 0x1e

;;;; LOAD BOOT SECTOR ;;;;

	mov	al, 0x01
	mov	dx, 0x302
	out	dx, al
	mov	al, 0xef
	mov	dx, 0x30e
	out	dx, al
cf8:
	in	al, dx
	and	al, 0x80
	jnz	cf8

	xor	ax, ax
	mov	es, ax
	mov	ds, ax
	mov	ax, 0x0201
	mov	bx, 0x7c00
	mov	cx, 1
	mov	dx, 0x0080
	int	0x13
	jmp	0:0x7c00

INT08:
	push	ds
	push	ax
	mov	ax, 0x40
	mov	ds, ax
	clc
	adc	word [ds:0x6c], 1
	adc	word [ds:0x6e], 0
	int	0x1c
	mov	al, 0x20
	out	0x20, al
	pop	ax
	pop	ds
	iret

INT09:
	mov	al, 0x20
	out	0x20, al
	iret

;;;; BIOS CONVENTIONAL MEMORY SERVICE ;;;;

INT12:
	mov	ax, 512
	iret
	
;;;; BIOS DISK SERVICE ;;;;

INT13:
	cmp	ah, 2
	je	INT13_read_disk
	cmp	ah, 8
	je	INT13_disk_type
	iret
INT13_read_disk:
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	
	mov     di, bx
	mov     si, ax

	mov     bx, cx
	and     bx, 63

	shr     cl, 6
	xchg    cl, ch

	xchg    dl, dh
	and     dx, 0x0f

	mov     al, dl
	or      al, 0xa0
	mov     dx, 0x30c
	out     dx, al

	mov     ax, si
	mov     dx, 0x304
	out     dx, al

	mov     al, bl
	mov     dx, 0x306
	out     dx, al

	mov     al, cl
	mov     dx, 0x308
	out     dx, al

	mov     al, ch
	mov     dx, 0x30a
	out     dx, al

	mov     al, 0x20
	mov     dx, 0x30e
	out     dx, al

	mov     bx, si
INT13_keep_reading:
	mov     cx, 256
	mov     dx, 0x30e
INT13_wait_ready:
	in      al, dx
	test    al, 8
	jz      INT13_wait_ready
INT13_read_word:
	mov     dx, 0x300
	in      ax, dx
	stosw
	loop    INT13_read_word
	dec     bl
	jnz     INT13_keep_reading
	
	pop	si
	pop     di
	pop     dx
	pop     cx
	pop	bx
	pop	ax
	iret

INT13_disk_type:
	mov     cx, 0xff3f
	mov     dx, 0x0f01
	iret

;;;; BIOS KEYBOARD SERVICE ;;;;

INT16:
	xor	ax, ax
	iret

;;;; BIOS CLOCK COUNTER SERVICE ;;;;

INT1A:
	push	ax
	push	ds
	mov	ax, 0x40
	mov	ds, ax
	mov	cx, [ds:0x6e]
	mov	dx, [ds:0x6c]
	pop	ds
	pop	ax
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	times	0x1000-($-$$) nop
	iret
	times	0x1ff0-($-$$) nop
	jmp     0xf000:0xe000
	times   11 nop