; Scan converts an edge from (X1,Y1) to (X2,Y2), not including the
; point at (X2,Y2). If SkipFirst == 1, the point at (X1,Y1) isn't
; drawn; if SkipFirst == 0, it is. For each scan line, the pixel
; closest to the scanned edge without being to the left of the scanned
; edge is chosen. Uses an all-integer approach for speed & precision.
; C near-callable as:
;    void ScanEdge(int X1, int Y1, int X2, int Y2, int SetXStart,
;     int SkipFirst, struct HLine **EdgePointPtr);
; Edges must not go bottom to top; that is, Y1 must be <= Y2.
; Updates the pointer pointed to by EdgePointPtr to point to the next
;  free entry in the array of HLine structures.
;
; Link with L21-1.C, L21-3.C, and L22-3.ASM in Small model.
; Tested with TASM 4.0 and Borland C++ 4.02 by Jim Mischel 12/16/94.
;
HLine   struc
XStart  dw	?   	;X coordinate of leftmost pixel in scan line
XEnd   	dw	?	;X coordinate of rightmost pixel in scan line
HLine   ends

Parms   struc
        dw   2 dup(?) 	;return address & pushed BP
X1      dw   	?   	;X start coord of edge
Y1      dw   	?   	;Y start coord of edge
X2      dw   	?   	;X end coord of edge
Y2      dw   	?   	;Y end coord of edge
SetXStart   dw	?  	;1 to set the XStart field of each
            			; HLine struc, 0 to set XEnd
SkipFirst   dw	?   	;1 to skip scanning the first point
            			; of the edge, 0 to scan first point
EdgePointPtr dw	?   	;pointer to a pointer to the array of
            			; HLine structures in which to store
            			; the scanned X coordinates
Parms   ends

;Offsets from BP in stack frame of local variables.
AdvanceAmt      equ     -2
Height          equ     -4
LOCAL_SIZE      equ     4   ;total size of local variables

	.model small
	.code
   	public _ScanEdge
   	align  2
_ScanEdge   	proc
   	push  	bp		;preserve caller's stack frame
   	mov   	bp,sp      	;point to our stack frame
   	sub   	sp,LOCAL_SIZE   	;allocate space for local variables
   	push  	si         	;preserve caller's register variables
   	push  	di
   	mov   	di,[bp+EdgePointPtr]
   	mov   	di,[di]    	;point to the HLine array
   	cmp   	[bp+SetXStart],1 	;set the XStart field of each HLine
            				; struc?
   	jz   	HLinePtrSet 	;yes, DI points to the first XStart
   	add   	di,XEnd    	;no, point to the XEnd field of the
            				; first HLine struc
