;
; *** Listing 28.1 ***
;
; Program to demonstrate bit-plane animation. Performs
; flicker-free animation with image transparency and
; image precedence across four distinct planes, with
; 13 32x32 images kept in motion at once.
;
; Tested with TASM 4.0 by Jim Mischel 12/16/94.
;
; Set to higher values to slow down on faster computers.
; 0 is fine for a PC. 500 is a reasonable setting for an AT.
; Slowing animation further allows a good look at
; transparency and the lack of flicker and color effects
; when images cross.
;
SLOWDOWN	equ	10000
;
; Plane selects for the four colors we're using.
;
RED	equ	01h
GREEN	equ	02h
BLUE	equ	04h
WHITE	equ	08h
;
VGA_SEGMENT	equ	0a000h	;mode 10h display memory
				; segment
SC_INDEX		equ	3c4h	;Sequence Controller Index
				; register
MAP_MASK		equ	2	;Map Mask register index in
				; Sequence Controller
SCREEN_WIDTH	equ	80	;# of bytes across screen
SCREEN_HEIGHT	equ	350	;# of scan lines on screen
WORD_OUTS_OK	equ	1	;set to 0 to assemble for
				; computers that can't
				; handle word outs to
				; indexed VGA regs
;
stack	segment para stack 'STACK'
	db	512 dup (?)
stack	ends
;
; Complete info about one object that we're animating.
;
ObjectStructure	struc
Delay		dw	?	;used to delay for n passes
				; throught the loop to
				; control animation speed
BaseDelay	dw	?	;reset value for Delay
Image		dw	?	;pointer to drawing info
				; for object
XCoord		dw	?	;object X location in pixels
XInc		dw	?	;# of pixels to increment
				; location by in the X
				; direction on each move
XLeftLimit	dw	?	;left limit of X motion
XRightLimit	dw	?	;right limit of X motion
YCoord		dw	?	;object Y location in pixels
YInc		dw	?	;# of pixels to increment
				; location by in the Y
				; direction on each move
YTopLimit	dw	?	;top limit of Y motion
YBottomLimit	dw	?	;bottom limit of Y motion
PlaneSelect	db	?	;mask to select plane to
				; which object is drawn
		db	?	;to make an even # of words
				; long, for better 286
				; performance (keeps the
				; following structure
				; word-aligned)
ObjectStructure	ends
;
Data	segment	word 'DATA'
;
; Palette settings to give plane 0 precedence, followed by
; planes 1, 2, and 3. Plane 3 has the lowest precedence (is
; obscured by any other plane), while plane 0 has the
; highest precedence (displays in front of any other plane).
;
Colors	db	000h ;background color=black
	db	03ch ;plane 0 only=red
	db	03ah ;plane 1 only=green
	db	03ch ;planes 0&1=red (plane 0 priority)
	db	039h ;plane 2 only=blue
	db	03ch ;planes 0&2=red (plane 0 priority)
	db	03ah ;planes 1&2=green (plane 1 priority)
	db	03ch ;planes 0&1&2=red (plane 0 priority)
	db	03fh ;plane 3 only=white
	db	03ch ;planes 0&3=red (plane 0 priority)
	db	03ah ;planes 1&3=green (plane 1 priority)
	db	03ch ;planes 0&1&3=red (plane 0 priority)
	db	039h ;planes 2&3=blue (plane 2 priority)
	db	03ch ;planes 0&2&3=red (plane 0 priority)
	db	03ah ;planes 1&2&3=green (plane 1 priority)
	db	03ch ;planes 0&1&2&3=red (plane 0 priority)
	db	000h ;border color=black
;
; Image of a hollow square.
; There's an 8-pixel-wide blank border around all edges
; so that the image erases the old version of itself as
; it's moved and redrawn.
;
Square	label	byte
	dw	48,6	;height in pixels, width in bytes
	rept	8
	db	0,0,0,0,0,0	;top blank border
	endm
	.radix	2
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,00000000,00000000,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	db	0,11111111,11111111,11111111,11111111,0
	.radix	10
	rept	8
	db	0,0,0,0,0,0	;bottom blank border
	endm
