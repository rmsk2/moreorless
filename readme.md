# Moreorless

This is a text viewer for the Foenix F256 family of modern retro computers. It allows to load a text file
into RAM and to navigate through it in forwards and backwards direction using the following keys:

- `Cursor left` and `right` move the cursor horizontally. Whenever the left or right edge of the screen are
crossed the current line is increased or decreased. When the cursor crosses the right edge in the bottom 
line the view scrolls one line up and a new line (if it exists) is exposed.
- `Cursor up` and `down` move the cursor one line up or down. When the upper or lower edge of the screen
would be crossed the whole screen is scrolled up or down and a new line is revealed at the top or the 
bottom of the screen.
- Pressing the `space bar` moves the view one screen towards the end of the file
- Pressing `b` moves the view one screen towards the beginning of the file
- Pressing `F1` resets the view to line one in 80x60 text mode
- Pressing `F3` resets the view to line one in 80x30 text mode
- Pressing `q` leaves the program by causing a soft reset

In essence the basic navigation commands work in the same way as in the UNIX `less` utlility. 
`Moreorless` uses a single line feed character as a line delimiter. Carriage return characters are 
ignored.

The software auto detects the presence of a RAM expansion cartridge and uses the extra RAM if it is
determined that such a cartridge is in fact present.

On the F256K keyboard autorepeat is implemented in software by `Moreorless`. Surprisingly enough this is
compatible with autorepeat by a PS/2 keyboard when used on the Junior. As the repeat frequency seems
to be slower with a real keyboard vertical scrolling appears to be slower on the Junior.

# Other limitations

- The maximum line length is 224 characters. Any file with lines longer than that will not be loaded
- All characters which appear in columns 81 or higher are clipped, i.e. there is no horizontal scrolling
- Tab characters are not expanded at the moment
- Due to the data structure selected (see below) there is quite a bit if memory management overhead, i.e.
wasted memory. `Moreorless` uses roughly twice as much memory as would be needed to only store the file 
contents in RAM. On the other hand the files `const.txt` (47 KB) and `macbeth.txt` (125 KB) contained 
in this repo as an example can be loaded and viewed on an unexpanded F256 with RAM to spare. The file 
`grimm.txt` (286 KB) needs the RAM expansion but also leaves 90 KB free for additional text.

# A bit of technical Info

`Moreorless` uses a doubly linked list to organize the data of the file in RAM. Additionally the memory is
managed dynamically in units of 32 bytes. This also explains the odd number of 224 maximum characters per
line: A list entry links to seven data blocks each containing 32 bytes (7 * 32 = 224). The pointers used
in the linked list contain three bytes. The first two bytes give the address in the 16 bit memory window 
to which the 32 byte block is mapped when brought into view by the MMU and the third byte contains the 8K 
block number which can be written directly into the corresponding MMU register.

On an unexpanded system 384 KB (48 8 KB blocks) of RAM are managed by `Moreorless`. There would be an 
additional 64 KB (eight 8 KB blocks) available which have been excluded as a reserve for future extensions.
When a RAM expansion cartridge is present the memory available to `Moreorless` is increased to 640 KB.

# Remarks

As the data structure which represents the file contents in memory is dynamic this could become a native 
text editor for the Foenix 256 line of computers. But as Foenix retro systems has announced that the F256K
will be followed by the F256K2, which seems to offer vastly more memory, it may be wise to wait and see
what new possibilities this new machine will bring to the table before starting this endeavour. Nontheless 
I think this software is useful as it is.

My 6502 simulator [`6502profiler`](https://github.com/rmsk2/6502profiler) has been eminently useful in testing
the memory managment and linked list functionality.