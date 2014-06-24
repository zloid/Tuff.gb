SECTION "EntityLogic",ROM0


; Update the on screen entites based on the type handler ----------------------
entity_update:
    ld      de,entityScreenState
    ld      b,0

.loop:

    ; load type / active
    ld      a,[de]
    cp      0
    jr      z,.skip; not active skip
    ld      l,a ; store type

    ; get sprite index
    call    _entity_sprite_offset
    add     a,b; offset + entity index
    ld      h,a; store sprite index for position code

    ; store counter, screen state address and indecies
    push    bc
    push    hl
    push    de

    ld      c,a; store sprite index for update handler

    ; invoke custom entity update handler
    ld      a,l
    dec     a; convert into 0 based offset
    ld      hl,DataEntityUpdateHandlerTable
    add     a,a  ; multiply entity type by 4
    add     a,a
    add     a,l ; add a to hl
    ld      l,a
    adc     a,h
    sub     l
    ld      h,a

    push    bc
    call    _entity_handler_jump
    pop     bc

    pop     de
    pop     hl

    ; check if the update handler disabled the entity
    ld      a,[de]
    cp      0
    jr      z,.disabled; not active skip

    inc     de; skip type
    inc     de; skip flags
    inc     de; skip direction

    ld      a,[de] ; x position
    ld      c,a
    inc     de

    ld      a,[de] ; y position
    ld      b,a
    ld      a,h  
    call    sprite_set_position
    inc     de

    pop     bc

    inc     de
    inc     de
    inc     de
    jr      .next

.disabled:
    ld      a,c
    call    sprite_disable
    pop     bc

.skip:
    inc     de
    inc     de
    inc     de
    inc     de
    inc     de
    inc     de
    inc     de
    inc     de

.next:
    inc     b
    ld      a,b
    cp      ENTITY_PER_ROOM
    jr      nz,.loop
    ret


; Load the entity state from RAM or the map default and  ----------------------
; Set up sprite and initial data based on type handler ------------------------
entity_load:

    ; clear tile row mapping
    call    _entity_reset_tile_row_mapping

    ; get offset for entity map data
    ld      hl,mapRoomBlockBuffer + MAP_ROOM_SIZE
    ld      b,0

.loop:

    ld      a,[mapRoomEntityCount]
    cp      b
    ret     z

    ; get type / used
    ld      a,[hl]
    ld      c,a ; store byte
    and     %00111111 ; mask type bits
    cp      0
    jr      z,.next ; entity is not set for room

    ; init base state
    push    hl
    call    _entity_screen_offset_hl

    ; set type
    ld      a,c
    and     %00111111 ; mask type bits
    ld      [hli],a

    ; reset flags
    ld      a,0
    ld      [hli],a

    ; set default direction 
    ld      a,c
    and     %11000000 ; mask type bits
    srl     a
    srl     a
    srl     a
    srl     a
    srl     a
    srl     a
    ld      [hl],a
    pop     hl; restore screen state address

    call    _entity_load

.init:
    push    hl

    ld      a,c ; type / dir flags
    and     %00111111 ; mask type bits
    ld      l,a; store entity type
    call    _entity_sprite_offset
    add     a,b ; offset + entity index
    ld      c,a ; store sprite index
    call    sprite_enable

    ; Get palette flag
    push    bc
    ld      a,l; load type
    call    _entity_defintion
    and     %01000000
    srl     a
    srl     a
    ld      b,a
    ld      a,c
    call    sprite_set_palette
    pop     bc

    ; get screen entity offset
    call    _entity_screen_offset_de
    push    bc
    push    de


    ; load entity sprite data into one of the available sprite row slots
    ; in the upper half of the sprite memory
    ld      a,[de] ; load type
    call    _entity_load_tile_row ; -> a = tile offset
    ld      b,a ; load tile offset 
    ld      a,c ; load sprite index
    call    sprite_set_tile_offset


    ; call custom load handler
    ld      a,l
    dec     a; convert into 0 based offset
    ld      hl,DataEntityLoadHandlerTable
    add     a,a  ; multiply entity type by 4
    add     a,a
    add     a,l ; add a to hl
    ld      l,a
    adc     a,h
    sub     l
    ld      h,a

    ; call the load handler
    call    _entity_handler_jump
    pop     de
    cp      1
    jr      z,.ignore_load

    ; set sprite position
    inc     de ; skip type
    inc     de ; skip flags
    inc     de ; skip direction

    ld      l,c ; restore sprite index
    ld      a,[de] ; load y position
    ld      c,a
    inc     de
    ld      a,[de] ; load x position
    ld      b,a
    ld      a,l ; load sprite index
    call    sprite_set_position

    pop     bc;  restore entity / loop index
    pop     hl

    jr      .next