;
; Image of a hollow diamond with a smaller diamond in the
; middle.
; There's an 8-pixel-wide blank border around all edges
; so that the image erases the old version of itself as
; it's moved and redrawn.
;
Diamond	label	byte
	dw	48,6	;height in pixels, width in bytes
	rept	8
	db	0,0,0,0,0,0	;top blank border
	endm
	.radix	2
	db	0,00000000,00000001,10000000,00000000,0
	db	0,00000000,00000011,11000000,00000000,0
	db	0,00000000,00000111,11100000,00000000,0
	db	0,00000000,00001111,11110000,00000000,0
	db	0,00000000,00011111,11111000,00000000,0
	db	0,00000000,00111110,01111100,00000000,0
	db	0,00000000,01111100,00111110,00000000,0
	db	0,00000000,11111000,00011111,00000000,0
	db	0,00000001,11110000,00001111,10000000,0
	db	0,00000011,11100000,00000111,11000000,0
	db	0,00000111,11000000,00000011,11100000,0
	db	0,00001111,10000001,10000001,11110000,0
	db	0,00011111,00000011,11000000,11111000,0
	db	0,00111110,00000111,11100000,01111100,0
	db	0,01111100,00001111,11110000,00111110,0
	db	0,11111000,00011111,11111000,00011111,0
	db	0,11111000,00011111,11111000,00011111,0
	db	0,01111100,00001111,11110000,00111110,0
	db	0,00111110,00000111,11100000,01111100,0
	db	0,00011111,00000011,11000000,11111000,0
	db	0,00001111,10000001,10000001,11110000,0
	db	0,00000111,11000000,00000011,11100000,0
	db	0,00000011,11100000,00000111,11000000,0
	db	0,00000001,11110000,00001111,10000000,0
	db	0,00000000,11111000,00011111,00000000,0
	db	0,00000000,01111100,00111110,00000000,0
	db	0,00000000,00111110,01111100,00000000,0
	db	0,00000000,00011111,11111000,00000000,0
	db	0,00000000,00001111,11110000,00000000,0
	db	0,00000000,00000111,11100000,00000000,0
	db	0,00000000,00000011,11000000,00000000,0
	db	0,00000000,00000001,10000000,00000000,0
	.radix	10
	rept	8
	db	0,0,0,0,0,0	;bottom blank border
	endm
;
; List of objects to animate.
;
	even	;word-align for better 286 performance
;
ObjectList	label	ObjectStructure
 ObjectStructure <1,21,Diamond,88,8,80,512,16,0,0,350,RED>
 ObjectStructure <1,15,Square,296,8,112,480,144,0,0,350,RED>
 ObjectStructure <1,23,Diamond,88,8,80,512,256,0,0,350,RED>
 ObjectStructure <1,13,Square,120,0,0,640,144,4,0,280,BLUE>
 ObjectStructure <1,11,Diamond,208,0,0,640,144,4,0,280,BLUE>
 ObjectStructure <1,8,Square,296,0,0,640,144,4,0,288,BLUE>
 ObjectStructure <1,9,Diamond,384,0,0,640,144,4,0,288,BLUE>
 ObjectStructure <1,14,Square,472,0,0,640,144,4,0,280,BLUE>
 ObjectStructure <1,8,Diamond,200,8,0,576,48,6,0,280,GREEN>
 ObjectStructure <1,8,Square,248,8,0,576,96,6,0,280,GREEN>
 ObjectStructure <1,8,Diamond,296,8,0,576,144,6,0,280,GREEN>
 ObjectStructure <1,8,Square,344,8,0,576,192,6,0,280,GREEN>
 ObjectStructure <1,8,Diamond,392,8,0,576,240,6,0,280,GREEN>
ObjectListEnd	label	ObjectStructure
;
Data	ends
;
; Macro to output a word value to a port.
;
OUT_WORD	macro
if WORD_OUTS_OK
	out	dx,ax