HLinePtrSet:
   	mov   	bx,[bp+Y2]
   	sub   	bx,[bp+Y1]   	;edge height
   	jle   	ToScanEdgeExit  	;guard against 0-length & horz edges
   	mov   	[bp+Height],bx  	;Height = Y2 - Y1
   	sub   	cx,cx      	;assume ErrorTerm starts at 0 (true if
                         	; we're moving right as we draw)
   	mov   	dx,1      	;assume AdvanceAmt = 1 (move right)
   	mov   	ax,[bp+X2]
   	sub   	ax,[bp+X1]      	;DeltaX = X2 - X1
   	jz    	IsVertical	;it's a vertical edge--special case it
   	jns   	SetAdvanceAmt   	;DeltaX >= 0
   	mov   	cx,1      	;DeltaX < 0 (move left as we draw)
   	sub   	cx,bx      	;ErrorTerm = -Height + 1
   	neg   	dx      		;AdvanceAmt = -1 (move left)
   	neg   	ax       		;Width = abs(DeltaX)
SetAdvanceAmt:
   	mov   	[bp+AdvanceAmt],dx
; Figure out whether the edge is diagonal, X-major (more horizontal),
; or Y-major (more vertical) and handle appropriately.
   	cmp   	ax,bx      	;if Width==Height, it's a diagonal edge
   	jz   	IsDiagonal   	;it's a diagonal edge--special case
   	jb   	YMajor      	;it's a Y-major (more vertical) edge
            				;it's an X-major (more horz) edge
   	sub  	dx,dx 		;prepare DX:AX (Width) for division
   	div    	bx      		;Width/Height
            				;DX = error term advance per scan line
   	mov   	si,ax      	;SI = minimum # of pixels to advance X
            				; on each scan line
   	test 	[bp+AdvanceAmt],8000h ;move left or right?
   	jz	XMajorAdvanceAmtSet ;right, already set
   	neg  	si            	;left, negate the distance to advance
					; on each scan line
XMajorAdvanceAmtSet:            	;
   	mov	ax,[bp+X1]   	;starting X coordinate
        cmp 	[bp+SkipFirst],1 	;skip the first point?
        jz	XMajorSkipEntry  	;yes
XMajorLoop:
   	mov	[di],ax      	;store the current X value
   	add	di,size HLine   	;point to the next HLine struc
XMajorSkipEntry:
   	add   	ax,si      	;set X for the next scan line
   	add   	cx,dx      	;advance error term
   	jle   	XMajorNoAdvance 	;not time for X coord to advance one
            				; extra
   	add   	ax,[bp+AdvanceAmt];advance X coord one extra
        sub 	cx,[bp+Height]  	;adjust error term back
XMajorNoAdvance:
        dec	bx      		;count off this scan line
        jnz	XMajorLoop
   	jmp	ScanEdgeDone
   	align 	2
ToScanEdgeExit:
   	jmp 	ScanEdgeExit
        align	2
IsVertical:
   	mov	ax,[bp+X1]   	;starting (and only) X coordinate
   	sub	bx,[bp+SkipFirst]	;loop count = Height - SkipFirst
        jz   	ScanEdgeExit 	;no scan lines left after skipping 1st
VerticalLoop:
   	mov	[di],ax      	;store the current X value
   	add	di,size HLine   	;point to the next HLine struc
   	dec 	bx      		;count off this scan line
   	jnz 	VerticalLoop
   	jmp 	ScanEdgeDone
        align 	2
IsDiagonal:
   	mov 	ax,[bp+X1]   	;starting X coordinate
        cmp  	[bp+SkipFirst],1 	;skip the first point?
   	jz	DiagonalSkipEntry	;yes
DiagonalLoop:   
   	mov 	[di],ax      	;store the current X value
   	add 	di,size HLine   	;point to the next HLine struc
DiagonalSkipEntry:
   	add 	ax,dx      	;advance the X coordinate
   	dec	bx      		;count off this scan line
   	jnz	DiagonalLoop
   	jmp	ScanEdgeDone
        align 	2
YMajor:
   	push	bp      		;preserve stack frame pointer
   	mov	si,[bp+X1]   	;starting X coordinate
   	cmp	[bp+SkipFirst],1	;skip the first point?
   	mov	bp,bx      	;put Height in BP for error term calcs
   	jz	YMajorSkipEntry	;yes, skip the first point
YMajorLoop:
   	mov	[di],si      	;store the current X value
   	add	di,size HLine   	;point to the next HLine struc
YMajorSkipEntry:
   	add 	cx,ax      	;advance the error term
   	jle	YMajorNoAdvance 	;not time for X coord to advance
   	add 	si,dx      	;advance the X coordinate
   	sub  	cx,bp      	;adjust error term back
YMajorNoAdvance:
   	dec	bx		;count off this scan line
   	jnz	YMajorLoop
   	pop	bp      		;restore stack frame pointer
ScanEdgeDone:
   	cmp	[bp+SetXStart],1	;were we working with XStart field?
   	jz	UpdateHLinePtr  	;yes, DI points to the next XStart
   	sub   	di,XEnd      	;no, point back to the XStart field
UpdateHLinePtr:
   	mov   	bx,[bp+EdgePointPtr] ;point to pointer to HLine array
   	mov   	[bx],di      	;update caller's HLine array pointer
ScanEdgeExit:
   	pop   	di      		;restore caller's register variables
   	pop   	si
   	mov	sp,bp           	;deallocate local variables
   	pop  	bp      		;restore caller's stack frame
   	ret
_ScanEdge   	endp
   	end

