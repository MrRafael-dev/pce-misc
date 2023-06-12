;
; link.ini
; ----------------
; [objects]
; main.o
;
; Build.bat
; ----------------
; ".\wla-huc6280.exe" -o main.o main.asm
; ".\wlalink.exe" -v -S -i link.ini main.pce
;

; =========================================================================== ;
; header.s
; =========================================================================== ;

; Slots de memória do PC-Engine.
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

; Bancos de memória da ROM.
;
; Cada banco possui 8KB, tornando este o menor tamanho de ROM possível.
; Para extender o tamanho da ROM, aumente o valor de `BANKS`.
.ROMBANKMAP
	BANKSTOTAL 1
	BANKSIZE $2000
	BANKS 1
.ENDRO

; Variáveis definidas na RAM.
.RAMSECTION "variables" BANK 1 SLOT "RAM"
	Variable.Gamepad: word
	Variable.PlayerX: db
	Variable.PlayerY: db
.ENDS

; Preencher espaços vazios com $FF.
.EMPTYFILL $FF

; =========================================================================== ;
; constants.s
; =========================================================================== ;

.DEFINE MPR_IO 	 $FF ; MPR0: $FF (I/O).
.DEFINE MPR_RAM  $F8 ; MPR1: $F8 (RAM).
.DEFINE MPR_ROM  $00 ; MPR7: $00-$7F (HuCard ROM).

.DEFINE MPR_SRAM $F7 ; MPR?: $7F (Save RAM).

; Endereços de mapeamento usados pela instrução TAM.
.DEFINE TAM0 1
.DEFINE TAM1 2
.DEFINE TAM2 4
.DEFINE TAM3 8
.DEFINE TAM4 16
.DEFINE TAM5 32
.DEFINE TAM6 64
.DEFINE TAM7 128

.DEFINE IO_TIMER_COUNTER $0C00
.DEFINE IO_TIMER_CONTROL $0C01

.DEFINE ST0_ADDRESS 0 ; Escrever um valor neste endereço equivale ao `st0`. 
.DEFINE ST1_ADDRESS 2 ; Escrever um valor neste endereço equivale ao `st1`. 
.DEFINE ST2_ADDRESS 3 ; Escrever um valor neste endereço equivale ao `st2`. 

.DEFINE TILES256_ADDRESS $1000 ; Tiles 256+.
.DEFINE SATB_ADDRESS     $7F00 ; Inicío da Sprite Attribute Table (SATB).

.DEFINE IO_PALETTE_RESET    $0400 ; Reseta a paleta de cores atual.
.DEFINE IO_PALETTE_ENTRY_LO $0402 ; Seleciona um índice de paleta: [__] [VV]
.DEFINE IO_PALETTE_ENTRY_HI $0403 ; Seleciona um índice de paleta: [VV] [__]
.DEFINE IO_PALETTE_NEW_LO   $0404 ; Define uma nova cor na paleta: [__] [VV]
.DEFINE IO_PALETTE_NEW_HI   $0405 ; Define uma nova cor na paleta: [VV] [__]

.DEFINE IO_VDC_PORT    $0000 ; Porta de vídeo (VDC).
.DEFINE IO_IRQ_JOYPAD  $1000 ; Porta dos controles.
.DEFINE IO_IRQ_PORT    $1400 ; Porta das interrupts (IRQs).
.DEFINE IO_IRQ_DISABLE $1402 ; Desativa interrupts (IRQs).
.DEFINE IO_IRQ_REQUEST $1403 ; Requisita interrupt (IRQ).

.DEFINE VDC_VRAM_WRITE_ADDRESS  $00 ; Seleciona um offset da VDC para leitura.
.DEFINE VDC_VRAM_READ_ADDRESS   $01 ; Seleciona um offset da VDC para escrita.
.DEFINE VDC_VRAM_READ_WRITE     $02 ; Expõe o offset da VDC para ler/escrever.

