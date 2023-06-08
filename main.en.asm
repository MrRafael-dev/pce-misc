;
; link.ini
; ----------------
; [objects]
; main.o
;
; Build.bat
; ----------------
; ".\wla-huc6280.exe" -o main.o main.en.asm
; ".\wlalink.exe" -v -S -i link.ini main.pce
;

; =========================================================================== ;
; header.s
; =========================================================================== ;

; PC-Engine memory slots.
.MEMORYMAP
	SLOTSIZE $2000
	DEFAULTSLOT 7
	SLOT 0 $0000 "IO"  ; MPR0: $FF (I/O).
	SLOT 1 $2000 "RAM" ; MPR1: $F8 (RAM).
	SLOT 2 $4000 "R0"  ; MPR2: $??.
	SLOT 3 $6000 "R1"  ; MPR3: $??.
	SLOT 4 $8000 "R2"  ; MPR4: $??.
	SLOT 5 $A000 "R3"  ; MPR5: $??.
	SLOT 6 $C000 "R4"  ; MPR6: $??.
	SLOT 7 $E000 "ROM" ; MPR7: $00 (HuCard ROM).
.ENDME

; ROM memory banks.
;
; Each bank has 8KB, being that the lowest possible ROM size.
; To extend it, increase `BANKS` value.
.ROMBANKMAP
	BANKSTOTAL 1
	BANKSIZE $2000
	BANKS 1
.ENDRO

; RAM variables.
.RAMSECTION "variables" BANK 0 SLOT "RAM"
.ENDS

; Fill empty spaces with $FF.
.EMPTYFILL $FF

; =========================================================================== ;
; constants.s
; =========================================================================== ;

.DEFINE MPR_IO 	 $FF ; MPR0: $FF (I/O).
.DEFINE MPR_RAM  $F8 ; MPR1: $F8 (RAM).
.DEFINE MPR_ROM  $00 ; MPR7: $00-$7F (HuCard ROM).

.DEFINE MPR_SRAM $F7 ; MPR?: $7F (Save RAM).

; TAM mapping addresses.
.DEFINE TAM0 1
.DEFINE TAM1 2
.DEFINE TAM2 4
.DEFINE TAM3 8
.DEFINE TAM4 16
.DEFINE TAM5 32
.DEFINE TAM6 64
.DEFINE TAM7 128

.DEFINE ST0_ADDRESS 0 ; Writing a value here is equivalent to `st0`.
.DEFINE ST1_ADDRESS 2 ; Writing a value here is equivalent to `st1`.
.DEFINE ST2_ADDRESS 3 ; Writing a value here is equivalent to `st2`.

.DEFINE TILES256_ADDRESS $1000 ; Tiles 256+.
.DEFINE SATB_ADDRESS     $7F00 ; Start of Sprite Attribute Table (SATB).

.DEFINE IO_PALETTE_RESET    $0400 ; Reset current color palette.
.DEFINE IO_PALETTE_ENTRY_LO $0402 ; Select a palette index : [__] [VV]
.DEFINE IO_PALETTE_ENTRY_HI $0403 ; Select a palette index : [VV] [__]
.DEFINE IO_PALETTE_NEW_LO   $0404 ; Set a new palette color: [__] [VV]
.DEFINE IO_PALETTE_NEW_HI   $0405 ; Set a new palette color: [VV] [__]

.DEFINE IO_IRQ_JOYPAD  $1000
.DEFINE IO_IRQ_DISABLE $1402 ; Disable interrupts (IRQs).
.DEFINE IO_IRQ_REQUEST $1403 ; Request for interrupt (IRQ).

.DEFINE VDC_VRAM_WRITE_ADDRESS  $00 ; Select an VDC offset for reading.
.DEFINE VDC_VRAM_READ_ADDRESS   $01 ; Select an VDC offset for writing.
.DEFINE VDC_VRAM_READ_WRITE     $02 ; Expose VDC offset for read/write.
.DEFINE VDC_CONTROL             $05 ; Controls the VDC.
.DEFINE VDC_BACKGROUND_SCROLL_X $07 ; Controls the background X position.
.DEFINE VDC_BACKGROUND_SCROLL_Y $08 ; Controls the background Y position.
.DEFINE VDC_MEMORY_ACCESS_WIDTH $09 ; Controls the VDC pixel clock.
.DEFINE VDC_VRAM_TO_SATB        $13 ; Transfer data from VRAM to SATB.

; =========================================================================== ;
; functions.s
; =========================================================================== ;

