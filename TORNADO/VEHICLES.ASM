;****************************************************************************
;*
;* VEHICLES.ASM
;*
;* Ground vehicles control (trucks / trains) etc.
;*
;* 23.06.1992 - KJB
;* 10.05.1993 - KJB - CheckBridge added.
;*
;* Trucks / Trains
;* ---------------
;*
;* Trucks and trains share the same control routines. The only difference is
;* that road bridges have different inclines to railway bridges.
;*
;* The routes which these vehicles follow are generated by the mission planner.
;*
;* Routes comprise a list of "route nodes". Route nodes specify turning points,
;* stopping points, bridge inclines etc.
;*
;* Each convoy may have an initial delay period. This is so that transport
;* movement can be co-ordinated. The delay attribute should not be set for
;* the initial delay (if the route "links back" then the vehicles would
;* always stop at the starting point which might not be desirable).
;*
;* If the route starts with an event then the initial delay period is ignored.
;*
;* Convoys can be made to stop after passing a route node and wait for a fixed
;* delay period before continuing. The route leg speed should not be set to
;* zero as the convoy will stop automatically. If the speed is set to zero
;* then the convoy cannot continue!
;*
;* Convoys can be made to stop after passing a route node and wait for an
;* "event". An event is triggered by another drone reaching a predetermined
;* point on its route. For example; a truck convoy could wait until a train
;* arrives before setting off, or a helicopter could be waiting for a truck
;* etc.
;*
;* A drone's event is simply the number of waypoints / route nodes which it
;* has satisfied.
;*
;* All convoys must start in a straight line and all vehicles in the convoy
;* must start somewhere after the first route node and before the second,
;* pointing in the correct direction. Normally, the last vehicle in the convoy
;* would start exactly on the first route node.
;*
;* Vehicles cannot start on bridges.
;*
;* If a route links back then the vehicles event counter will be reset when
;* the link occurs.
;*
;* It is possible to confuse the system so take care when creating routes!
;*
;*
;*
;* Initialization
;* --------------
;*
;*    Convoy 
;*    ------
;*
;*       General Format
;*       --------------
;*
;*	    CONVOY <>		<- global data for each convoy
;*
;*	    MOBILE <>		   )
;*          VIEWPOINT <>	<- ) compound data structure for each drone
;*          VEHICLE <>		   ) 
;*
;*	    MOBILE <>		<- drone object data
;*          VIEWPOINT <>	<- drone position and attitude data
;*          VEHICLE <>		<- drone control data
;*
;*	      ..  ..
;*
;*	    MOBILE <>		(repeat up to NUM_TRUCKS / NUM_TRAINS)
;*          VIEWPOINT <>
;*          VEHICLE <>   
;*
;*    	 Initialization Details
;*       ----------------------
;*
;*          ? indicates "initialized at run time" but use default values
;*          given in appropriate include files.
;*
;*          Refer to include files for data sizes, value ranges etc.
;*
;*          CONVOY (see MAINDATA.INC)
;*	    ------
;*             CNVY_ACTIVE ....... convoy active / inactive
;*             CNVY_DELAY ........ initial delay
;*             CNVY_SPEED ........ ?
;*             CNVY_AIM_SPEED .... ?
;*	       CNVY_DRONE ........ ?
;*             CNVY_EVENT ........ ?
;*
;*          MOBILE (see VISDATA.INC)
;*          ------
;*             MOB_NUM ........... 3D model number
;*             MOB_TYPE .......... ?
;*             MOB_ANIM .......... animation
;*             MOB_LINK_PTR ...... ?
;*
;*          VIEWPOINT (see VISDATA.INC)
;*          ---------
;*             VP_XSEC ........... ) 
;*             VP_YSEC ........... ) Drone must be positioned at its starting
;*             VP_XFT ............ ) point (somewhere between first and second
;*             VP_YFT ............ ) route node) pointing in the correct
;*             VP_ZFT ............ ) direction.
;*             VP_HDG ............ )
;*             VP_PITCH .......... ?
;*             VP_ROLL ........... ?
;*
;*          VEHICLE (see MAINDATA.INC)
;*          -------
;*	       VEH_DRONE ......... truck / train
;*             VEH_SIDE .......... allied / enemy / dead
;*             VEH_EVENT ......... ?
;*             VEH_NODE_PTR ...... ?
;*             VEH_DIST .......... distance to next (second) route node
;*             VEH_DIST_FINE ..... ?
;*             VEH_XFINE ......... ?
;*             VEH_YFINE ......... ?
;*             VEH_ZFINE ......... ?
;*
;*    Convoy Route
;*    ------------
;*
;*       General Format
;*       --------------
;*
;*	    ROUTE_NODE <>	<- route node data
;*	    ROUTE_NODE <>
;*	    ROUTE_NODE <>
;*           ..    ..
;*	    ROUTE_NODE <>
;*	    ROUTE_NODE <>	(repeat up to NUM_ROUTE_NODES)
;*
;*    	 Initialization Details
;*       ----------------------
;*
;*	    ROUTE_NODE
;*          ----------
;*             ROUTE_XSEC ........ )
;*             ROUTE_YSEC ........ ) node position (must be on active map)
;*             ROUTE_XFT ......... )
;*             ROUTE_YFT ......... )
;*             ROUTE_DIST ........ distance to next node
;*             ROUTE_DIR ......... direction of next node
;*             ROUTE_ATTR ........ attributes (see below)
;*             ROUTE_SPEED ....... speed
;*             ROUTE_DRONE ....... drone to trigger event
;*             ROUTE_EVENT ....... event number
;*
;*          Attributes
;*          ----------
;*             RN_END ............ end of route (terminate here)
;*                                    ROUTE_DIST = 65,535
;*				      ROUTE_DIR must still be valid
;*				      ROUTE_SPEED = 0
;*	       RN_LINK ........... link back to first node (continuous loop)
;*             RN_EVENT .......... stop here and wait for event
;*			   	      ROUTE_SPEED do not set to zero
;*                                    ROUTE_DRONE = drone number
;*                                    ROUTE_EVENT = event number
;*             RN_DELAY .......... stop here and wait for delay period 
;*			   	      ROUTE_SPEED do not set to zero
;*             RN_UPSLOPE ........ start bridge ascent here
;*             RN_DNSLOPE ........ start bridge descent here
;*
;****************************************************************************

		OPTION	M510		;<<<<< MASM v5.10 <<<<<

		PUBLIC	InitConvoys
		PUBLIC	UpdateConvoys

		EXTRN	CreateMobile:FAR
		EXTRN	DeleteMobile:FAR
		EXTRN	UpdateMobile:FAR

		EXTRN	DronePtrs:WORD
		EXTRN	ATruckConvoy1:WORD
		EXTRN	ATruckConvoy2:WORD
		EXTRN	ETruckConvoy1:WORD
		EXTRN	ETruckConvoy2:WORD
		EXTRN	ATrain1:WORD
		EXTRN	ATrain2:WORD
		EXTRN	ETrain1:WORD
		EXTRN	ETrain2:WORD
		EXTRN	ATruck1Route:WORD
		EXTRN	ATruck2Route:WORD
		EXTRN	ETruck1Route:WORD
		EXTRN	ETruck2Route:WORD
		EXTRN	ATrain1Route:WORD
		EXTRN	ATrain2Route:WORD
		EXTRN	ETrain1Route:WORD
		EXTRN	ETrain2Route:WORD
		EXTRN	SinTable:WORD
		EXTRN	CosTable:WORD
		EXTRN	DeltaTime:WORD
		EXTRN	LastFrame:WORD
		EXTRN	SectorTable:WORD

		EXTRN	Night:BYTE
		EXTRN	Fog:BYTE
		EXTRN	SectorLayer1:BYTE

