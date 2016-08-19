; Player Water Movement (Swimming and Diving) ---------------------------------
playerWaterSwimOffsetTable:
    DB      1,1,2,2,1,1,0,0,1,1,2,2,1,1,0,0

playerWaterHitOffsetTable:
    DB      1,2,3,4,6,7,8,9,10,8,7,7,6,6,6,5,5,5,5,4
    DB      4,4,4,3,3,3,3,3,2,2,2,2,2,1,1,1


player_water_update:

    ; check for the intitial frame on which we hit the water
    ld      a,[playerInWater]
    cp      0
    jr      nz,.not_initial

    ; reset bounce frames
    xor     a
    ld      [playerBounceFrames],a

    ; save speed
    ld      a,[playerFallFrames]
    ld      [playerWaterHitDepth],a

    ld      a,1
    ld      [playerInWater],a

    xor     a
    ld      [playerFallFrames],a

    ; play sound
    ld      a,[playerWasUnderWater]
    cp      1
    jr      z,.sound_surface

    ; water in gfx
    ld      d,EFFECT_WATER_IN_OFFSET
    call    player_effect_water_splash

    ld      a,SOUND_EFFECT_PLAYER_WATER_ENTER
    jr      .sound

.sound_surface:
    ; water out gfx
    ld      d,EFFECT_WATER_OUT_OFFSET
    call    player_effect_water_splash

    ld      a,SOUND_EFFECT_PLAYER_WATER_LEAVE

.sound:
    call    sound_play_effect_two

    ; check if we were previously under water, if so skip water offset
    ld      a,[playerWasUnderWater]
    cp      1
    jr      nz,.not_initial

    ; if we are surfacing skip the offset, and correct the player y position
    ld      a,7
    ld      [playerWaterTick],a

    ld      a,1
    ld      [playerWaterHitDone],a
    ld      [playerGravityTick],a

    xor     a
    ld      [playerWasUnderWater],a
    ld      [playerUnderWater],a
    ld      [playerJumpForce],a

    ; correct y position
    ld      a,[playerY]
    and     %11111000
    add     5
    ld      [playerY],a

.not_initial:

    ; ignore water physics while pounding
    ld      a,[playerIsPounding]
    cp      0
    ret     nz

    ; prevent sleep and reset fall speed
    xor     a
    ld      [playerSleepTick],a

    ; check if water hit done
    ld      a,[playerWaterHitDone]
    cp      1
    jr      nz,.stop_fall

    ; check ability
    ld      a,[playerCanDive]
    cp      0
    jr      z,.stop_fall

    ; check button for diving
    ld      a,[coreInput]
    and     BUTTON_B
    cp      BUTTON_B
    jr      nz,.stop_fall

    ; animation and speed
    ld      a,PLAYER_ANIMATION_FALL
    ld      [playerAnimation],a

    ld      a,PLAYER_JUMP_SWIM
    ld      [playerFallSpeed],a
    jr      .offset

.stop_fall:
    xor     a
    ld      [playerFallSpeed],a

    ; check swimming offset or initial hit offset
.offset:
    ld      a,[playerWaterHitDone]
    cp      1
    jr      z,.animate_water

    ; initial "splash / hit" offset
    ld      a,[playerWaterTick]
    cp      PLAYER_WATER_OFFSET_MAX; check if we're done
    jr      z,.water_hit_done

    ld      a,[playerWaterTick]
    inc     a
    ld      [playerWaterTick],a

    ; load the y offset for the splash
    ld      hl,playerWaterHitOffsetTable
    ld      b,0
    ld      c,a
    add     hl,bc

    ; set diving / surfacing animation
    cp      14
    jr      c,.down
    ld      a,PLAYER_ANIMATION_SURFACE
    jr      .animate
.down:
    ld      a,PLAYER_ANIMATION_FALL

.animate:
    ld      [playerAnimation],a

    ; load y offset value
    ld      b,[hl]

    ; adjust the depth based on the fall speed
    ld      a,[playerWaterHitDepth]
    cp      15
    jr      nc,.fast
    srl     b; divice depth by 2 if speed was low

    ; apply
.fast:
    ld      a,[playerY]
    add     b
    ld      [playerYOffset],a
    ret

.water_hit_done:
    ld      a,1
    ld      [playerWaterHitDone],a
    ld      a,7; set the value so the first movement after the splash is up
    ld      [playerWaterTick],a
    ret


    ; swimming offset
.animate_water:

    ; load y offset from table
    ld      a,[playerWaterTick]
    ld      hl,playerWaterSwimOffsetTable
    ld      b,0
    ld      c,a
    add     hl,bc
    ld      b,[hl]

    ld      a,[playerWaterTick]
    cp      8
    jr      c,.move_down ; if 4 is greater than the tick, move the player down (0, 1, 2, 3)

.move_up: ; move the player up, 4, 5, 6, 7
    ld      a,[playerY]
    sub     b
    ld      [playerYOffset],a
    ret

.move_down:
    ld      a,[playerY]
    add     b
    ld      [playerYOffset],a
    ret


player_water_timer:

    ; check if in water
    ld      a,[playerInWater]
    cp      0
    jr      z,.done

    ; check if we've finished the initial splash offseting
    ld      a,[playerWaterHitDone]
    cp      0
    jr      z,.bubble

    ; update offset tick
.tick:
    ld      a,[playerWaterTick]
    inc     a
    cp      16
    jr      nz,.done
    jr      c,.done
    xor     a

.done:
    ld      [playerWaterTick],a

.bubble:

    ; check if we're under water
    ld      a,[playerUnderWater]
    cp      0
    ret     z

    ; check if effect counter reached 0
    ld      a,[playerEffectCounter]
    cp      0
    jr      nz,.decrease_counter

    ; reset counter
    call    math_random
    and     %0000_0111
    add     PLAYER_AIR_BUBBLE_INTERVAL
    ld      [playerEffectCounter],a

    ; create air bubble effect above player
    ld      a,[playerYOffset]
    sub     PLAYER_HEIGHT
    add     6
    ld      b,a

    ld      a,[playerDirection]
    cp      PLAYER_DIRECTION_LEFT
    jr      z,.bubble_left

    ld      a,[playerX]
    add     PLAYER_HALF_WIDTH
    jr      .bubble_effect

.bubble_left:
    ld      a,[playerX]
    add     2

.bubble_effect:
    ld      c,a
    ld      a,0
    call    effect_create
    ret


.decrease_counter:
    dec     a
    ld      [playerEffectCounter],a
    ret