.DEFINE VDC_CONTROL               $05 ; [ CR] Controla a VDC.
.DEFINE VDC_SCANLINE_DETECTION    $06 ; [RCR] 
.DEFINE VDC_BACKGROUND_SCROLL_X   $07 ; [BXR] Controla a posição X do background.
.DEFINE VDC_BACKGROUND_SCROLL_Y   $08 ; [BYR] Controla a posição Y do background.
.DEFINE VDC_MEMORY_ACCESS_WIDTH   $09 ; [MWR] Controle do clock de pixels da VDC.
.DEFINE VDC_HSYNC                 $0A ; [HSR]
.DEFINE VDC_HDISPLAY              $0B ; [HDR] Controle do tamanho do display horizontal.
.DEFINE VDC_VSYNC                 $0C ; [VPR]
.DEFINE VDC_VDISPLAY              $0D ; [BDW] Controle do tamanho do display vertical.
.DEFINE VDC_VDISPLAY_END_POSITION $0E ; [BCR]

.DEFINE VDC_BLOCK_TRANSFER_CONTROL             $0F ; [ DCR]
.DEFINE VDC_BLOCK_TRANSFER_SOURCE_ADDRESS      $10 ; [SOUR]
.DEFINE VDC_BLOCK_TRANSFER_DESTINATION_ADDRESS $11 ; [DESR]
.DEFINE VDC_BLOCK_TRANSFER_LENGTH              $12 ; [LENR]
.DEFINE VDC_VRAM_TO_SATB                       $13 ; [SATB] Transfere dados da VRAM para a SATB.

.DEFINE VDC_SELECTED_REGISTER $20F7

; =========================================================================== ;
; functions.s
; =========================================================================== ;