;============================================================================

		INCLUDE	MAINDATA.INC

		INCLUDE	\VISUAL\GNDLIST.INC
		INCLUDE	\VISUAL\VISDATA.INC
		INCLUDE	\VISUAL\VISMACRO.INC

		INCLUDE	\LIB8086\USEFUL.INC
		INCLUDE	\LIB8086\TRIG.INC

;============================================================================

DATA		SEGMENT PARA PUBLIC 'DATA'

VehicleType	DW	0

NumVehicles	DW	0

ConvoyPtr	DW	0

RoutePtr	DW	0

Dist		DW	0

DistFine	DW	0

LeadVehicle	DB	0		;1 = lead vehicle, 0 = following vehicle

StopConvoy	DB	0		;1 = stop convoy

		EVEN

;* sin(slope) values wrt (road / rail)

SinSlope	DW	1364		;TRUCK
		DW	1024		;TRAIN

;* cos(slope) values wrt (road / rail)

CosSlope	DW	32740		;TRUCK
		DW	32752		;TRAIN

PITCH_UP	EQU	3		;pdegs
PITCH_DN	EQU	512-3		;pdegs

BRIDGE_HT	EQU	32		;ft

ACCEL_RATE	EQU	4*256		;ft/sec/sec * 256
DECEL_RATE	EQU	-8*256		;ft/sec/sec * 256