else
	out	dx,al
	inc	dx
	xchg	ah,al
	out	dx,al
	dec	dx
	xchg	ah,al
endif
	endm
;
; Macro to output a constant value to an indexed VGA
; register.
;
CONSTANT_TO_INDEXED_REGISTER	macro ADDRESS, INDEX, VALUE
	mov	dx,ADDRESS
	mov	ax,(VALUE shl 8) + INDEX
	OUT_WORD
	endm
;
Code	segment
	assume	cs:Code, ds:Data
Start	proc	near
	cld
	mov	ax,Data
	mov	ds,ax
;
; Set 640x350 16-color mode.
;
	mov	ax,0010h	;AH=0 means select mode
				;AL=10h means select
				; mode 10h
	int	10h		;BIOS video interrupt
;
; Set the palette up to provide bit-plane precedence. If
; planes 0 & 1 overlap, the plane 0 color will be shown;
; if planes 1 & 2 overlap, the plane 1 color will be
; shown; and so on.
;
	mov	ax,(10h shl 8) + 2	;AH = 10h means
					; set palette
					; registers fn
					;AL = 2 means set
					; all palette
					; registers
	push	ds			;ES:DX points to
	pop	es			; the palette
	mov	dx,offset Colors	; settings
	int	10h			;call the BIOS to
					; set the palette
;
; Draw the static backdrop in plane 3. All the moving images
; will appear to be in front of this backdrop, since plane 3
; has the lowest precedence the way the palette is set up.
;
	CONSTANT_TO_INDEXED_REGISTER SC_INDEX, MAP_MASK, 08h
				;allow data to go to
				; plane 3 only
;
; Point ES to display memory for the rest of the program.
;
	mov	ax,VGA_SEGMENT
	mov	es,ax
;
	sub	di,di
	mov	bp,SCREEN_HEIGHT/16	;fill in the screen
					; 16 lines at a time
BackdropBlockLoop:
	call	DrawGridCross		;draw a cross piece
	call	DrawGridVert		;draw the rest of a
					; 15-high block
	dec	bp
	jnz	BackdropBlockLoop
	call	DrawGridCross		;bottom line of grid
;
; Start animating!
;
AnimationLoop:
	mov	bx,offset ObjectList	;point to the first
					; object in the list
;
; For each object, see if it's time to move and draw that
; object.
;
ObjectLoop:
;
; See if it's time to move this object.
;
	dec	[bx+Delay]	;count down delay
	jnz	DoNextObject	;still delaying-don't move
	mov	ax,[bx+BaseDelay]
	mov	[bx+Delay],ax	;reset delay for next time
;
; Select the plane that this object will be drawn in.
;
	mov	dx,SC_INDEX
	mov	ah,[bx+PlaneSelect]
	mov	al,MAP_MASK
	OUT_WORD
;
; Advance the X coordinate, reversing direction if either
; of the X margins has been reached.
;
	mov	cx,[bx+XCoord]		;current X location
	cmp	cx,[bx+XLeftLimit]	;at left limit?
	ja	CheckXRightLimit	;no
	neg	[bx+XInc]		;yes-reverse
CheckXRightLimit:
	cmp	cx,[bx+XRightLimit]	;at right limit?
	jb	SetNewX			;no
	neg	[bx+XInc]		;yes-reverse
SetNewX:
	add	cx,[bx+XInc]		;move the X coord
	mov	[bx+XCoord],cx		; & save it
;
; Advance the Y coordinate, reversing direction if either
; of the Y margins has been reached.
;
	mov	dx,[bx+YCoord]	    	;current Y location
	cmp	dx,[bx+YTopLimit]   	;at top limit?
	ja	CheckYBottomLimit   	;no
	neg	[bx+YInc]	    	;yes-reverse
CheckYBottomLimit:
	cmp	dx,[bx+YBottomLimit]	;at bottom limit?
	jb	SetNewY		    	;no
	neg	[bx+YInc]	    	;yes-reverse
SetNewY:
	add	dx,[bx+YInc]	    	;move the Y coord
	mov	[bx+YCoord],dx	    	; & save it