; Returns a bit from a given index from a number.
;
; -
;   value: Number.
;   index: Bit index.
; -
.FUNCTION getBit(value, index) ((value >> (index # 8)) & 1)

; Converts a RGB9 (9-bits) color to PC-Engine format.
;
; -
;   r: Red   ($00-$07)
;   g: Green ($00-$07)
;   b: Blue  ($00-$07)
; -
.FUNCTION RGB9(r, g, b) (((g # 8) * 64) | ((r # 8) * 8) | (b # 8))

; Converts a RGB (24-bits) color to PC-Engine format.
;
; -
;   r: Red   ($00-$FF)
;   g: Green ($00-$FF)
;   b: Blue  ($00-$FF)
; -
.FUNCTION RGB(r, g, b) RGB9(floor(r / 32), floor(g / 32), floor(b / 32))

; Calculate one pixel line for a bitplane. Used on macro `createTile()`.
;
; Unfortunately, WLA-DX doesn't break functions down to lines, which ends up
; making this function look large. But is not that complex, and can be
; studied by copying the line to a new text file and organizing
; each file separately.
;
; -
;   index    : Bitplane index to be calculated. There are only 4 bitplanes.
;   col[0..7]: Pixel column. Each tile must be 8 pixels wide.
; -
.FUNCTION bitPlaneRow(index, col0, col1, col2, col3, col4, col5, col6, col7) ((getBit(col0 # 16, index) * 128) | (getBit(col1 # 16, index) * 64) | (getBit(col2 # 16, index) * 32) | (getBit(col3 # 16, index) * 16) | (getBit(col4 # 16, index) * 8) | (getBit(col5 # 16, index) * 4) | (getBit(col6 # 16, index) * 2) | getBit(col7 # 16, index))

; Tile parameters.
;
; -
;   palette: Palette index ($00-$FF).
;   index  : Tile index. Recommended to use only tiles 256+.
; - 
.FUNCTION tileFlags(palette, index) ((palette * 4096) | index)

; Calculates reference memory address relative to a VRAM sprite.
;
; -
;   value: Memory address.
; -
.FUNCTION spriteAddress(value) (value >> 5)

; Sprite parameters.
;
; -
;   palette: Palette index ($00-$FF).
;   sizeX  : Sprite width (16/32/64).
;   sizeY  : Sprite height (16/32).
;   flipX  : Flip sprite horizontally.
;   flipY  : Flip sprite vertically.
;   fg     : Keep sprite in front or back of the tiles.
; -
.FUNCTION spriteFlags(palette, sizeX, sizeY, flipX, flipY, fg) (((flipY # 2) * 32768) | (0 * 8192) | ((sizeY # 4) * 4096) | ((flipX # 2) * 2048) | (0 * 512) | ((sizeX # 2) * 256) | ((fg # 2) * 128) | (0 * 16) | (palette # 16))

; Interrupt (IRQ) parameters.
; -
;   timer: Timer interrupt request.
;   IRQ1 : IRQ1 (Vblank).
;   IRQ2 : IRQ2 (1 = disabled).
; -
.FUNCTION IRQFlags(timer, IRQ1, IRQ2) ((timer * 4) | (IRQ1 * 2) | IRQ2)

; VDC control parameters.
;
; -
;   RWAutoIncrement      : R/W auto-increment.
;   enableDRAM           : Enable/disable DRAM.
;   displayTerminalOutput: DISP terminal output (pin 27).
;   enableBackground     : Enable/disable background on screen (1 = enabled).
;   enableSprites        : Enable/disable sprites on screen (1 = enabled).
;   vsyncSignal          : VSync I/O signal.
;   hsyncSignal          : HSync I/O signal.
;   vblankSignal         : VBlank.
;   scanlineMatch        : Scanline match.
;   spriteOverflow       : Sprite overflow (16+ sprites on the same scanline).
;   collisionDetection   : Collision detection.
; -
.FUNCTION VDCControlFlags(RWAutoIncrement, enableDRAM, displayTerminalOutput, enableBackground, enableSprites, vsyncSignal, hsyncSignal, vblankSignal, scanlineMatch, spriteOverflow, collisionDetection) ((0 * 16384) | (RWAutoIncrement * 1024) | (enableDRAM * 512) | (displayTerminalOutput * 256) | (enableBackground * 128) | (enableSprites * 64) | (vsyncSignal * 32) | (hsyncSignal * 16) | (vblankSignal * 8) | (scanlineMatch * 4) | (spriteOverflow * 2) | collisionDetection)

; =========================================================================== ;
; extra_instructions.s
; =========================================================================== ;

; Shorthanded version for `st1` and `st2` instructions, accepting a 16-bit
; value on a single line. The endianess is inverted because it must be passed
; as little-endian.
;
; Unfortunately, there's a problem on WLA-DX where passing values from
; functions to `st1` and `st2` throw an error. Implementing these instructions
; manually with their respective opcodes solves the problem.
.MACRO st.data ARGS value
	.db $13, <value
	.db $23, >value
.ENDM

; =========================================================================== ;
; macros.s
; =========================================================================== ;

; Create an tile with a size of 8x8 pixels.
;
; -
;  \[1..64]: Pixel data. Each tile must have 64 pixels total.
; -
.MACRO createTile
	; Enforce macro to receive the exact amount of pixels.
	.IF NARGS != 64
		.FAIL "Tiles must have 64 pixels."
	.ENDIF
	
	; Bitplanes 1/2:
	.db bitPlaneRow(0,  \1, \2, \3, \4, \5, \6, \7, \8), bitPlaneRow(1,  \1, \2, \3, \4, \5, \6, \7, \8)
	.db bitPlaneRow(0,  \9,\10,\11,\12,\13,\14,\15,\16), bitPlaneRow(1,  \9,\10,\11,\12,\13,\14,\15,\16)
	.db bitPlaneRow(0, \17,\18,\19,\20,\21,\22,\23,\24), bitPlaneRow(1, \17,\18,\19,\20,\21,\22,\23,\24)
	.db bitPlaneRow(0, \25,\26,\27,\28,\29,\30,\31,\32), bitPlaneRow(1, \25,\26,\27,\28,\29,\30,\31,\32)
	.db bitPlaneRow(0, \33,\34,\35,\36,\37,\38,\39,\40), bitPlaneRow(1, \33,\34,\35,\36,\37,\38,\39,\40)
	.db bitPlaneRow(0, \41,\42,\43,\44,\45,\46,\47,\48), bitPlaneRow(1, \41,\42,\43,\44,\45,\46,\47,\48)
	.db bitPlaneRow(0, \49,\50,\51,\52,\53,\54,\55,\56), bitPlaneRow(1, \49,\50,\51,\52,\53,\54,\55,\56)
	.db bitPlaneRow(0, \57,\58,\59,\60,\61,\62,\63,\64), bitPlaneRow(1, \57,\58,\59,\60,\61,\62,\63,\64)
	
	; Bitplanes 3/4:
	.db bitPlaneRow(2,  \1, \2, \3, \4, \5, \6, \7, \8), bitPlaneRow(3,  \1, \2, \3, \4, \5, \6, \7, \8)
	.db bitPlaneRow(2,  \9,\10,\11,\12,\13,\14,\15,\16), bitPlaneRow(3,  \9,\10,\11,\12,\13,\14,\15,\16)
	.db bitPlaneRow(2, \17,\18,\19,\20,\21,\22,\23,\24), bitPlaneRow(3, \17,\18,\19,\20,\21,\22,\23,\24)
	.db bitPlaneRow(2, \25,\26,\27,\28,\29,\30,\31,\32), bitPlaneRow(3, \25,\26,\27,\28,\29,\30,\31,\32)
	.db bitPlaneRow(2, \33,\34,\35,\36,\37,\38,\39,\40), bitPlaneRow(3, \33,\34,\35,\36,\37,\38,\39,\40)
	.db bitPlaneRow(2, \41,\42,\43,\44,\45,\46,\47,\48), bitPlaneRow(3, \41,\42,\43,\44,\45,\46,\47,\48)
	.db bitPlaneRow(2, \49,\50,\51,\52,\53,\54,\55,\56), bitPlaneRow(3, \49,\50,\51,\52,\53,\54,\55,\56)
	.db bitPlaneRow(2, \57,\58,\59,\60,\61,\62,\63,\64), bitPlaneRow(3, \57,\58,\59,\60,\61,\62,\63,\64)
.ENDM

; Create an sprite with a size of 16x16 pixels.
;
; -
;  \[1..256]: Pixel data. Each sprite must have 256 pixels total.
; -
.MACRO createSprite
	; Enforce macro to receive the exact amount of pixels.
	.IF NARGS != 256
		.FAIL "Sprites must have 256 pixels."
	.ENDIF
	
	; Bitplane 1:
    .db bitPlaneRow(0,   \9, \10, \11, \12, \13, \14, \15, \16), bitPlaneRow(0,   \1,  \2,  \3,  \4,  \5,  \6,  \7,  \8)
    .db bitPlaneRow(0,  \25, \26, \27, \28, \29, \30, \31, \32), bitPlaneRow(0,  \17, \18, \19, \20, \21, \22, \23, \24)
    .db bitPlaneRow(0,  \41, \42, \43, \44, \45, \46, \47, \48), bitPlaneRow(0,  \33, \34, \35, \36, \37, \38, \39, \40)
    .db bitPlaneRow(0,  \57, \58, \59, \60, \61, \62, \63, \64), bitPlaneRow(0,  \49, \50, \51, \52, \53, \54, \55, \56)
    .db bitPlaneRow(0,  \73, \74, \75, \76, \77, \78, \79, \80), bitPlaneRow(0,  \65, \66, \67, \68, \69, \70, \71, \72)
    .db bitPlaneRow(0,  \89, \90, \91, \92, \93, \94, \95, \96), bitPlaneRow(0,  \81, \82, \83, \84, \85, \86, \87, \88)
    .db bitPlaneRow(0, \105,\106,\107,\108,\109,\110,\111,\112), bitPlaneRow(0,  \97, \98, \99,\100,\101,\102,\103,\104)
    .db bitPlaneRow(0, \121,\122,\123,\124,\125,\126,\127,\128), bitPlaneRow(0, \113,\114,\115,\116,\117,\118,\119,\120)
    .db bitPlaneRow(0, \137,\138,\139,\140,\141,\142,\143,\144), bitPlaneRow(0, \129,\130,\131,\132,\133,\134,\135,\136)
    .db bitPlaneRow(0, \153,\154,\155,\156,\157,\158,\159,\160), bitPlaneRow(0, \145,\146,\147,\148,\149,\150,\151,\152)
    .db bitPlaneRow(0, \169,\170,\171,\172,\173,\174,\175,\176), bitPlaneRow(0, \161,\162,\163,\164,\165,\166,\167,\168)
    .db bitPlaneRow(0, \185,\186,\187,\188,\189,\190,\191,\192), bitPlaneRow(0, \177,\178,\179,\180,\181,\182,\183,\184)
    .db bitPlaneRow(0, \201,\202,\203,\204,\205,\206,\207,\208), bitPlaneRow(0, \193,\194,\195,\196,\197,\198,\199,\200)
    .db bitPlaneRow(0, \217,\218,\219,\220,\221,\222,\223,\224), bitPlaneRow(0, \209,\210,\211,\212,\213,\214,\215,\216)
    .db bitPlaneRow(0, \233,\234,\235,\236,\237,\238,\239,\240), bitPlaneRow(0, \225,\226,\227,\228,\229,\230,\231,\232)
    .db bitPlaneRow(0, \249,\250,\251,\252,\253,\254,\255,\256), bitPlaneRow(0, \241,\242,\243,\244,\245,\246,\247,\248)
	
	; Bitplane 2:
	.db bitPlaneRow(1,   \9, \10, \11, \12, \13, \14, \15, \16), bitPlaneRow(1,   \1,  \2,  \3,  \4,  \5,  \6,  \7,  \8)
    .db bitPlaneRow(1,  \25, \26, \27, \28, \29, \30, \31, \32), bitPlaneRow(1,  \17, \18, \19, \20, \21, \22, \23, \24)
    .db bitPlaneRow(1,  \41, \42, \43, \44, \45, \46, \47, \48), bitPlaneRow(1,  \33, \34, \35, \36, \37, \38, \39, \40)
    .db bitPlaneRow(1,  \57, \58, \59, \60, \61, \62, \63, \64), bitPlaneRow(1,  \49, \50, \51, \52, \53, \54, \55, \56)
    .db bitPlaneRow(1,  \73, \74, \75, \76, \77, \78, \79, \80), bitPlaneRow(1,  \65, \66, \67, \68, \69, \70, \71, \72)
    .db bitPlaneRow(1,  \89, \90, \91, \92, \93, \94, \95, \96), bitPlaneRow(1,  \81, \82, \83, \84, \85, \86, \87, \88)
    .db bitPlaneRow(1, \105,\106,\107,\108,\109,\110,\111,\112), bitPlaneRow(1,  \97, \98, \99,\100,\101,\102,\103,\104)
    .db bitPlaneRow(1, \121,\122,\123,\124,\125,\126,\127,\128), bitPlaneRow(1, \113,\114,\115,\116,\117,\118,\119,\120)
    .db bitPlaneRow(1, \137,\138,\139,\140,\141,\142,\143,\144), bitPlaneRow(1, \129,\130,\131,\132,\133,\134,\135,\136)
    .db bitPlaneRow(1, \153,\154,\155,\156,\157,\158,\159,\160), bitPlaneRow(1, \145,\146,\147,\148,\149,\150,\151,\152)
    .db bitPlaneRow(1, \169,\170,\171,\172,\173,\174,\175,\176), bitPlaneRow(1, \161,\162,\163,\164,\165,\166,\167,\168)
    .db bitPlaneRow(1, \185,\186,\187,\188,\189,\190,\191,\192), bitPlaneRow(1, \177,\178,\179,\180,\181,\182,\183,\184)
    .db bitPlaneRow(1, \201,\202,\203,\204,\205,\206,\207,\208), bitPlaneRow(1, \193,\194,\195,\196,\197,\198,\199,\200)
    .db bitPlaneRow(1, \217,\218,\219,\220,\221,\222,\223,\224), bitPlaneRow(1, \209,\210,\211,\212,\213,\214,\215,\216)
    .db bitPlaneRow(1, \233,\234,\235,\236,\237,\238,\239,\240), bitPlaneRow(1, \225,\226,\227,\228,\229,\230,\231,\232)
    .db bitPlaneRow(1, \249,\250,\251,\252,\253,\254,\255,\256), bitPlaneRow(1, \241,\242,\243,\244,\245,\246,\247,\248)
	
	; Bitplane 3:
	.db bitPlaneRow(2,   \9, \10, \11, \12, \13, \14, \15, \16), bitPlaneRow(2,   \1,  \2,  \3,  \4,  \5,  \6,  \7,  \8)
    .db bitPlaneRow(2,  \25, \26, \27, \28, \29, \30, \31, \32), bitPlaneRow(2,  \17, \18, \19, \20, \21, \22, \23, \24)
    .db bitPlaneRow(2,  \41, \42, \43, \44, \45, \46, \47, \48), bitPlaneRow(2,  \33, \34, \35, \36, \37, \38, \39, \40)
    .db bitPlaneRow(2,  \57, \58, \59, \60, \61, \62, \63, \64), bitPlaneRow(2,  \49, \50, \51, \52, \53, \54, \55, \56)
    .db bitPlaneRow(2,  \73, \74, \75, \76, \77, \78, \79, \80), bitPlaneRow(2,  \65, \66, \67, \68, \69, \70, \71, \72)
    .db bitPlaneRow(2,  \89, \90, \91, \92, \93, \94, \95, \96), bitPlaneRow(2,  \81, \82, \83, \84, \85, \86, \87, \88)
    .db bitPlaneRow(2, \105,\106,\107,\108,\109,\110,\111,\112), bitPlaneRow(2,  \97, \98, \99,\100,\101,\102,\103,\104)
    .db bitPlaneRow(2, \121,\122,\123,\124,\125,\126,\127,\128), bitPlaneRow(2, \113,\114,\115,\116,\117,\118,\119,\120)
    .db bitPlaneRow(2, \137,\138,\139,\140,\141,\142,\143,\144), bitPlaneRow(2, \129,\130,\131,\132,\133,\134,\135,\136)
    .db bitPlaneRow(2, \153,\154,\155,\156,\157,\158,\159,\160), bitPlaneRow(2, \145,\146,\147,\148,\149,\150,\151,\152)
    .db bitPlaneRow(2, \169,\170,\171,\172,\173,\174,\175,\176), bitPlaneRow(2, \161,\162,\163,\164,\165,\166,\167,\168)
    .db bitPlaneRow(2, \185,\186,\187,\188,\189,\190,\191,\192), bitPlaneRow(2, \177,\178,\179,\180,\181,\182,\183,\184)
    .db bitPlaneRow(2, \201,\202,\203,\204,\205,\206,\207,\208), bitPlaneRow(2, \193,\194,\195,\196,\197,\198,\199,\200)
    .db bitPlaneRow(2, \217,\218,\219,\220,\221,\222,\223,\224), bitPlaneRow(2, \209,\210,\211,\212,\213,\214,\215,\216)
    .db bitPlaneRow(2, \233,\234,\235,\236,\237,\238,\239,\240), bitPlaneRow(2, \225,\226,\227,\228,\229,\230,\231,\232)
    .db bitPlaneRow(2, \249,\250,\251,\252,\253,\254,\255,\256), bitPlaneRow(2, \241,\242,\243,\244,\245,\246,\247,\248)
	
	; Bitplane 4:
    .db bitPlaneRow(3,   \9, \10, \11, \12, \13, \14, \15, \16), bitPlaneRow(3,   \1,  \2,  \3,  \4,  \5,  \6,  \7,  \8)
    .db bitPlaneRow(3,  \25, \26, \27, \28, \29, \30, \31, \32), bitPlaneRow(3,  \17, \18, \19, \20, \21, \22, \23, \24)
    .db bitPlaneRow(3,  \41, \42, \43, \44, \45, \46, \47, \48), bitPlaneRow(3,  \33, \34, \35, \36, \37, \38, \39, \40)
    .db bitPlaneRow(3,  \57, \58, \59, \60, \61, \62, \63, \64), bitPlaneRow(3,  \49, \50, \51, \52, \53, \54, \55, \56)
    .db bitPlaneRow(3,  \73, \74, \75, \76, \77, \78, \79, \80), bitPlaneRow(3,  \65, \66, \67, \68, \69, \70, \71, \72)
    .db bitPlaneRow(3,  \89, \90, \91, \92, \93, \94, \95, \96), bitPlaneRow(3,  \81, \82, \83, \84, \85, \86, \87, \88)
    .db bitPlaneRow(3, \105,\106,\107,\108,\109,\110,\111,\112), bitPlaneRow(3,  \97, \98, \99,\100,\101,\102,\103,\104)
    .db bitPlaneRow(3, \121,\122,\123,\124,\125,\126,\127,\128), bitPlaneRow(3, \113,\114,\115,\116,\117,\118,\119,\120)
    .db bitPlaneRow(3, \137,\138,\139,\140,\141,\142,\143,\144), bitPlaneRow(3, \129,\130,\131,\132,\133,\134,\135,\136)
    .db bitPlaneRow(3, \153,\154,\155,\156,\157,\158,\159,\160), bitPlaneRow(3, \145,\146,\147,\148,\149,\150,\151,\152)
    .db bitPlaneRow(3, \169,\170,\171,\172,\173,\174,\175,\176), bitPlaneRow(3, \161,\162,\163,\164,\165,\166,\167,\168)
    .db bitPlaneRow(3, \185,\186,\187,\188,\189,\190,\191,\192), bitPlaneRow(3, \177,\178,\179,\180,\181,\182,\183,\184)
    .db bitPlaneRow(3, \201,\202,\203,\204,\205,\206,\207,\208), bitPlaneRow(3, \193,\194,\195,\196,\197,\198,\199,\200)
    .db bitPlaneRow(3, \217,\218,\219,\220,\221,\222,\223,\224), bitPlaneRow(3, \209,\210,\211,\212,\213,\214,\215,\216)
    .db bitPlaneRow(3, \233,\234,\235,\236,\237,\238,\239,\240), bitPlaneRow(3, \225,\226,\227,\228,\229,\230,\231,\232)
    .db bitPlaneRow(3, \249,\250,\251,\252,\253,\254,\255,\256), bitPlaneRow(3, \241,\242,\243,\244,\245,\246,\247,\248)
.ENDM

; =========================================================================== ;
; main.asm
; =========================================================================== ;

; Organize data offset to the beginning of the ROM.
.BANK 0
.ORG $0000

; System initialization subroutine.
SUBROUTINE_RESET:
	; CPU initializaion.
	; -
	;   Block interrupts (IRQs).
	;   Switch CPU to "fast mode" (7.16HMz).
	;   Disable CPU's decimal mode.
	; -
	sei
	csh
	cld
	
	; Mapping / bank switching.
	; -
	;   MPR1 -> I/O ($FF)
	;   MPR2 -> RAM ($F8)
	; -
	lda #MPR_IO
	tam #TAM0
	lda #MPR_RAM
	tam #TAM1
	
	; Initalize stack (stack pointer) on I/O mapper ($FF).
	ldx #MPR_IO
	txs
	
	; Disable interrupts (IRQs).
	; -
	;   timer = 1
	;   IRQ1  = 1
	;   IRQ2  = 1
	; - 
	lda #IRQFlags(1, 1, 1)
	sta IO_IRQ_DISABLE
	
	; Configure VDC.
	; -
	;   enableBackground = 1
	;   enableSprites    = 1
	; -
	st0 #VDC_CONTROL
	st.data #VDCControlFlags(0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0)
	
	; Configure background size (32 x 32).
	st0 #VDC_MEMORY_ACCESS_WIDTH
	st.data #0
	
	; Configure background scroll.
	st0 #VDC_BACKGROUND_SCROLL_X
	st.data #0
	st0 #VDC_BACKGROUND_SCROLL_Y
	st.data #0
	
	; Loop used to load a palette to VRAM to be used by tiles.
	; It will process 2 bytes at a time.
	;
	; Notice how some instructions can be labeled with "-" and "+" on their
	; sides. This is used as a referente to assembler, which can optimize the
	; loop with a relative jump using the `bra` instruction.
	@loadTilePalette:
		ldx #0
		ldy #0
		
		; Select palette index to be written.
		;
		; The `stz` instruction sets the high-byte to 0, while the X register
		; is used as an iterator.
	  - stx IO_PALETTE_ENTRY_LO
		stz IO_PALETTE_ENTRY_HI
		
		; Move first byte from palette:
		lda PAL_PICO8.w, y
		sta IO_PALETTE_NEW_LO
		iny

		; Move second byte from palette:
		lda PAL_PICO8.w, y
		sta IO_PALETTE_NEW_HI
		iny
		
		; Each palette has 2 bytes for each color,
		; and this loop process 2 bytes at a time.
		;
		; This gives 16 iterations.
		inx
		cpx #16
		bne -
	; end
	
	; Loop used to load a palette to VRAM to be used by sprites.
	; It will process 2 bytes at a time.
	@loadSpritePalette:
		ldx #0
		ldy #0
		
		; Select palette index to be written.
		;
		; This time, the high-byte will be set to 1.
	  - stx IO_PALETTE_ENTRY_LO
		lda #1
		sta IO_PALETTE_ENTRY_HI
		
		; Move first byte from palette:
		lda PAL_PICO8.w, y
		sta IO_PALETTE_NEW_LO
		iny
		
		; Move second byte from palette:
		lda PAL_PICO8.w, y
		sta IO_PALETTE_NEW_HI
		iny
		
		; Each palette has 2 bytes for each color,
		; and this loop process 2 bytes at a time.
		;
		; This gives 16 iterations.
		inx
		cpx #16
		bne -
	; end
		
	; Select read/write register to address $1000.
	; This is the section where tiles 256+ are stored.
	st0 #VDC_VRAM_WRITE_ADDRESS
	st.data #TILES256_ADDRESS
	
	
	; Enable writing on the selected register above.
	;
	; While enabled, it will be possible to read/write data using:
	; - `st1 / st2`
	; - `st.data`*
	; - `sta ST1_ADDRESS.w / sta ST2_ADDRESS.w`
	;
	; Subsequent reads/writes increment the offset automatically (+1).
	;
	; * Notice: `st.data` IS NOT A NATIVE INSTRUCTION. This "instruction" is
	;           a macro, which look like a instruction for convenience.
	st0 #VDC_VRAM_READ_WRITE
	
	; Loop used to load a tile into VRAM.
	; It will process 2 bytes at a time.
	@loadTileGraphics:
		ldx #0
		ldy #0

		; Move first tile byte:
		;
		; Notice how `ST1_ADDRESS` and `STA2_ADDRESS` has `.w` in the end.
		; This is used so WLA-DX interpret these values as 16-bit.
		;
		; Because `ST1_ADDRESS` and `ST2_ADDRESS` has values similar to
		; zero-page as seem on a standard 6502, removing the `.w` will make
		; WLA-DX use the addressing mode of zero-page instead of absolute.
		; Adding `.w` in the end solves this problem.
	  - lda GFX_TILE.w, y
		sta ST1_ADDRESS.w
		iny
		
		; Move second byte from tile:
		lda GFX_TILE.w, y
		sta ST2_ADDRESS.w
		iny
		
		; Each tile has 32 bytes, 
		; and this loop process 2 bytes at a time.
		;
		; This gives 16 iterations.
		inx
		cpx #16
		bne -
	; end
	
	; Select read/write register to address $3000.
	; This section will contain sprite graphics.
	;
	; Sprites can be saved anywhere into memory.
	; This one was picked out of personal choice.
	;
	; Remember to point this exact same memory address later on
	; SATB (Sprite Attribute Table).
	st0 #VDC_VRAM_WRITE_ADDRESS
	st.data #$3000
	st0 #VDC_VRAM_READ_WRITE
	
	; Loop usado para carregar um sprite na VRAM.
	; São processados 2 bytes de cada vez.
	
	; Loop used to load a sprite into VRAM.
	; It will process 2 bytes at a time.
	@loadSpriteGraphics:
		ldx #0
		ldy #0
		
		; Move first byte from tile:
	  - lda GFX_SPRITE.w, y
		sta ST1_ADDRESS.w
		iny
		
		; Move second byte from tile:
		lda GFX_SPRITE.w, y
		sta ST2_ADDRESS.w
		iny
		
		; Each sprite has 128 bytes, 
		; and this loop process 2 bytes at a time.
		;
		; This gives 64 iterations.
		inx
		cpx #64
		bne -
	; end
	
	; Select read/write register to address $7F00.
	; This is the recommended section to transfer the SABT (Sprite Attribute 
	; Table) to it's special memory section.
	st0 #VDC_VRAM_WRITE_ADDRESS
	st.data #SATB_ADDRESS
	st0 #VDC_VRAM_READ_WRITE
		
	; Loop used to load SATB (Sprite Attribute Table) into VRAM.
	; It will process 2 bytes at a time.
	@loadSpriteAttributeTable:
		ldx #0
		ldy #0
		
		; Move first byte from tile:
	  - lda GFX_SPRITE_ATTRIBUTE_TABLE.w, y
		sta ST1_ADDRESS.w
		iny
		
		; Move second byte from tile:
		lda GFX_SPRITE_ATTRIBUTE_TABLE.w, y
		sta ST2_ADDRESS.w
		iny
		
		; Each sprite attribute has 8 bytes,
		; and this loop process 2 bytes at a time.
		;
		; The SATB (Sprite Attribute Table) has 64 attributes total.
		; This gives 256 iterações.
		;
		; The X register is incremented up to 255. After that, it's value will
		; overflow and will turn back to 0, thus giving 256 iterations.
		inx
		cpx #0
		bne -
	; end
	
	; Transfer SATB to it's special memory section.
	st0 #VDC_VRAM_TO_SATB
	st.data #SATB_ADDRESS
	
	; Add a tile on screen as an example.
	;
	; While the screen starts at $0000, writing on this address will create
	; artifacts on other tiles. This happens because this memory section is
	; shared between tiles/palettes, which ends up creating
	; a data conflict between them.
	;
	; Writing on a few offsets ahead solves this problem.
	st0 #VDC_VRAM_WRITE_ADDRESS
	st.data #32
	st0 #VDC_VRAM_READ_WRITE
	st.data tileFlags(0, 256)

	jmp SUBROUTINE_START
; end

; Example palette. This is the PICO-8 palette:
; https://lospec.com/palette-list/pico-8
;
; Each palette is formed by 16 colors and has 256 bytes of size.
; Colors use the GGGRRRBBB format, and use 2 bytes each.
;
; The function `RGB9()` and `RGB()` can be used to create the colors.
PAL_PICO8:
	;         [0,0]             [1,0]             [0,1]             [1,1]
	;     # 0 [0,0]         # 1 [0,0]         # 2 [0,0]         # 3 [0,0]
	.word RGB($00,$00,$00), RGB($1D,$2B,$53), RGB($75,$25,$53), RGB($00,$87,$51)
	
	;         [0,0]             [1,0]             [0,1]             [1,1]
	;     # 4 [1,0]         # 5 [1,0]         # 6 [1,0]         # 7 [1,0]
	.word RGB($AB,$52,$36), RGB($5F,$57,$4F), RGB($C2,$C3,$C7), RGB($FF,$F1,$E8)
	
	;         [0,0]             [1,0]             [0,1]             [1,1]
	;     # 8 [0,1]         # 9 [0,1]         #10 [0,1]         #11 [0,1]
	.word RGB($FF,$00,$4D), RGB($FF,$A3,$00), RGB($FF,$EC,$27), RGB($00,$E4,$36)
	
	;         [0,0]             [1,0]             [0,1]             [1,1]
	;     #12 [1,1]         #13 [1,1]         #14 [1,1]         #15 [1,1]
	.word RGB($29,$AD,$FF), RGB($86,$76,$9C), RGB($FF,$77,$A8), RGB($FF,$CC,$AA)
; end

; Example tile. This is from the RogueDB32 asset pack, by SpiderDave:
; https://opengameart.org/content/roguedb32
;
; Each tile is formed by 4 bitplanes and has 32 bytes of size.
; Tiles has 8x8 of size. Each pixel references a palette index.
;
; Tiles use palettes saved at banks 0-255.
;
; The macro `createTIle()` can be used to create the tiles.
GFX_TILE:
	createTile                         \
		 3, 11, 11, 11,  0,  0,  2,  0 \
		 0, 11,  3,  3,  3,  0,  0,  2 \
		 0,  3,  1, 15,  1,  0,  0,  2 \
		 0,  4, 15, 15, 15,  0,  0,  2 \
		 3, 11, 11, 11, 11,  3, 15,  2 \
		15, 13, 13,  7, 13,  0,  0,  2 \
		 0,  3,  3,  3,  3,  0,  0,  2 \
		 0,  2,  0,  0,  2,  0,  2,  0
	; end
; end

; Example sprite. This is from the Classic Hero asset pack, by GrafkKid:
; https://opengameart.org/content/classic-hero
;
; Each sprite is formed by 4 bitplanes and has 128 bytes of size.
; Sprites has 16x16 of size. Each pixel references a palette index.
;
; Tiles use palettes saved at banks 256-511.
;
; The macro `createSprite()` can be used to create the sprites.
GFX_SPRITE:
	createSprite                                                       \
		 0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  0,  0,  0,  0,  0 \
		 0,  0,  0,  0,  0,  1, 15, 15, 15, 15, 15,  1,  0,  0,  0,  0 \
		 0,  0,  0,  0,  1, 15, 15, 15, 15, 15, 15, 15,  1,  0,  0,  0 \
		 0,  0,  0,  0,  1, 15, 15, 15,  1, 15, 15,  1,  1,  0,  0,  0 \
		 0,  0,  0,  0,  1, 15, 15, 15,  1, 15, 15,  1,  1,  0,  0,  0 \
		 0,  0,  0,  0,  1, 15, 15, 15, 15, 15, 15, 15,  1,  0,  0,  0 \
		 0,  0,  0,  0,  1, 14, 15, 15, 15, 15, 15, 14,  1,  0,  0,  0 \
		 0,  0,  0,  0,  0,  1, 14, 14, 14, 14, 14,  7,  7,  1,  0,  0 \
		 0,  0,  0,  0,  1, 12, 12, 12, 12, 12, 12,  7,  7,  1,  0,  0 \
		 0,  0,  0,  0,  1,  3, 12, 12, 12, 12, 12,  3,  1,  0,  0,  0 \
		 0,  0,  0,  0,  0,  1,  3, 12, 12, 12,  3,  1,  0,  0,  0,  0 \
		 0,  0,  0,  1,  1,  1,  2,  2,  2,  2,  2,  2,  1,  1,  1,  0 \
		 0,  0,  0,  1,  4,  2,  2,  1,  1,  1,  1,  2,  9,  9,  1,  0 \
		 0,  0,  0,  1,  4,  1,  1,  0,  0,  0,  1,  9,  4,  1,  0,  0 \
		 0,  0,  0,  1,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  0,  0 \
		 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
	; end
; end


; Example SATB (Sprite Atrribute Table).
;
; It's only necessary to copy this value to VRAM once,
; preferably on address $7F00.
;
; There are 64 sprites, and each attribute table has 8 bytes of size.
; The SATB (Sprite Attribute Table) has 512 bytes total.
;
; The macros `spriteAddress()` and `spriteFlags()` can be used to
; configure the sprites.
GFX_SPRITE_ATTRIBUTE_TABLE:
	;     y ; x ; address(value)      ; flags(palette, sizeX, sizeY, flipX, flipY, fg)                        
	.word 80, 80, spriteAddress($3000), spriteFlags(0, 0, 0, 0, 0, 0)
	
	; instruction that copies the SATB (Sprite Attribute Table) frm VRAM to
	; it's special memory section will always move 512 bytes, regardless if
	; they're all being used or not.
	;
	; In order not to copy "garbage data" from anywhere of ROM, we can
	; fill the rest of the attributes with an empty space...
	.REPEAT 63
		.word 0, 0, 0, 0
	.ENDR
; end

; Subroutine responsible for the game loop.
SUBROUTINE_START:
  - lda $2000
	adc #1
	sta $2000
	bra -
; end

; The last bytes of ROM must point to the initialization subroutine.
;
; The code jumps during the initialization and a "soft reset".
.ORG $1FFE
.word SUBROUTINE_RESET

; EOF
