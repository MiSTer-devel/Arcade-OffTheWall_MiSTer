# Off the Wall for MiSTer FPGA

An FPGA core for **Off the Wall**, Atari Games' 1991 ball-and-paddle game for
up to three players, for the [MiSTer](https://github.com/MiSTer-devel/Main_MiSTer/wiki)
platform.

The core recreates the original hardware rather than emulating the game: the
game board (Atari A049727, a 68000 with Atari's VAD and MOB video chips) and
the JSA III sound board (a 6502 and a YM2151). It was built from Atari's
schematics and from the equations of the board's GAL chips, with MAME used as
a cross-reference where the published documents are silent.

<img src="https://img.shields.io/badge/Quartus-17.0.2-blue" alt="Quartus 17.0.2"> <img src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue" alt="GPL-3.0-or-later">

---

## Supported games

| MRA | MAME set | Version |
| --- | --- | --- |
| `Off the Wall.mra` | `offtwall` | 2/3-player upright |
| `_alternatives/_Off the Wall/Off the Wall (Cocktail).mra` | `offtwallc` | 2-player cocktail |

Both sets run on the same bitstream; the cocktail set has its own program and
graphics ROMs.

---

## Installing

1. Copy `releases/OffTheWall_<date>.rbf` to `_Arcade/cores/` on the SD card.
   When updating, delete the older `OffTheWall_*.rbf` first.
2. Copy `releases/Off the Wall.mra` to `_Arcade/`. For the cocktail version,
   also copy the folder `releases/_alternatives/_Off the Wall` to
   `_Arcade/_alternatives/`.
3. Put the MAME 0.289 ROM set `offtwall.zip` in `games/mame/`. The cocktail
   version needs `offtwallc.zip` as well.

**No ROM data is included in this repository.** The MRA files name each ROM
by file name and CRC, and give MiSTer an MD5 sum to check the set against.

An **SDRAM module is required**: the graphics ROMs are read from it.

### Settings and high scores

Off the Wall has no DIP switches. Coinage, difficulty and the other operator
settings, the bookkeeping totals and the high-score table are kept in the
board's 2 KB EEPROM, which MiSTer saves to the SD card. Until a save file
exists the core starts from the factory settings in the MAME set.

The operator menus are in the game's self-test. Set **Service** to On in the
OSD and reset the core to enter it; set it to Off and reset to return to the
game.

---

## Controls

Each station on the cabinet has a **whirly-gig** (a spinning knob that moves
the paddle) and one **START/ACTION** button. MiSTer players 1, 2 and 3 are the
left, right and centre stations.

| Button | Function | Default |
| --- | --- | --- |
| Action | START/ACTION | A |
| Start | the optional JAMMA start button | Start |
| Coin | player 1: left coin, player 2: right coin, player 3: service credit | Select |

With **Control panel: Whirly-gigs** (the default) each of these turns a
station's whirly-gig, and they add together:

* a MiSTer spinner or a paddle;
* the mouse, for player 1 (the left mouse button is player 1's Action);
* the left analog stick, pushed left or right, as a speed;
* the d-pad left and right, as full speed.

**Whirly-gig speed** scales the motion from 0.25x to 4x and **Whirly-gig
direction** reverses it.

**Control panel: Joysticks** is the joystick version of the game: the d-pad is
each station's 8-way joystick. The game works out by itself which kind of
control is fitted.

---

## OSD options

| Option | Effect |
| --- | --- |
| Aspect ratio | Original (4:3), Full Screen, or the two custom ratios from `MiSTer.ini` |
| Orientation | Original, or Flip (the picture turned 180 degrees, for a cocktail table) |
| Scale | Normal, V-Integer, HV-Integer, Narrower HV-Integer |
| Analog alignment | CRT H-Size, CRT H-Position, Analog VGA H-Shift and V-Shift for analog video output; at 0 they leave the picture untouched |
| Control panel | Whirly-gigs or Joysticks |
| Whirly-gig speed, direction | see Controls |
| Service | the board's self-test switch |
| Reset | resets the game |

---

## Hardware

| Block | What the core models |
| --- | --- |
| Main CPU | 68000 at 14.318 MHz (see Known limits) |
| Program ROM | 256 KB; the top 32 KB is bank-switched by the GAL 136090-1001 |
| Address decode | GAL 136090-1003, with wait states from a 74F163 counter |
| Video | VAD 137656-002 (timing, one scrolling playfield of 8 x 8 tiles, video RAM), MOB 137593-001 (motion objects) and its line buffer, mixer GALs 136090-1006 and 136090-1007 |
| Colour | 2048-word colour RAM, 5 bits each of red, green and blue plus a shared intensity bit |
| Picture | 336 x 240, 7.159 MHz pixel clock, 15.70 kHz, 59.92 Hz |
| Controls | the LETA 137304-2002 counts the whirly-gigs |
| Settings | 28C16 2 KB EEPROM with its write lock |
| Watchdog | a 74LS197 counting frames; also the power-on reset |
| Sound | JSA III: 6502 at 1.79 MHz, YM2151 at 3.58 MHz with its YM3012 DAC, the board's analog filters and master volume; mono |

The whole core runs from one 57.27 MHz clock, four times the board's 14.318
MHz crystal, with clock enables. The program ROMs, the sound program and the
EEPROM are in FPGA block RAM; the 768 KB of graphics ROMs are in SDRAM.

Resource use of the released build on the DE10-Nano's Cyclone V
(5CSEBA6U23I7): 14,161 of 41,910 ALMs (34 %), 498 of 553 RAM blocks (90 %),
50 of 112 DSP blocks. Timing is met on every corner; the worst setup slack is
+0.231 ns, and the core's own 57.27 MHz clock has at least +1.13 ns.

---

## Accuracy

The behaviour comes from the hardware documents wherever they exist:

* The main address decoder, the video mixer and the sound board's decoder
  use the equations of the board's GAL chips (136090-1003, -1006, -1007 and
  the JSA III's 136085-1038 and -1039).
* The I/O block, the LETA, the sound board's latches, mailbox, interrupt
  timer and analog filters follow Atari's schematics. Where this board's own
  sheet was never published (wait states, watchdog, EEPROM lock), the core
  follows the same circuit on Atari's sister boards.

### Where this core differs from MAME

| Behaviour | MAME | This core |
| --- | --- | --- |
| Program ROM bank switching | replaced by patches keyed to the program counter | a model of the bank GAL; the game's own ROM test passes unpatched |
| "HARDWARE ERROR" letters | hidden by patching RAM | the game draws them all the time and hides them with a motion-object setting, which the core models |
| 68000 clock | 7.159 MHz, no wait states | 14.318 MHz with the board's wait states |
| Sound CPU at power-up | runs at once | held in reset until the 68000 first releases it |
| 4 ms sound interrupt | free-running | restarts at each acknowledge, as wired: music about 0.3 % slower |
| Playfield wrap | 496 pixels | 512 pixels: the self-test menus sit 16 pixels further right |
| Colour or sprite change in mid-frame | applied to the whole frame | shown from the line the beam has reached |

### Known limits

Atari's schematics of this board's CPU, decode and video sections were never
published, and the bank-switching GAL 136090-1001 has never been read out.
These parts were worked out from the game program, the other GALs and sister
boards instead:

* **Bank-switching GAL.** Reconstructed from what the two program ROM sets
  need. It is exact for every ROM access the game makes, but it is not the
  chip's own equations.
* **68000 clock.** The board has solder straps for 7.159 and 14.318 MHz. The
  core uses 14.318 MHz: the board's parts list gives a 12 MHz 68HC000, and
  at 7.159 MHz with the board's wait states the game cannot keep its frame
  rate.
* **Video RAM timing.** How the VAD shares its RAM between the 68000, the
  playfield and the motion objects is not known. The core gives the 68000
  and the motion objects an access every pixel, which is enough for
  everything the game draws.
* **Motion-object setting.** The register that hides the "HARDWARE ERROR"
  letters is read as a horizontal shift of all motion objects. That fits
  every observation of both sets.
* **Whirly-gig resolution.** The counts per turn of the real control are not
  known; set the feel with Whirly-gig speed.

If you have a real Off the Wall board and can help settle any of these,
please open an issue.

---

## Verification

The core was developed with AI assistance, simulation first. Every block has
its own test bench, and the whole core was simulated with the real 68000
(fx68k), 6502 (T65) and YM2151 (jt51) models, loading the ROMs exactly as
MiSTer sends them, and compared with MAME 0.289:

* **Attract mode and a full game**, 1,480 frames of each set: every frame is
  a MAME frame, or lies between two consecutive MAME frames where the game
  changes the picture in mid-frame, apart from the few frames of each level
  load and some frames where only the ball is caught half-updated.
* **Self-test**: the ROM test reports "ALL ROMS are OK" for both sets
  through the reconstructed bank GAL; the playfield, motion object and
  monitor screens match pixel for pixel; the sound board test reports GOOD.
* **Sound board**, driven by MAME's command log: every byte between the two
  CPUs is passed in the same order as in MAME.

On real hardware the released bitstream has been tested on many MiSTer
systems with no issues reported, and self-test screens captured from a
DE10-Nano match the simulation pixel for pixel. The core has not been
compared with a real Off the Wall board.

---

## Building

Quartus Prime Lite 17.0.2. Open `OffTheWall.qpf` and compile, or run
`quartus_sh --flow compile OffTheWall` in this folder; the bitstream is
`output_files/OffTheWall.rbf`. The framework writes the build date into the
bitstream, so a build made on another day differs from the release.

Source files are listed in `files.qip`; add new ones there by hand, not from
the Quartus GUI. If a compile writes the full pin list into
`OffTheWall.qsf`, restore the short file (it ends at `source files.qip`).
`clean.bat` removes the build products.

---

## Repository layout

```text
OffTheWall.qpf, .qsf, .sdc   Quartus project
Arcade-OffTheWall.sv         MiSTer glue: OSD, controls, video and audio out
files.qip                    source list
rtl/offtwall_core.sv         the game board, the sound board and their memories
rtl/main/                    68000, program ROM and bank GAL, decode, wait states, EEPROM, watchdog
rtl/io/                      I/O block, LETA, whirly-gig and MiSTer control mapping
rtl/video/                   VAD, video RAM, playfield, motion objects, line buffer, mixer, colour RAM,
                             analog output alignment
rtl/gal/                     GAL equations of the game board
rtl/sound/                   the JSA III sound board
rtl/mem/                     ROM download, SDRAM controller, graphics ROM reader
rtl/lib/                     fx68k, T65 and jt51, unchanged
rtl/pll/                     the 57.27 MHz PLL
sys/                         MiSTer framework, unchanged
releases/                    the bitstream and the MRAs
```

---

## License and credits

GPL-3.0-or-later; see `LICENSE`. `NOTICE.md` says where each part comes from,
and every file keeps its own notice.

| Component | Author | License |
| --- | --- | --- |
| fx68k (68000) | Jorge Cwik | GPL-3.0 |
| T65 (6502) | Daniel Wallner, Mike Johnson, Wolfgang Scherr, Morten Leikvoll | BSD-style |
| jt51 (YM2151) | José Tejada (jotego) | GPL-3.0-or-later |
| `analog_hsize.sv` | Umberto Parisi (rmonic79) | GPL-3.0-or-later |
| MiSTer framework (`sys/`) | Alexey Melnikov (sorgelig) and contributors | GPL-2.0-or-later / GPL-3.0-or-later per file |

The core builds on earlier Atari MiSTer cores: Relief Pitcher, which runs on
the same game board (video, I/O, SDRAM controller); Batman, which has the
same JSA III sound board (sound board, CPU wrapper, watchdog, EEPROM);
Rampart (LETA and spinner pacing); and their ancestors Skull & Crossbones,
Bad Lands, Blasteroids, Xybots and Toobin'.

Thanks to the MAME team, whose `offtwall.cpp`, `atarijsa`, `atarivad` and
`atarimo` code was the cross-reference throughout, and to the people who
recovered the read-protected GAL fuse maps of this board and shared them.

Off the Wall and its ROMs, artwork and manuals are © Atari Games. This
repository contains no ROM data.