DLY_AFTER_EVENT	EQU	30*100		;delay after event (1/100ths sec)

;* check heading switch

CheckSwitch	DW	CheckHdgN	;0
		DW	CheckHdgE	;2
		DW	CheckHdgS	;4
		DW	CheckHdgW	;6

DATA		ENDS

;============================================================================

SECDATA1	SEGMENT PARA PUBLIC 'DATA'

SECDATA1	ENDS

;============================================================================

DRONECODE	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME CS:DRONECODE
		ASSUME DS:DATA

;* DIV256
;*
;* pass: dx, ax = unsigned 32 bit value
;* ret : dx, ax = dx, ax / 256 (rounded up)
;* kill: flags

DIV256		MACRO

		xchg	al,dh	;/256 retaining lsb in dh
		xchg	al,dl
		xchg	al,ah
		shl	dh,1	;extract 1/2 bit
		mov	dh,0
		adc	ax,0	;round up
		adc	dx,0

		ENDM

;----------------------------------------------------------------------------

;* InitConvoys - initialize truck convoys and trains
;*
;* pass: nothing
;* ret : nothing
;* kill: assume all

InitConvoys	PROC	FAR

		mov	bx,TRUCK
		mov	cx,NUM_TRUCKS
		mov	si,OFFSET ATruckConvoy1
		mov	di,OFFSET ATruck1Route
		call	InitOneConvoy

		mov	bx,TRUCK
		mov	cx,NUM_TRUCKS
		mov	si,OFFSET ATruckConvoy2
		mov	di,OFFSET ATruck2Route
		call	InitOneConvoy

		mov	bx,TRUCK
		mov	cx,NUM_TRUCKS
		mov	si,OFFSET ETruckConvoy1
		mov	di,OFFSET ETruck1Route
		call	InitOneConvoy

		mov	bx,TRUCK
		mov	cx,NUM_TRUCKS
		mov	si,OFFSET ETruckConvoy2
		mov	di,OFFSET ETruck2Route
		call	InitOneConvoy

		mov	bx,TRAIN
		mov	cx,NUM_TRAINS
		mov	si,OFFSET ATrain1
		mov	di,OFFSET ATrain1Route
		call	InitOneConvoy

		mov	bx,TRAIN
		mov	cx,NUM_TRAINS
		mov	si,OFFSET ATrain2
		mov	di,OFFSET ATrain2Route
		call	InitOneConvoy

		mov	bx,TRAIN
		mov	cx,NUM_TRAINS
		mov	si,OFFSET ETrain1
		mov	di,OFFSET ETrain1Route
		call	InitOneConvoy

		mov	bx,TRAIN
		mov	cx,NUM_TRAINS
		mov	si,OFFSET ETrain2
		mov	di,OFFSET ETrain2Route
		call	InitOneConvoy

		ret

InitConvoys	ENDP

;----------------------------------------------------------------------------

;* InitOneConvoy
;*
;* pass: bx = vehicle type
;*       cx = max number of vehicles in convoy
;*       si -> convoy
;*       di -> route
;* ret : nothing
;* kill: assume all

InitOneConvoy	PROC	NEAR

		test	CNVY_ACTIVE[si],1	;convoy active?
		jz	ExitInit		;no ->

;* store params

		mov	VehicleType,bx
		mov	NumVehicles,cx
		mov	ConvoyPtr,si
		mov	RoutePtr,di

;* init convoy speed

		xor	ax,ax

		mov	CNVY_SPEED[si],ax	;speed = 0

		mov	ah,ROUTE_SPEED[di]	;aiming speed * 256

		mov	CNVY_AIM_SPEED[si],ax

;* init convoy event

		mov	al,ROUTE_DRONE[di]
		mov	CNVY_DRONE[si],al

		mov	al,ROUTE_EVENT[di]
		mov	CNVY_EVENT[si],al

;* init each vehicle in convoy (if active)

		add	si,CNVY_REC_SIZE	;ptr -> first vehicle in convoy

InitLoop:	cmp	_VEH_SIDE[si],DEAD	;vehicle active?
		je	InitNext      		;no ->

		mov	_VEH_NODE_PTR[si],di	;ptr -> first route node

		xor	ax,ax

 		mov	_VP_PITCH[si],ax	;pitch = 0
		mov	_VP_ROLL[si],ax		;roll = 0

		mov	_VEH_EVENT[si],al
		mov	_VEH_DIST_FINE[si],ax
		mov	_VEH_XFINE[si],ax
		mov	_VEH_YFINE[si],ax
		mov	_VEH_ZFINE[si],ax

		mov	MOB_TYPE[si],OTYPE_MOBILE1	;skew only mobile

