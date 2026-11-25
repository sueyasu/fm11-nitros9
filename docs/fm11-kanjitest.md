# KanjiTest: stock FM-11 sub-ROM Kanji diagnostic

The Level 1 command `KanjiTest` sends the enhanced FM-11 standard
display sub-ROM's $37 (Shift-JIS mode) and $12 (CHARACTER OUT) commands
through the established $FC80-$FC84 mailbox / $FD05 handshake.
It never reads $AFF4-$AFF7 itself and never modifies graphics VRAM.
The sub-ROM is responsible for selecting both ROM banks and drawing
the glyphs.

Requires the later 20-KiB FM-11AD2/BS-family sub-ROM and both
128-KiB Kanji ROMs. The first-level sample contains six characters;
the second-level sample contains JIS78 48-ku, 1-5-ten.

Build the Level 1 **2HD** image (the diagnostic is included in the extended command set):
```sh
scripts/fm11/build-images.sh 1 6809 2hd
```
On a 2D image, space constraints may select the core commands only;
in that case copy the compiled `build/.../kanjitest` OS-9 module
into `/D0/CMDS` manually or use the 2HD image.
Then at the LOCAL FM-11 console:
```
OS9: kanjitest
```
Run the emulator with `--trace-kanji` and confirm both the
displayed glyphs and ROM-access counts. A serial /T1 console is
not a substitute for the local CRT.

The command $37 parameter was verified against the provided original
20-KiB SubRom.h machine code. The dispatcher sends $37 to the handler
at $EAF4. That handler tests the byte at $9F83 and sets the Shift-JIS
mode flag (direct RAM $9C, bit 7) on the $FF path. Setting $9F83
to $01 instead *clears* that flag and causes byte pairs to be shown
as single-byte characters; the Kanji ROM ports are never accessed.
KanjiTest now sends $FF to enable and $00 to disable; the auxiliary
parameter bytes at $9F84/$9F85 are cleared.

The ROM handler logic has been statically analyzed, but glyph output
through the running emulator and the specific supplied ROM still
requires local verification. Confirm `--trace-kanji` increments when
running KanjiTest; if not, inspect the actual sub-ROM's $37 handler
and its text-mode configuration before introducing further guesses.

ROM revision reference:
https://haserin09.la.coocan.jp/fm1116rom.html

## Graphics output gate ($FDA0)

The first runtime test with command $37 enable=$FF yielded **11 Kanji
selections** (six level-1 plus five level-2 glyphs), but no visible glyph
pixels. The FM-11 main-side $FDA0 register controls whether the graphics
VRAM plane is visible: graphics bits are $0C, text bits are $03.
The original NitrOS-9 local console is a text-only driver and does not
explicitly enable main-side graphics output.

KanjiTest now writes **$0D to $FDA0** before sending $37/$12: graphics
and the ordinary text overlay remain enabled. This is a diagnostic
display-mode change, not an emulated glyph overlay; the stock sub-ROM
still fetches and rasterizes the character. The test leaves both
layers enabled on return. A display reset restores normal firmware
defaults.

If glyphs remain invisible, use the SDL software renderer with
`--trace-kanji --diagnostics` and record **leftReads/rightReads**,
**VRAM_nonzero**, and **FDA0** while KanjiTest is running. This
distinguishes glyph ROM reads, VRAM writes, and visibility gating.