; Retorna o valor de um bit no índice do número especificado.
;
; -
;   value: Número.
;   index: Índice do bit.
; -
.FUNCTION getBit(value, index) ((value >> (index # 8)) & 1)

; Converte uma cor RGB9 (9-bits) para o formato do PC-Engine.
;
; -
;   r: Red   ($00-$07)
;   g: Green ($00-$07)
;   b: Blue  ($00-$07)
; -
.FUNCTION RGB9(r, g, b) (((g # 8) * 64) | ((r # 8) * 8) | (b # 8))

; Converte uma cor RGB (24-bits) para o formato do PC-Engine.
;
; -
;   r: Red   ($00-$FF)
;   g: Green ($00-$FF)
;   b: Blue  ($00-$FF)
; -
.FUNCTION RGB(r, g, b) RGB9(floor(r / 32), floor(g / 32), floor(b / 32))

; Calcula uma linha de pixels para um bitplane. Usada na macro `createTile()`.
;
; Infelizmente, o WLA-DX não permite quebrar as funções em linhas, o que
; acaba fazendo esta função parecer gigante. Mas não é tão complexa, e pode ser
; estudada copiando a linha para outro arquivo de texto e organizando
; cada parte separadamente.
;
; -
;   index    : Índice do bitplane a ser calculado. Só existem 4 bitplanes.
;   col[0..7]: Colunas de pixels. Cada tile deve possuir 8 pixels de largura.
; -
.FUNCTION bitPlaneRow(index, col0, col1, col2, col3, col4, col5, col6, col7) ((getBit(col0 # 16, index) * 128) | (getBit(col1 # 16, index) * 64) | (getBit(col2 # 16, index) * 32) | (getBit(col3 # 16, index) * 16) | (getBit(col4 # 16, index) * 8) | (getBit(col5 # 16, index) * 4) | (getBit(col6 # 16, index) * 2) | getBit(col7 # 16, index))

; Parâmetros de um tile.
;
; -
;   palette: Índice da paleta ($00-$FF).
;   index  : Índice do tile. Recomenda-se utilizar apenas os tiles 256+.
; - 
.FUNCTION tileFlags(palette, index) ((palette * 4096) | index)

; Calcula o endereço de memória de referência relativo ao de um sprite na VRAM.
;
; -
;   value: Endereço de memória.
; -
.FUNCTION spriteAddress(value) (value >> 5)

; Parâmetros de um sprite.
;
; -
;   palette: Índice da paleta ($00-$FF).
;   sizeX  : Largura do sprite (16/32/64).
;   sizeY  : Altura do sprite (16/32).
;   flipX  : Inverter sprite horizontalmente.
;   flipY  : Inverter sprite verticalmente.
;   fg     : Manter sprite na frente ou atrás dos tiles.
; -
.FUNCTION spriteFlags(palette, sizeX, sizeY, flipX, flipY, fg) (((flipY # 2) * 32768) | (0 * 8192) | ((sizeY # 4) * 4096) | ((flipX # 2) * 2048) | (0 * 512) | ((sizeX # 2) * 256) | ((fg # 2) * 128) | (0 * 16) | (palette # 16))

; Calcula o endereço de memória de um atributo de sprites dentro
; da SATB (Sprite Attribute Table) no índice especificado.
;
; A SATB (Sprite Attribute Table) possui 64 sprites, todos com tamanho fixo.
; Desta forma, contanto que o endereço de memória onde ela estiver localizada
; for o mesmo, é possível utilizar esta função para alterar valores
; individualmente para cada sprite.
;
; -
;   index: Índice do atributo.
; -
.FUNCTION spriteAttributeIndex(index) (SATB_ADDRESS + (8 * (index # 64)))

; Parâmetros de interrupts (IRQs).
; -
;   timer: Timer interrupt request.
;   IRQ1 : IRQ1 (Vblank).
;   IRQ2 : IRQ2 (1 = disabled).
; -
.FUNCTION IRQFlags(timer, IRQ1, IRQ2) ((timer * 4) | (IRQ1 * 2) | IRQ2)

; Parâmetros de controle da VDC.
;
; -
;   RWAutoIncrement      : R/W auto-increment.
;   enableDRAM           : Ativa/desativa a DRAM.
;   displayTerminalOutput: Saída do terminal DISP (pino 27).
;   enableBackground     : Ativa/desativa o background na tela (1 = ativado).
;   enableSprites        : Ativa/desativa sprites na tela (1 = ativado).
;   vsyncSignal          : Sinal de I/O da VSync.
;   hsyncSignal          : Sinal de I/O da HSync.
;   vblankSignal         : VBlank.
;   scanlineMatch        : Scanline match.
;   spriteOverflow       : Sprite overflow (16+ sprites na mesma scanline).
;   collisionDetection   : Detecção de colisão.
; -
.FUNCTION VDCControlFlags(RWAutoIncrement, enableDRAM, displayTerminalOutput, enableBackground, enableSprites, vsyncSignal, hsyncSignal, vblankSignal, scanlineMatch, spriteOverflow, collisionDetection) ((0 * 16384) | (RWAutoIncrement * 1024) | (enableDRAM * 512) | (displayTerminalOutput * 256) | (enableBackground * 128) | (enableSprites * 64) | (vsyncSignal * 32) | (hsyncSignal * 16) | (vblankSignal * 8) | (scanlineMatch * 4) | (spriteOverflow * 2) | collisionDetection)

; Parâmetros de controle do tamanho do display horizontal.
;
; Estes parâmetros não possuem documentação amplamente disponível, mas podem
; ser melhor compreendidos através deste link:
; http://archaicpixels.com/HuC6270#.240B_-_HDR_-_Horizontal_Display_Register
;
; -
;   width: Ciclo de tiles exibidos por linha.
;   end  : Final da exibição de tiles, em ciclos.
; -
.FUNCTION horizontalDisplayFlags(width, end) (((end # 128) * 256) | (0 * 128) | (width # 128))

; =========================================================================== ;
; extra_instructions.s
; =========================================================================== ;

; Resume as instruções `st1` e `st2`, aceitando um valor de 16-bits
; em uma única linha. A ordem dos valores é invertida pois são passados em 
; little-endian.
;
; Infelizmente, existe um problema no WLA-DX onde passar valores de funções
; para as instruções `st1` e `st2` acusam um erro. Implementar as instruções
; manualmente com seus respectivos opcodes resolve este problema.
.MACRO st.data ARGS value
	.db $13, <value
	.db $23, >value
.ENDM

; =========================================================================== ;
; macros.s
; =========================================================================== ;

; Cria um tile de 8x8 pixels.
;
; -
;  \[1..64]: Dados de pixels. Cada tile deve conter 64 pixels no total.
; -
.MACRO createTile
	; Reforçar que a macro receba exatamente a quantidade exata de pixels.
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

; Cria um sprite de 16x16 pixels.
;
; -
;  \[1..256]: Dados de pixels. Cada sprite deve conter 256 pixels no total.
; -
.MACRO createSprite
	; Reforçar que a macro receba exatamente a quantidade exata de pixels.
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

; Organizar offset de dados para o início da ROM.
.BANK 0
.ORG $0000

; Subrotina de inicialização do console.
SUBROUTINE_RESET:
	; Inicialização da CPU.
	; -
	;   Impedir interrupts (IRQs).
	;   Alternar CPU para o "fast mode" (7.16HMz).
	;   Desativa o modo decimal da CPU.
	; -
	sei
	csh
	cld
	
	; Mapeamento / bank switching.
	; -
	;   MPR1 -> I/O ($FF)
	;   MPR2 -> RAM ($F8)
	; -
	lda #MPR_IO
	tam #TAM0
	lda #MPR_RAM
	tam #TAM1
	
	; Inicializar pilha (stack pointer) no mapeamento de I/O ($FF).
	ldx #MPR_IO

	; Desativar interrupts (IRQs).
	; -
	;   timer = 1
	;   IRQ1  = 1
	;   IRQ2  = 1
	; - 
	lda #IRQFlags(1, 1, 1)
	sta IO_IRQ_DISABLE
	
	st0 #VDC_SCANLINE_DETECTION
	st.data #$0000
	
	st0 #VDC_BACKGROUND_SCROLL_X
	st.data #$0000
	
	st0 #VDC_BACKGROUND_SCROLL_Y
	st.data #$0000
	
	st0 #VDC_MEMORY_ACCESS_WIDTH
	st.data #$1000
	
	st0 #VDC_HSYNC
	st.data #$0202
	
	; Configurar exibição horizontal dos tiles.
	;
	; -
	;   width = 32
	;   end   = 32
	; -
	st0 #VDC_HDISPLAY
	st.data #horizontalDisplayFlags(32, 32)
	
	st0 #VDC_VSYNC
	st.data #$070D
	
	st0 #VDC_VDISPLAY
	st.data #$DF00
	
	st0 #VDC_VDISPLAY_END_POSITION
	st.data #$0300

; ========
; @todo
; ========
;	st0 #VDC_BLOCK_TRANSFER_CONTROL
;	st.data #GFX_SPRITE_ATTRIBUTE_TABLE
;	
;	; Transferir SATB para a posição especial de memória.
;	st0 #VDC_VRAM_TO_SATB
;	st.data #SATB_ADDRESS
; ========

	; Configurar VDC.
	; -
	;   enableBackground = 1
	;   enableSprites    = 1
	; -
	st0 #VDC_CONTROL
	st.data #VDCControlFlags(0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0)
	
	; Inicialização dos controles.
	;
	; Os controles são inicializados salvando `1` e `3` na
	; região de memória `$1000`. Os valores precisam ser escritos com um
	; período de delay.
	@initializeJoypad:
		clx
		cly
		
		; Salvar valores.
		lda #1
		sta IO_IRQ_JOYPAD
		lda #3
		sta IO_IRQ_JOYPAD
		
		; O período de delay deve durar aproximadamente 9 ciclos.
		; `ina` dura 2 ciclos, e `nop` dura 1 ciclo.
		ina
		ina
		ina
		ina
		nop
	; end
	
	; Loop usado para carregar uma paleta na VRAM para os tiles.
	; São processados 2 bytes de cada vez.
	;
	; Note que algumas instruções podem ser rotuladas com `-` e `+` ao lado
	; delas. Isto é usado como referência para o assembler, que pode otimizar
	; o loop com um salto relativo utilizando a instrução `bra`.
	@loadTilePalette:
		clx
		cly
		
		; Selecionar índice da paleta a ser escrita.
		;
		; A instrução `stz` define o high-byte do índice para 0, enquanto o 
		; registrador X é utilizado como iterador.
	  - stx IO_PALETTE_ENTRY_LO
		stz IO_PALETTE_ENTRY_HI
		
		; Mover primeiro byte da paleta:
		lda PAL_PICO8.w, y
		sta IO_PALETTE_NEW_LO
		iny
		
		; Mover segundo byte da paleta:
		lda PAL_PICO8.w, y
		sta IO_PALETTE_NEW_HI
		iny
		
		; Uma paleta possui 2 bytes para cada cor, 
		; e este loop processa 2 bytes de cada vez.
		;
		; Isso dá 16 iterações.
		inx
		cpx #16
		bne -
	; end
	
	; Loop usado para carregar uma paleta na VRAM para os sprites.
	; São processados 2 bytes de cada vez.
	@loadSpritePalette:
		clx
		cly
		
		; Selecionar índice da paleta a ser escrita.
		;
		; Desta vez, o high-byte será definido para 1.
	  - stx IO_PALETTE_ENTRY_LO
		lda #1
		sta IO_PALETTE_ENTRY_HI
		
		; Mover primeiro byte da paleta:
		lda PAL_PICO8.w, y
		sta IO_PALETTE_NEW_LO
		iny
		
		; Mover segundo byte da paleta:
		lda PAL_PICO8.w, y
		sta IO_PALETTE_NEW_HI
		iny
		
		; Uma paleta possui 2 bytes para cada cor, 
		; e este loop processa 2 bytes de cada vez.
		;
		; Isso dá 16 iterações.
		inx
		cpx #16
		bne -
	; end
	
	; Selecionar registro para leitura/escrita no endereço $1000.
	; Esta é a região dos tiles 256+.
	st0 #VDC_VRAM_WRITE_ADDRESS
	st.data #TILES256_ADDRESS
	
	; Ativar modo de escrita no registro de leitura/escrita selecionado acima.
	;
	; Enquanto ativado, será possível ler/escrever dados utilizando:
	; - `st1 / st2`
	; - `st.data`*
	; - `sta ST1_ADDRESS.w / sta ST2_ADDRESS.w`
	;
	; Leituras/escritas subsequentes incrementam o offset automaticamente (+1).
	;
	; * Nota: `st.data` NÃO É UMA INSTRUÇÃO NATIVA. Esta "instrução" equivale
	;         a uma macro, que se assemelha a uma instrução por conveniência.
	st0 #VDC_VRAM_READ_WRITE
	
	; Loop usado para carregar um tile na VRAM.
	; São processados 2 bytes de cada vez.
	@loadTileGraphics:
		clx
		cly
		
		; Mover primeiro byte do tile:
		;
		; Note que o `ST1_ADDRESS` e `ST2_ADDRESS` possuem `.w` no final.
		; Isto é usado para que WLA-DX interprete estes valores como 16-bit.
		;
		; Como `ST1_ADDRESS` e `ST2_ADDRESS` possuem valores similares aos da
		; zero-page de um 6502 comum, retirar o `.w` fará com que o WLA-DX
		; interprete o modo de endereçamento como zero-page ao invés
		; de absoluto. O `.w` no final resolve este problema.
	  - lda GFX_TILE.w, y
		sta ST1_ADDRESS.w
		iny
		
		; Mover segundo byte do tile:
		lda GFX_TILE.w, y
		sta ST2_ADDRESS.w
		iny
		
		; Um tile possui 32 bytes, 
		; e este loop processa 2 bytes de cada vez.
		;
		; Isso dá 16 iterações.
		inx
		cpx #16
		bne -
	; end
	
	; Selecionar registro para leitura/escrita no endereço $3000.
	; Nesta região, serão salvos os gráficos de um sprite.
	;
	; Sprites podem ser salvos em qualquer região de memória. Esta
	; foi escolhida por conta própria.
	;
	; Lembre-se de apontar este mesmo endereço de memória depois na
	; SATB (Sprite Attribute Table).
	st0 #VDC_VRAM_WRITE_ADDRESS
	st.data #$3000
	st0 #VDC_VRAM_READ_WRITE
	
	; Loop usado para carregar um sprite na VRAM.
	; São processados 2 bytes de cada vez.
	@loadSpriteGraphics:
		clx
		cly
		
		; Mover primeiro byte do sprite:
	  - lda GFX_SPRITE.w, y
		sta ST1_ADDRESS.w
		iny
		
		; Mover segundo byte do sprite:
		lda GFX_SPRITE.w, y
		sta ST2_ADDRESS.w
		iny
		
		; Um sprite possui 128 bytes, 
		; e este loop processa 2 bytes de cada vez.
		;
		; Isso dá 64 iterações.
		inx
		cpx #64
		bne -
	; end
	
	; Selecionar registro para leitura/escrita na região $7F00.
	; Esta é a região recomendada para transferir a SATB (Sprite Attribute
	; Table) para a sua posição especial de memória.
	st0 #VDC_VRAM_WRITE_ADDRESS
	st.data #SATB_ADDRESS
	st0 #VDC_VRAM_READ_WRITE
	
	; Loop usado para carregar a SATB (Sprite Attribute Table) na VRAM.
	; São processados 2 bytes de cada vez.
	@loadSpriteAttributeTable:
		clx
		cly
		
		; Mover primeiro byte dos atributos:
	  - lda GFX_SPRITE_ATTRIBUTE_TABLE.w, y
		sta ST1_ADDRESS.w
		iny
		
		; Mover segundo byte dos atributos:
		lda GFX_SPRITE_ATTRIBUTE_TABLE.w, y
		sta ST2_ADDRESS.w
		iny
		
		; O registrador Y só consegue copiar 256 valores de uma vez antes de
		; dar overflow.
		;
		; Como a A SATB (Sprite Attribute Table) possui 512 bytes no total, 
		; isso acaba duplicando os primeiros 256 valores ao invés de copiar os
		; que faltam.
		;
		; Alterar o endereço de escrita durante a metade do ciclo de iterações
		; resolve este problema.
		;
		; Note que esta checagem é rotulada com `+`. Este bloco de código é 
		; muito similar a um `if(x === 128) { ... }`.
		inx
		cpx #128
		bne +
			st0 #VDC_VRAM_WRITE_ADDRESS
			st.data #(SATB_ADDRESS + 128)
			st0 #VDC_VRAM_READ_WRITE
		; end
		
		; Um atributo de sprite possui 8 bytes, 
		; e este loop processa 2 bytes de cada vez.
		;
		; A SATB (Sprite Attribute Table) possui 64 atributos.
		; Isso dá 256 iterações.
		;
		; O registrador X é incrementado até 255. Após isso, seu valor dá
		; overflow e volta a ser 0, totalizando assim 256 iterações.
	  + inx
		cpx #0
		bne -
	; end
	
	; Transferir SATB para a posição especial de memória.
	st0 #VDC_VRAM_TO_SATB
	st.data #SATB_ADDRESS
	
	; Adiciona um tile na tela para exemplo.
	;
	; Embora o início da tela esteja na posição $0000, escrever neste endereço
	; cria artefatos nos outros tiles. Isto ocorre porque esta região de
	; memória é compartilhada com tiles/paletas, o que acaba criando um 
	; conflito de dados.
	;
	; Escrever em algumas posições mais adiante resolve este problema.
	st0 #VDC_VRAM_WRITE_ADDRESS
	st.data #32
	st0 #VDC_VRAM_READ_WRITE
	st.data tileFlags(0, 256)

	jmp SUBROUTINE_START
; end

; Paleta de exemplo. Esta é a paleta do PICO-8:
; https://lospec.com/palette-list/pico-8
;
; Uma paleta é composta por 16 cores e possuem 256 bytes de tamanho.
; As cores utilizam o formato GGGRRRBBB e utilizam 2 bytes cada.
;
; As funções `RGB9()` e `RGB()` podem ser usadas para criar as cores.
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

; Tile de exemplo. Este é do asset pack RogueDB32, por SpiderDave:
; https://opengameart.org/content/roguedb32
;
; Um tile é composto por 4 bitplanes e possuem 32 bytes de tamanho.
; Os tiles possuem 8x8 de tamanho. Cada pixel referencia um índice
; da paleta.
;
; Tiles utilizam as paletas salvas nos bancos 0-255.
;
; A macro `createTile()` pode ser usada para criar os tiles.
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

; Sprite de exemplo. Este é do asset pack Classic Hero, por GrafxKid:
; https://opengameart.org/content/classic-hero
;
; Um sprite é composto por 4 bitplanes e possuem 128 bytes de tamanho.
; Os sprites possuem 16x16 de tamanho. Cada pixel referencia um índice
; da paleta.
;
; Tiles utilizam as paletas salvas nos bancos 256-511.
;
; A macro `createSprite()` pode ser usada para criar os sprites.
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

; SATB (Sprite Attribute Table) de exemplo.
;
; Só é necessário copiar este valor na VRAM uma vez, 
; preferencialmente na região $7F00.
;
; São 64 sprites, e cada tabela de atributos possui 8 bytes de tamanho.
; A SATB (Sprite Attribute Table) possui 512 bytes de tamanho no total.
;
; As macros `spriteAddress()` e `spriteFlags()` podem ser usadas para 
; configurar os sprites.
GFX_SPRITE_ATTRIBUTE_TABLE:
	;     y ; x ; address(value)      ; flags(palette, sizeX, sizeY, flipX, flipY, fg)                        
	.word 80, 80, spriteAddress($3000), spriteFlags(0, 0, 0, 0, 0, 0)
	
	; instrução que copia a SATB (Sprite Attribute Table) da VRAM para para
	; a sua região especial de memória sempre moverá 512 bytes, independente de
	; terem poucos sprites em uso ou não.
	;
	; Para não copiar "dados de lixo" de qualquer lugar da ROM, podemos
	; preencher o resto dos atributos com um espaço vazio...
	.REPEAT 63
		.word 0, 0, 0, 0
	.ENDR
; end

; Subrotina responsável pelo game loop do jogo.
SUBROUTINE_START:
	@readGamepad:
		clx
		cly
		
		; Primeira leitura do gamepad,
		; período de delay (9 ciclos).
		;
		; Left, Down, Right, Up.
	    lda #1
		sta IO_IRQ_JOYPAD
		ina
		ina
		ina
		ina
		nop
		lda IO_IRQ_JOYPAD
		
		; Salvar primeiro byte do gamepad.
		ldy #0
		sta Variable.Gamepad, y
	
		; Segunda leitura do gamepad,
		; período de delay (9 ciclos).
		;
		; Run, Select, Button II, Button I.
		lda #0
		sta IO_IRQ_JOYPAD
		ina
		ina
		ina
		ina
		nop
		lda IO_IRQ_JOYPAD
		
		; Salvar segundo byte do gamepad.
		ldy #1
		sta Variable.Gamepad, y
	; end
	
	; Alterar posição X do sprite.
    lda Variable.PlayerX.w
	lda #80
	sta Variable.PlayerX.w
	
	; Alterar posição Y do sprite.
	lda Variable.PlayerY.w
	ina
	sta Variable.PlayerY.w
	
	; Selecionar região de memória da SATB (Sprite Attribute Table) onde o
	; primeiro sprite está salvo.
	st0 #VDC_VRAM_WRITE_ADDRESS
	st.data #spriteAttributeIndex(0)
	st0 #VDC_VRAM_READ_WRITE
	
	; Salvar posição Y do sprite.
	lda Variable.PlayerY.w
	sta ST1_ADDRESS.w
	stz ST2_ADDRESS.w
	
	; Salvar posição X do sprite.
	lda Variable.PlayerX.w
	sta ST1_ADDRESS.w
	stz ST2_ADDRESS.w
	
	; Atualizar SATB (Sprite Attribute Table) com os novos valores.
	st0 #VDC_VRAM_TO_SATB
	st.data #SATB_ADDRESS
	
	jmp SUBROUTINE_START
; end

; @todo
SUBROUTINE_VDC_INTERRUPT_HANDLER:
	rti
; end

; @todo
SUBROUTINE_TIMER_INTERRUPT_HANDLER:
	rti
; end

; @todo
SUBROUTINE_INTERRUPT_RETURN:
	rti
; end

; Os últimos bytes da ROM precisam apontar para a subrotina de incialização.
;
; O código salta durante a inicialização e um "soft reset".
.ORG $1FF6
.word SUBROUTINE_INTERRUPT_RETURN        ; RTI...?
.word SUBROUTINE_VDC_INTERRUPT_HANDLER   ; VDC interrupt...?
.word SUBROUTINE_TIMER_INTERRUPT_HANDLER ; Timer interrupt...?
.word SUBROUTINE_INTERRUPT_RETURN        ; CPU/VCE interrupt...?
.word SUBROUTINE_RESET                   ; Reset pointer.

; EOF
