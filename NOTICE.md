# License and acknowledgements

The Off the Wall RTL is licensed under GPL-3.0-or-later.
The complete GPL version 3 text is in LICENSE. The game name and hardware
identifiers identify compatible hardware; no game ROMs, fuse maps, Atari
manuals or board photographs are included.

fx68k by Jorge Cwik (rtl/lib/fx68k) is included unchanged under GPL-3.0,
with its license file.

The processor wrapper, wait-state counter, watchdog and EEPROM model are
adapted from the Batman MiSTer core (Copyright (C) 2026 the Batman MiSTer
core authors, GPL-3.0-or-later), which took their structure from the Skull &
Crossbones and Bad Lands cores. The I/O block and the video system are
adapted from the Relief Pitcher MiSTer core, whose video modules come from
the Batman and Skull & Crossbones cores. The LETA model is adapted from
the Rampart MiSTer core (Copyright (C) 2026 RetroShrimp), whose behaviour
follows leta_rep.vhd by JROK from the Atari System 1 core and whose structure
follows the Blasteroids core. The sound board (rtl/sound) is the Batman
MiSTer core's JSA III model, whose structure follows the Skull & Crossbones
core. The SDRAM controller, the EEPROM save controller and the analog
output alignment come from the Relief Pitcher and Batman cores (after Skull
& Crossbones; analog_hsize.sv by Umberto Parisi). The control mapping and
the spinner pacing come from the Rampart core (RetroShrimp), after the
Blasteroids core. Each file keeps its notice.

The MiSTer framework (sys) is the MiSTer-devel project's, unchanged, under
its own licences.

T65 (rtl/lib/T65) by Daniel Wallner, Mike Johnson, Wolfgang Scherr and
Morten Leikvoll is included unchanged under its BSD-style licence (notice in
T65.vhd); T65_wrap.vhd is from the Skull & Crossbones core (GPL-3.0). JT51
(rtl/lib/jt51) by José Tejada Gómez is included unchanged under
GPL-3.0-or-later.