InitNext:	add	si,NEXT_VEHICLE

		loop	InitLoop

ExitInit:	ret

InitOneConvoy	ENDP

;----------------------------------------------------------------------------

;* UpdateConvoys
;*
;* pass: nothing
;* ret : nothing
;* kill: assume all

UpdateConvoys	PROC	FAR

		mov	bx,TRUCK
		mov	cx,NUM_TRUCKS
		mov	si,OFFSET ATruckConvoy1
		mov	di,OFFSET ATruck1Route
		call	UpdateOneConvoy

		mov	bx,TRUCK
		mov	cx,NUM_TRUCKS
		mov	si,OFFSET ATruckConvoy2
		mov	di,OFFSET ATruck2Route
		call	UpdateOneConvoy

		mov	bx,TRUCK
		mov	cx,NUM_TRUCKS
		mov	si,OFFSET ETruckConvoy1
		mov	di,OFFSET ETruck1Route
		call	UpdateOneConvoy

		mov	bx,TRUCK
		mov	cx,NUM_TRUCKS
		mov	si,OFFSET ETruckConvoy2
		mov	di,OFFSET ETruck2Route
		call	UpdateOneConvoy

		mov	bx,TRAIN
		mov	cx,NUM_TRAINS
		mov	si,OFFSET ATrain1
		mov	di,OFFSET ATrain1Route
		call	UpdateOneConvoy

		mov	bx,TRAIN
		mov	cx,NUM_TRAINS
		mov	si,OFFSET ATrain2
		mov	di,OFFSET ATrain2Route
		call	UpdateOneConvoy

		mov	bx,TRAIN
		mov	cx,NUM_TRAINS
		mov	si,OFFSET ETrain1
		mov	di,OFFSET ETrain1Route
		call	UpdateOneConvoy

		mov	bx,TRAIN
		mov	cx,NUM_TRAINS
		mov	si,OFFSET ETrain2
		mov	di,OFFSET ETrain2Route
		call	UpdateOneConvoy

		ret

UpdateConvoys	ENDP

;----------------------------------------------------------------------------

;* UpdateOneConvoy
;*
;* pass: bx = vehicle type
;*       cx = max number of vehicles in convoy
;*       si -> convoy
;*       di -> route
;* ret : nothing
;* kill: assume all

UpdateOneConvoy	PROC	NEAR

		test	CNVY_ACTIVE[si],1	;convoy active?
		_JZ	ExitUpdate		;no ->

		mov	LeadVehicle,1	;first active vehicle is leader

		mov	StopConvoy,0

;--------------
;* store params
;--------------

		mov	VehicleType,bx
		mov	NumVehicles,cx
		mov	ConvoyPtr,si
		mov	RoutePtr,di

;-------------------
;* sort convoy event
;-------------------

		cmp	CNVY_EVENT[si],-1	;wait for event?
		je	SortDelay		;no ->

		mov	bl,CNVY_DRONE[si]	;fetch drone number
		xor	bh,bh
		shl	bx,1		;*2 word index

		mov	di,DronePtrs[bx]	;di -> drone data

		mov	al,_DRONE_EVENT[di]
		cmp	al,CNVY_EVENT[si]	;event satisfied?
		jb	@F			;no ->

		mov	CNVY_DRONE[si],0	;clear event
		mov	CNVY_EVENT[si],-1

		mov	CNVY_DELAY[si],DLY_AFTER_EVENT

		jmp	SortDelay

@@:		xor	ax,ax		;aiming speed = 0

		jmp	ContSpeed	;override route leg speed ->

;-------------------
;* sort convoy delay
;-------------------

SortDelay:	mov	ax,CNVY_DELAY[si]

		test	ax,ax		;delaying?
		jz	SortSpeed	;no ->

;* do not start delay until convoy has stopped

		cmp	CNVY_SPEED[si],0	;convoy stopped?
		jne	@F			;no ->

		sub	ax,LastFrame

		MINM	ax

		mov	CNVY_DELAY[si],ax

@@:		xor	ax,ax		;aiming speed = 0

		jmp	ContSpeed	;override route leg speed ->

;-------------------
;* sort convoy speed
;-------------------

;* error = aim speed - speed
;*
;* select error
;* case = 0 (no change)
;*    accel = 0
;* case > 0 (accelerate)
;*    accel = min(ACCEL_RATE * DeltaTime, error)
;* case < 0 (decelerate)
;*    accel = max(DECEL_RATE * DeltaTime, error)
;* endselect
;*
;* speed = speed + accel