.ignore_load:
    pop     bc;  restore entity / loop index

    call    _entity_screen_offset_hl
    ld      [hl],0

    pop     hl
    ld      a,c
    call    sprite_disable

.next:
    inc     hl
    inc     hl

    inc     b
    ld      a,b
    cp      ENTITY_PER_ROOM
    jp      nz,.loop
    ret



; Load a single Entity's state ------------------------------------------------
_entity_load:

    ; check if an existing bucket that stores this entity 
    push    hl
    push    de
    push    bc
    call    _entity_get_current_room_id
    call    _entity_find_bucket ; c is the room id, b is the entity id, return a and hl

    cp      1
    jr      nz,.load_defaults

.load_stored:
    
    inc     hl; skip room id

    ; get entity screen offset for b into de
    call    _entity_screen_offset_de
    inc     de; skip type

    ; load flags, direction and entity id (FFFFDDII)
    ld      a,[hli]
    ld      b,a; store copy of original value into b

    ; get flags
    srl     a
    srl     a
    srl     a
    srl     a
    and     %00001111
    ld      [de],a; set flags
    inc     de

    ; get direction
    ld      a,b; load origin value one more time
    srl     a
    srl     a
    and     %00000011
    ld      [de],a; set direction
    inc     de

    ; load y position
    ld      a,[hli]
    ld      [de],a
    inc     de
    
    ; load x position
    ld      a,[hl]
    ld      [de],a
    inc     de

    ; restore registers
    pop     bc
    pop     de
    pop     hl
    ret


    ; load default data from map buffer
.load_defaults:

    ; restore registers
    pop     bc
    pop     de
    pop     hl

    ; push loop indicies
    push    hl
    push    de
    
    ; get entity screen offset for b into de
    call    _entity_screen_offset_de
    inc     de ; skip type
    inc     de ; skip flags
    inc     de ; skip direction

    ; skip stored type and direction
    inc     hl

    ; load x/y value
    ld      a,[hl]
    and     %11110000 ; y position, just works we can skip the x16 here
    add     16 ; anchor at the bottom
    ld      [de],a
    inc     de

    ; x position
    ld      a,[hl]
    and     %00001111 ; need to multiply by 16 here
    sla     a
    sla     a
    sla     a
    sla     a
    add     8
    ld      [de],a

    ; restore indicies
    pop     de
    pop     hl
    ret


; Store the entity state into RAM based on the type handler -------------------
; -----------------------------------------------------------------------------
entity_store:
    ld      de,entityScreenState
    ld      b,0

.loop:
    ld      a,[de]
    cp      0
    jr      z,.skip; entity is not loaded for this screen

    ; find a bucket to store this entity in, either the bucket which already
    ; stores it, or a unused one
    push    de
    call    _entity_get_last_room_id
    call    _entity_get_store_bucket
    pop     de

    ; did we find a bucket?
    cp      1
    jr      nz,.next

    ; store into bucket
    ; c is the room id, b is the entity id, hl is the pointer, de the screen data
    ld      a,c
    ld      [hli],a ; store room id

    inc     de ; skip type [0]
    
    ; combine flags, entity id and direction
    ; FFFFDDII
    ld      a,[de]; load flags
    inc     de 
    sla     a
    sla     a
    sla     a
    sla     a
    and     %11110000
    or      b; merge with id
    ld      b,a; store into b

    ld      a,[de] ; load direction
    inc     de
    sla     a
    sla     a
    and     %00001100
    or      b; merge with id and flags
    ld      [hli],a 

    ; y position
    ld      a,[de]
    inc     de
    ld      [hli],a 

    ; x position
    ld      a,[de]
    inc     de
    ld      [hl],a 

    ; skip tileslot, custom and custom
    inc     de
    inc     de
    inc     de
    jr      .next

.skip:
    inc     de
    inc     de
    inc     de
    inc     de
    inc     de
    inc     de
    inc     de
    inc     de

.next:
    inc     b
    ld      a,b
    cp      ENTITY_PER_ROOM
    jr      nz,.loop
    ret


