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

Note: The actual $37 mode argument is provisionally supplied
as 1 for enable and 0 for disable at $FC83. The command's
parameter format has not yet been execution-verified against the
specific stock sub-ROM in use. If it does not display Kanji,
the $37 handler must be traced and the argument format corrected.
Assembly/CTest success alone does not prove correct glyph display.

ROM revision reference:
https://haserin09.la.coocan.jp/fm1116rom.html