SortSpeed:	mov	ax,CNVY_AIM_SPEED[si]

ContSpeed:	sub	ax,CNVY_SPEED[si]

		jz	SetSpeed	;zero error ->

		mov	bp,ax		;bp = error

		js	Decelerate	;error < 0 ->

Accelerate:	mov	ax,ACCEL_RATE
		mov	dx,DeltaTime
		imul	dx
		FRACADJ	ax

		cmp	ax,bp		;change <= error?
		jle	SetSpeed	;yes ->

		mov	ax,bp

		jmp	SetSpeed

Decelerate:	mov	ax,DECEL_RATE
		mov	dx,DeltaTime
		imul	dx
		FRACADJ	ax

		cmp	ax,bp		;change >= error?
		jge	SetSpeed	;yes ->

		mov	ax,bp

SetSpeed:	add	CNVY_SPEED[si],ax

;-----------------
;* update vehicles
;-----------------

		add	si,CNVY_REC_SIZE	;si -> first vehicle

UpdateLoop:	cmp	_VEH_SIDE[si],DEAD	;vehicle active?
		_JE	SkipUpdate    		;no ->

;* dist moved = speed * cos(pitch) * DeltaTime

		mov	bx,ConvoyPtr
		mov	ax,CNVY_SPEED[bx]

;* headlamp animation

		and	MOB_ANIM[si],NOT HEADLAMPS	;assume off

		test	ax,ax		;speed = 0?
		jz	LampsOk		;yes ->

		cmp	Night,0		;night?
		jne	@F		;yes ->

		cmp	Fog,0		;fog?
		je	LampsOk		;no ->

@@:		or	MOB_ANIM[si],HEADLAMPS

;* calc speed * cos(pitch) wrt vehicle type

LampsOk:	cmp	WORD PTR _VP_PITCH[si],0	;any pitch?
		je	@F	 		     	;no ->

		mov	bx,VehicleType

		mov	dx,CosSlope[bx]

		imul	dx
		FRACADJ	ax		;speed * cos(pitch)

@@:		mov	dx,DeltaTime
		imul	dx		;(result always positive)

		shl	ax,1		;*2
		rcl	dx,1

		DIV256

		mov	Dist,dx
		mov	DistFine,ax

;* dist to go = dist to go - dist moved

		mov	dx,_VEH_DIST[si]
		mov	ax,_VEH_DIST_FINE[si]

		sub	ax,DistFine
		sbb	dx,Dist

		jc	Overshoot	;satisfied route node ->

;------------------------
;* travel along route leg
;------------------------

		mov	_VEH_DIST[si],dx
		mov	_VEH_DIST_FINE[si],ax

		mov	bx,ConvoyPtr
		mov	ax,CNVY_SPEED[bx]

		call	CalcDXYZwrtT

		call	UpdateMobile

		call	SortSlope

;* if lead vehicle and above ground then check bridge ok

		test	LeadVehicle,1
		jz	@F

		cmp	WORD PTR _VP_ZFT_LO[si],0
		je	@F

		call	CheckBridge

@@:		jmp	UpdateNext

;----------------------
;* satisfied route node
;----------------------

;* delete mobile (need to re-establish position)

Overshoot:	call	DeleteMobile

;* point to next node

		mov	di,_VEH_NODE_PTR[si]

		test	ROUTE_ATTR[di],RN_LINK	;link back to first node?
		jz	@F			;no ->

		mov	di,RoutePtr

		mov	_VEH_EVENT[si],0	;reset event count

		jmp	SetNodePtr

@@:		add	di,ROUTE_REC_SIZE

		inc	_VEH_EVENT[si]		;inc event count

SetNodePtr:	mov	_VEH_NODE_PTR[si],di

;* check for upslope / down slope

		test	ROUTE_ATTR[di],RN_UPSLOPE	;upslope?
		jz	@F	 			;no ->

		mov	WORD PTR _VP_PITCH[si],PITCH_UP

		mov	MOB_TYPE[si],OTYPE_MOBILE4	;mobile on bridge

		jmp	SlopeOk

@@:		test	ROUTE_ATTR[di],RN_DNSLOPE	;downslope?
		jz	SlopeOk				;no ->

		mov	_VP_PITCH[si],PITCH_DN

;* if lead vehicle then
;*    set convoy aiming speed
;*    if delay required then
;*       set delay
;*    endif
;*    set event
;* endif