;
; Draw at the new location. Because of the plane select
; above, only one plane will be affected.
;
	mov	si,[bx+Image]		;point to the
					; object's image
					; info
	call	DrawObject
;
; Point to the next object in the list until we run out of
; objects.
;
DoNextObject:
	add	bx,size ObjectStructure
	cmp	bx,offset ObjectListEnd
	jb	ObjectLoop
;
; Delay as specified to slow things down.
;
if SLOWDOWN
	mov	cx,SLOWDOWN
DelayLoop:
	loop	DelayLoop
endif
;
; If a key's been pressed, we're done, otherwise animate
; again.
;
CheckKey:
	mov	ah,1
	int	16h		;is a key waiting?
	jz	AnimationLoop	;no
	sub	ah,ah
	int	16h		;yes-clear the key & done
;
; Back to text mode.
;
	mov	ax,0003h	;AL=03h means select
				; mode 03h
	int	10h
;
; Back to DOS.
;
	mov	ah,4ch		;DOS terminate function
	int	21h		;done
;
Start	endp
;
; Draws a single grid cross-element at the display memory
; location pointed to by ES:DI. 1 horizontal line is drawn
; across the screen.
;
; Input: ES:DI points to the address at which to draw
;
; Output: ES:DI points to the address following the
;		line drawn
;
; Registers altered: AX, CX, DI
;
DrawGridCross	proc	near
	mov	ax,0ffffh	;draw a solid line
	mov	cx,SCREEN_WIDTH/2-1
	rep	stosw		;draw all but the rightmost
				; edge
	mov	ax,0080h
	stosw			;draw the right edge of the
				; grid
	ret
DrawGridCross	endp
;
; Draws the non-cross part of the grid at the display memory
; location pointed to by ES:DI. 15 scan lines are filled.
;
; Input: ES:DI points to the address at which to draw
;
; Output: ES:DI points to the address following the
;		part of the grid drawn
;
; Registers altered: AX, CX, DX, DI
;
DrawGridVert	proc	near
	mov	ax,0080h	;pattern for a vertical line
	mov	dx,15		;draw 15 scan lines (all of
				; a grid block except the
				; solid cross line)
BackdropRowLoop:
	mov	cx,SCREEN_WIDTH/2
	rep	stosw		;draw this scan line's bit
				; of all the vertical lines
				; on the screen
	dec	dx
	jnz	BackdropRowLoop
	ret
DrawGridVert	endp
;
; Draw the specified image at the specified location.
; Images are drawn on byte boundaries horizontally, pixel
; boundaries vertically.
; The Map Mask register must already have been set to enable
; access to the desired plane.
;
; Input:
;	CX - X coordinate of upper left corner
;	DX - Y coordinate of upper left corner
;	DS:SI - pointer to draw info for image
;	ES - display memory segment
;
; Output: none
;
; Registers altered: AX, CX, DX, SI, DI, BP
;
DrawObject	proc	near
	mov	ax,SCREEN_WIDTH
	mul	dx	;calculate the start offset in
			; display memory of the row the
			; image will be drawn at
	shr	cx,1
	shr	cx,1
	shr	cx,1	;divide the X coordinate in pixels
			; by 8 to get the X coordinate in
			; bytes
	add	ax,cx	;destination offset in display
			; memory for the image
	mov	di,ax	;point ES:DI to the address to
			; which the image will be copied
			; in display memory
	lodsw
	mov	dx,ax	;# of lines in the image
	lodsw		;# of bytes across the image
	mov	bp,SCREEN_WIDTH
	sub	bp,ax	;# of bytes to add to the display
			; memory offset after copying a line
			; of the image to display memory in
			; order to point to the address
			; where the next line of the image
			; will go in display memory
DrawLoop:
	mov	cx,ax	;width of the image
	rep	movsb	;copy the next line of the image
			; into display memory
	add	di,bp	;point to the address at which the
			; next line will go in display
			; memory
	dec	dx	;count down the lines of the image
	jnz	DrawLoop
	ret
DrawObject	endp
;
Code	ends
	end	Start

