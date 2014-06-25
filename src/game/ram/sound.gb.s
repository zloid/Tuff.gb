SECTION "SoundRam",WRAM0[$CB00]; must be aligned at 256 bytes for soundChannelState


; Constants -------------------------------------------------------------------
INCLUDE     "../data/bin/sounds.def.gb.s"

; Sound State Buffer ----------------------------------------------------------
soundChannelState:      DS 16; 4 byte per channel
                             ; sound ID, active priority, action flag, initial sound mode

soundEffectQueue:       DS 32; maximum of 4 active sounds, 8 bytes per sound
                             ; ID,Mode,Length,Channel,Priority,X,X,X

; Flag for halting the advancement of active sounds during force update -------
soundForceUpdate:       DB