SlopeOk:	test	LeadVehicle,1	;leader?
		jz	SkipLeader	;no ->

		mov	bx,ConvoyPtr

		mov	ah,ROUTE_SPEED[di]	;aiming speed * 256
		xor	al,al

		mov	CNVY_AIM_SPEED[bx],ax

	   	test	ROUTE_ATTR[di],RN_DELAY	;wait for delay period?
		jz	@F			;no ->

		mov	CNVY_DELAY[bx],DLY_AFTER_EVENT

@@:		mov	al,ROUTE_DRONE[di]
		mov	CNVY_DRONE[bx],al

		mov	al,ROUTE_EVENT[di]
		mov	CNVY_EVENT[bx],al

;----------------------------------------------------------------------------
;* When a vehicle passes a route node, the vehicle's position needs to be
;* re-calculated using the node as a datum. This is to reduce errors. The
;* overshoot distance must be taken into account.
;----------------------------------------------------------------------------

;* overshoot dist = dist moved - dist to go

SkipLeader:	mov	dx,Dist
		mov	ax,DistFine

		sub	ax,_VEH_DIST_FINE[si]
		sbb	dx,_VEH_DIST[si]

;* fetch dist to next node

		mov	cx,ROUTE_DIST[di]
		xor	bx,bx

;* dist to go = node dist - overshoot dist

		sub	bx,ax
		sbb	cx,dx
		
		mov	_VEH_DIST[si],cx
		mov	_VEH_DIST_FINE[si],bx

		DIV256		;ax = overshoot dist * 256

		push	ax

;* sort new heading

		mov	ax,ROUTE_DIR[di]
		mov	_VP_HDG[si],ax

;* place vehicle at route node (datum)

		xor	ah,ah

		mov	al,ROUTE_XSEC[di]
		mov	_VP_XSEC[si],ax
		mov	al,ROUTE_YSEC[di]
		mov	_VP_YSEC[si],ax

		mov	ax,ROUTE_XFT[di]
		mov	_VP_XFT[si],ax
		mov	ax,ROUTE_YFT[di]
		mov	_VP_YFT[si],ax

		xor	ax,ax
		mov	_VEH_XFINE[si],ax
		mov	_VEH_YFINE[si],ax

;* recreate mobile at route node

		call	CreateMobile

;* compensate for overshoot

		pop	ax

		call	CalcDXYZ

		call	UpdateMobile

		call	SortSlope

UpdateNext:	mov	LeadVehicle,0	

SkipUpdate:	add	si,NEXT_VEHICLE
		dec	NumVehicles
		_JNZ	UpdateLoop

;-----------------------
;* check for stop convoy (only stop convoy after updating all vehicles)
;-----------------------

		test	StopConvoy,1
		jz	ExitUpdate

		mov	si,ConvoyPtr

		mov	[si].CNVY_ACTIVE,0
		mov	[si].CNVY_SPEED,0
		mov	[si].CNVY_AIM_SPEED,0		

ExitUpdate:	ret

UpdateOneConvoy	ENDP

;----------------------------------------------------------------------------

;* CalcDXYZ - calc delta x, y, z (distance)
;*
;* pass: ax = distance (ft * 256)
;*       si -> MOBILE + VIEWPOINT + VEHICLE compound data block
;* ret : ax = delta xft, _VEH_XFINE[si]
;*       bx = delta yft, _VEH_YFINE[si]
;*       cx = delta zft, _VEH_ZFINE[si]
;* kill: dx, di, bp, flags
;*
;* note: Returns via CalcDXYZwrtT

CalcDXYZ	LABEL	NEAR

		mov	di,32767	;frame time = 1 sec (no effect)

		jmp	IntoCalcDXYZ

;* CalcDXYZwrtT - calc delta x, y, z wrt time (speed)
;*
;* pass: ax = speed (ft/sec * 256)
;*       si -> MOBILE + VIEWPOINT + VEHICLE compound data block
;* ret : ax = delta xft, _VEH_XFINE[si]
;*       bx = delta yft, _VEH_YFINE[si]
;*       cx = delta zft, _VEH_ZFINE[si]
;* kill: dx, di, bp, flags
;*
;* note: Pre-calculated values for cos(pitch) and sin(pitch) are used, instead
;*       of using standard SinTable[] and CosTable[] values, as greater accuracy
;*       is required.

CalcDXYZwrtT	PROC	NEAR

		mov	di,DeltaTime

IntoCalcDXYZ	LABEL	NEAR		;<<<<< from CalcDXYZ <<<<<

		mov	cx,ax		;store speed