; Reset the entity screen state -----------------------------------------------
; -----------------------------------------------------------------------------
entity_reset:
    ld      hl,entityScreenState
    ld      b,0

.loop:
    ld      a,[hl]
    cp      0
    jr      z,.skip; not loaded

    ; disable sprite 
    call    _entity_sprite_offset
    add     a,b; offset + entity index
    call    sprite_disable
    ;call    sprite_unset_mirror ; TODO needed?

    ; unset type
    ld      a,0
    ld      [hl],a

.skip:
    inc     hl
    inc     hl
    inc     hl
    inc     hl
    inc     hl
    inc     hl
    inc     hl
    inc     hl

.next:
    inc     b
    ld      a,b
    cp      ENTITY_PER_ROOM
    jr      nz,.loop
    ret


; Collision Wrappers ----------------------------------------------------------
; -----------------------------------------------------------------------------
entity_col_up:; b = x, c = y
    push    bc

    ld      a,c
    sub     17
    ld      c,a

    ; middle
    call    map_get_collision_simple
    jr      nz,.done

    ; left
    ld      a,b
    sub     7
    ld      b,a
    call    map_get_collision_simple
    jr      nz,.done

    ; right
    ld      a,b
    add     14
    ld      b,a
    call    map_get_collision_simple

.done:
    pop     bc
    ret
    

entity_col_down:; b = x, c = y
    push    bc

    ; middle
    call    map_get_collision_simple
    jr      nz,.done

    ; left
    ld      a,b
    sub     7
    ld      b,a
    call    map_get_collision_simple
    jr      nz,.done

    ; right
    ld      a,b
    add     14
    ld      b,a
    call    map_get_collision_simple

.done:
    pop     bc
    ret
    

entity_col_left:; b = x, c = y
    push    bc

    ; border
    ld      a,b
    sub     9
    ld      b,a

    ; bottom
    dec     c
    call    map_get_collision_simple
    jr      nz,.done

    ; middle
    ld      a,c
    sub     7
    ld      c,a
    call    map_get_collision_simple
    jr      nz,.done

    ; top
    ld      a,c
    sub     8
    ld      c,a
    call    map_get_collision_simple

.done:
    pop     bc
    ret
    

entity_col_right:; b = x, c = y
    push    bc

    ld      a,b
    add     8
    ld      b,a

    ; bottom
    dec     c
    call    map_get_collision_simple
    jr      nz,.done

    ; middle
    ld      a,c
    sub     7
    ld      c,a
    call    map_get_collision_simple
    jr      nz,.done

    ; top
    ld      a,c
    sub     8
    ld      c,a
    call    map_get_collision_simple

.done:
    pop     bc
    ret


; Trampolin for entity logic handler ------------------------------------------
; -----------------------------------------------------------------------------
_entity_handler_jump:
    jp      [hl]


; Entity Sprite Handling ------------------------------------------------------
; -----------------------------------------------------------------------------
_entity_sprite_offset: ; a = sprite type -> a = background offset
    call    _entity_defintion
    and     %10000000
    cp      %10000000
    jr      z,.foreground
    ld      a,ENTITY_BG_SPRITE_INDEX
    ret

.foreground:
    ld      a,ENTITY_FG_SPRITE_INDEX
    ret


_entity_reset_tile_row_mapping:
    ld      hl,entityTileRowMap
    ld      a,255
    ld      [hli],a
    ld      [hli],a
    ld      [hli],a
    ld      [hl],a
    ret


_entity_load_tile_row: ; a = entity type -> a = sprite tile offset for the entity

    push    de
    push    hl
    push    bc

    call    _entity_defintion
    and     %00111111 ; mask tile source row
    ld      c,a ; store tile row into c
    
    ; start search loop for tilerow map
    ld      b,0
    ld      hl,entityTileRowMap

.loop:
    ld      a,[hl]

    ; check if tilerow at this offset is the row required by the entity
    cp      c 
    jr      z,.done

    ; otherwise check if we got a free slow in vram to put the tilerow into
    cp      255
    jr      z,.load

    inc     hl
    inc     b
    cp      4
    jr      nz,.loop

    ; FIXME 
    ; we should never end up here because we got at most 4 different entity
    ; sprite rows
    ld      b,0; failsafe