;* calc speed * cos(pitch) wrt vehicle type

		cmp	WORD PTR _VP_PITCH[si],0	;any pitch?
		je	@F	 		     	;no ->

		mov	bx,VehicleType

		mov	dx,CosSlope[bx]

		imul	dx
		FRACADJ	ax		;speed * cos(pitch)

@@:		mov	bp,ax

;* delta xft = speed * cos(pitch) * sin(hdg) * DeltaTime / 256

		mov	bx,_VP_HDG[si]

		SINCOS	ax,bx,bx	;ax = sin(hdg), bx = cos(hdg)

		imul	bp
		FRACADJ	ax		;speed * cos(pitch) * sin(hdg)

		imul	di
		FRACADJ	ax		;speed * cos(pitch) * sin(hdg) * DeltaTime

		cwd			;align for xft, xfine
		mov	dl,ah
		mov	ah,al
		xor	al,al

		add	_VEH_XFINE[si],ax
		adc	dx,0

		mov	ax,bp		;ax = speed * cos(pitch)

		mov	bp,dx		;bp = delta xft

;* delta yft = speed * cos(pitch) * cos(hdg) * DeltaTime / 256

		imul	bx
		FRACADJ	ax		;speed * cos(pitch) * cos(hdg)

		imul	di
		FRACADJ	ax		;speed * cos(pitch) * cos(hdg) * DeltaTime

		cwd			;align for yft, yfine
		mov	dl,ah
		mov	ah,al
		xor	al,al

		add	_VEH_YFINE[si],ax
		adc	dx,0

		mov	ax,cx		;ax = speed

		mov	cx,dx		;cx = delta yft

;* delta zft = speed * sin(pitch) * DeltaTime / 256

		xor	dx,dx		;assume delta zft = 0

		cmp	WORD PTR _VP_PITCH[si],0	;any pitch?
		je	SkipZCalc		     	;no ->

		mov	bx,VehicleType

		mov	dx,SinSlope[bx]

		cmp	WORD PTR _VP_PITCH[si],PITCH_UP	;upslope?
		je	@F	 	     		;yes ->

		neg	dx

@@:		imul	dx
		FRACADJ	ax		;speed * sin(pitch)

		imul	di
		FRACADJ	ax		;speed * sin(pitch) * DeltaTime
		
		cwd			;align for zft, zfine
		mov	dl,ah
		mov	ah,al
		xor	al,al

		add	_VEH_ZFINE[si],ax
		adc	dx,0

;* shuffle return values

;* bp = delta xft
;* cx = delta yft
;* dx = delta zft

SkipZCalc:	mov	ax,bp		;ax = delta xft
		mov	bx,cx		;bx = delta yft
		mov	cx,dx		;cx = delta zft

		ret

CalcDXYZwrtT	ENDP

;----------------------------------------------------------------------------

;* SortSlope - test for end of upslope / downslope
;*
;* pass: si -> MOBILE + VIEWPOINT + VEHICLE compound data block
;* ret : nothing
;* kill: ax, flags

SortSlope	PROC	NEAR

;* if upslope then
;*    if zft >= BRIDGE_HT
;*       zft = BRIDGE_HT
;*       zfine = 0
;*       pitch = 0
;*    endif
;* endif

		cmp	WORD PTR _VP_PITCH[si],PITCH_UP	;upslope?
		jne	@F	 	     		;no ->

		cmp	WORD PTR _VP_ZFT_LO[si],BRIDGE_HT	;zft >= BRIDGE_HT?
		jb	ExitSlope				;no ->

		xor	ax,ax

		mov	WORD PTR _VP_ZFT_LO[si],BRIDGE_HT
		mov	_VEH_ZFINE[si],ax
		mov	_VP_PITCH[si],ax

		jmp	ExitSlope

;* if downslope then
;*    if zft < 0 then
;*       zft = 0
;*       zfine = 0
;*       pitch = 0
;*    endif
;* endif

@@:		cmp	_VP_PITCH[si],PITCH_DN	;downslope?
		jne	ExitSlope     		;no ->

		cmp	WORD PTR _VP_ZFT_HI[si],0	;zft < 0?
		jns	ExitSlope			;no ->

		xor	ax,ax

		mov	WORD PTR _VP_ZFT_HI[si],ax
		mov	WORD PTR _VP_ZFT_LO[si],ax
		mov	_VEH_ZFINE[si],ax
		mov	_VP_PITCH[si],ax

		mov	MOB_TYPE[si],OTYPE_MOBILE1	;skew only mobile

ExitSlope:	ret

SortSlope	ENDP

;----------------------------------------------------------------------------

;* CheckBridge - check bridge is intact
;*
;* pass: si -> MOBILE + VIEWPOINT + VEHICLE compound data block
;* ret : nothing
;* kill: ax, bx, cx, dx, di, bp, flags
;*
;* note: Only call this routine if lead vehicle and zft > 0.
;*
;*       Assume bridges are either NS or EW.
;*
;* 	 The vehicle control routine always keeps the vehicles in the exact
;*	 centre of the road so assume that the x or y axis the vehicle is
;*       travelling along is on a "grid" sub-division (256ft).

CheckBridge	PROC	NEAR

;----------------------
;* ensure on active map
;----------------------

		cmp	WORD PTR _VP_XSEC[si],31
		_JA	ExitCheck
		cmp	WORD PTR _VP_YSEC[si],31
		_JA	ExitCheck

;----------------------------
;* get ground object list ptr (if occupied sector)
;----------------------------

;* calc map index = x sec + y sec * 32

		mov	bp,_VP_YSEC[si]

		REPT	5
		shl	bp,1
		ENDM

		add	bp,_VP_XSEC[si]

;* test for occupied sector

		mov	al,SectorLayer1[bp]

		test	al,al
		_JZ	ExitCheck

;* calc ptr to sector data record

		CALC_SEC_PTR

;* get ptr to ground object list

		mov	di,[bx].SEC_OBJ_PTR

;* calc heading index

		mov	bx,_VP_HDG[si]

		mov	cl,7
		shr	bx,cl		;0 .. 3

		shl	bx,1		;0 .. 6 step 2

;* xgrid = (xft + 8192) / 256

		mov	ax,_VP_XFT[si]
		add	ax,8192
		mov	dl,ah		;dl = xgrid

;* ygrid = (yft + 8192) / 256

		mov	ax,_VP_YFT[si]
		add	ax,8192
		mov	dh,ah		;dh = ygrid

;--------------------------------------------
;* scan ground object list for damaged bridge
;--------------------------------------------

		mov	ax,SECDATA1
		mov	es,ax

;---------------------------
GndObjLoop	LABEL	NEAR
;---------------------------

;* check for end of list (-1 terminator)

		cmp	ES:[di].GND_NUM,-1
		je	ExitGndObj

;* check object dead

		test	ES:[di].GND_ANIM,OBJECT_DEAD
		jz	NextGndObj

;* check object ahead of vehicle (wrt heading)

		jmp	CheckSwitch[bx]

CheckHdgN:	cmp	ES:[di].GND_XGRID,dl	;obj xgrid = veh xgrid?
		jne	NextGndObj		;no ->
		cmp	ES:[di].GND_YGRID,dh	;obj ygrid >= veh ygrid?	
		jae	ContGndObj		;yes ->

		jmp	NextGndObj

CheckHdgE:	cmp	ES:[di].GND_YGRID,dh	;obj ygrid = veh ygrid?
		jne	NextGndObj		;no ->
		cmp	ES:[di].GND_XGRID,dl	;obj xgrid >= veh xgrid?
		jae	ContGndObj		;yes ->

		jmp	NextGndObj

CheckHdgS:	cmp	ES:[di].GND_XGRID,dl	;obj xgrid = veh xgrid?
		jne	NextGndObj		;no ->
		cmp	ES:[di].GND_YGRID,dh	;obj ygrid <= veh ygrid?
		jbe	ContGndObj		;yes ->

		jmp	NextGndObj

CheckHdgW:	cmp	ES:[di].GND_YGRID,dh	;obj ygrid = veh ygrid?
		jne	NextGndObj		;no ->
		cmp	ES:[di].GND_XGRID,dl	;obj xgrid <= veh xgrid?
		jbe	ContGndObj		;yes ->

		jmp	NextGndObj

;* check if destroyed bridge object

ContGndObj:	mov	al,ES:[di].GND_NUM

		cmp	al,GND_EMBCRATER
		je	@F
		cmp	al,GND_RBEWD
		je	@F
		cmp	al,GND_RBNSD
		je	@F
		cmp	al,GND_RLBEWD
		je	@F
		cmp	al,GND_RLBNSD
		je	@F

		jmp	NextGndObj

;* stop convoy (damaged bridge ahead)

@@:		mov	StopConvoy,1

		jmp	ExitGndObj

NextGndObj:	add	di,GND_REC_SIZE

		jmp	GndObjLoop

ExitGndObj:	mov	ax,DATA
		mov	es,ax

ExitCheck:	ret

CheckBridge	ENDP

DRONECODE	ENDS

;============================================================================

		END