.load: ; b is the index we we'll be mapping into, c is the sprite row of the entity that needs to be loaded
    
    ; mark tilerow as used
    ld      a,c ; c = sprite row index used for the row at [hl]
    ld      [hl],a

    ; load sprite row for entity
    ld      hl,DataEntityRows
    ld      de,$8400
    call    tileset_load_sprite_row

.done:
    ld      a,b ; load the row into which the sprite data got loaded
    add     a,a ; x4
    add     a,a
    add     a,16 ; skip the first 4 rows in vram

    pop     bc
    pop     hl
    pop     de

    ret



; Helper ----------------------------------------------------------------------
_entity_screen_offset_hl: ; b = entity index
    ld      h,entityScreenState >> 8; high byte, needs to be aligned at 256 bytes
    ld      l,b
    sla     l
    sla     l
    sla     l
    ret


_entity_screen_offset_de: ; b = entity index
    ld      d,entityScreenState >> 8; high byte, needs to be aligned at 256 bytes
    ld      e,b
    sla     e
    sla     e
    sla     e
    ret


_entity_defintion: ; a = sprite type
    push    hl
    ld      hl,DataEntityDefinitions

    dec     a; convert into zero based index

    ; a x 8
    add     a
    add     a
    add     a

    ; hl + a
    add     a,l
    ld      l,a
    adc     a,h
    sub     l
    ld      h,a

    ; load definition
    ld      a,[hl]
    pop     hl
    ret



; Entity Storage Bucket Handling ----------------------------------------------
; -----------------------------------------------------------------------------
_entity_get_current_room_id: ; c -> room id

    ld      a,[mapRoomX]
    inc     a ; convert to 1 based indexing
    ld      h,a

    ld      a,[mapRoomY]
    inc     a ; convert to 1 based indexing
    ld      e,a

    ; get room number index into hl
    call    math_mul8b ; hl = h * e 
    ld      c,l

    ret



_entity_get_last_room_id: ; c -> room id

    ld      a,[mapRoomLastX]
    inc     a ; convert to 1 based indexing
    ld      h,a

    ld      a,[mapRoomLastY]
    inc     a ; convert to 1 based indexing
    ld      e,a

    ; get room number index into hl
    call    math_mul8b ; hl = h * e 
    ld      c,l

    ret



_entity_get_store_bucket: ; c = room id (1-255), b = entity id (0-3)
    push    bc
    call    _entity_find_bucket; first check for a existing bucket that contains the entity
    cp      1
    jr      z,.done ; found a used bucket for this entity

    ; find a free bucket, if possible
    call    _entity_find_free_bucket
.done:
    pop     bc
    ret
    


_entity_find_bucket: ; b = room id (1-255), c = entity id (0-3)
    ; return a = 1 if we found a match, in which case hl = data pointer to entity state

    ; [roomid] (1 based indexing)
    ; [ffffff][ii] flags and entity id
    ; [y position]
    ; [x position]
    ld      hl,entityStoredState
    ld      e,0

.loop:
    ld      a,[hl]; get room id
    cp      0
    jr      z,.skip; skip empty buckets

    ; check for room id match
    cp      c
    jr      nz,.skip

    ; check entity id match
    inc     hl
    ld      a,[hl]
    and     %00000011
    dec     hl
    cp      b
    jr      nz,.skip

    ; match found, hl is at the correct offset already
    ld      a,1
    ret

.skip:
    inc     hl
    inc     hl
    inc     hl
    inc     hl

    ; break out after going through all rooms
.next:
    inc     e
    ld      a,e
    cp      ENTITY_MAX_STORE_BUCKETS
    jr      z,.not_found
        
    jr      .loop
    
.not_found:
    ld      a,0
    ret



_entity_find_free_bucket:
    ; return a = 1 if we found a free spot, in which case hl = data pointer to entity state

    ; [roomid] (1 based indexing)
    ; [ffffff][ii] flags and entity id
    ; [y position]
    ; [x position]
    ld      hl,entityStoredState
    ld      e,0

.loop:
    ld      a,[hl]; get room id
    cp      0
    jr      nz,.used; skip used buckets

    ; found a free spot, return the pointer
    ld      a,1
    ret

.used:
    inc     hl
    inc     hl
    inc     hl
    inc     hl

    ; break out after going through all rooms
.next:
    inc     e
    ld      a,e
    cp      ENTITY_MAX_STORE_BUCKETS
    jr      z,.not_found
        
    jr      .loop
    
.not_found:
    ld      a,0
    ret
