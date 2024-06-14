# Moreorless

This is a simple text editor and viewer for the Foenix F256 family of modern retro computers. It allows you to load 
a text file (remark: SuperBASIC programs are also text files) into RAM and to navigate through it in forwards and backwards 
direction as well as editing the loaded file. The following commands are supported (Remark: Use the `Windows` key instead
of `Foenix` when using a PS/2 keyboard.)

- `Cursor left` and `right` move the cursor horizontally
- `Cursor up` and `down` move the cursor one line up or down
- Pressing `Foenix+Cursor down` moves the view one screen towards the end of the file
- Pressing `Foenix+Cursor up` moves the view one screen towards the beginning of the file
- Pressing `F1` resets the view to line one in 80x60 text mode
- Pressing `F3` resets the view to line one in 80x30 text mode
- Pressing `Alt+x` leaves the program and restarts BASIC
- Pressing `Foenix+g` moves you to the line number which was entered after pressing the key
- Pressing `Foenix+f` allows you to enter a string to search for in the document. If a non empty string is entered 
`SRCH` is  shown in the status line. If an empty string is entered the current search string is deleted. If
a search string was entered `moreorless` will immediately search for it in forward direction. You can press
 `F5` or `F7` explicitly to search forward or backward for the next occurance. All searches are case insensitive
and instead of printing the found string in reverse the cursor is moved to the start position of the search 
string in the line.
- Pressing `Foenix+u` unsets or deletes the search string. This also makes `SRCH` disappear
- Pressing `F5` searches for the next occurance of the search string when moving towards the end of the 
document. If it is found the line in which it appeared becomes the first line which is displayed. While
the search is in progress a `*` is shown in the upper left corner of the screen.
- Pressing `F7` searches for the next occurance of the search string when moving towards the start of the 
document. If it is found the line in which it appeared becomes the first line which is displayed. While
the search is in progress a `*` is shown in the upper left corner of the screen.
- Pressing `delete` can be used to delete single characters and merge lines and thereby deleting a line
- Pressing `Return` can be used to split a line in two lines, i.e. it creates a new line below the current one.
- `Foenix+s` can be used to save the current state of the edited text
- `Alt+b` creates a new file from the current state of the edited text by automatically prefixing each line with
a line number. This can be used to edit BASIC programs without line numbers and adding them while writing the
file to SD card or an IEC drive.
- `Home` and `Shift+Home` can be used to move the cursor to the begin ir end of the line
- When any other key is pressed the corresponding character is inserted at the current cursor position
 
`Moreorless` uses a single line feed (LF) or carriage return (CR) character as a line delimiter. The default 
is LF but this can be changed at program start to CR. If the alternate line ending character is encountered
in text it is replaced by a diamond shaped character.

The software auto detects the presence of a RAM expansion cartridge and uses the extra RAM if it is
determined that such a cartridge is in fact present.

On the F256K keyboard autorepeat is implemented in software by `Moreorless`. Surprisingly enough this is
compatible with autorepeat by a PS/2 keyboard when used on the Junior. As the repeat frequency seems
to be slower with a real keyboard vertical scrolling appears to be slower on the Junior.

# Other limitations

- The maximum line length is 224 characters. Any file with lines longer than that will not be loaded
- All characters which appear in columns 81 or higher are clipped, i.e. there is currently no horizontal scrolling
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
I hope I can keep the overall length of the code below 32KB which would allow to keep the 8K block starting 
at $8000 as a window to map in some sort of  yet unspecified extension code.

# Remarks

## Viewing and editing SuperBASIC programs

SuperBASIC can cope with either LF or CR as a line ending character and CR seems to be the default. So if you 
can not load a SuperBASIC program into `moreorless` try to switch to the CR line ending at program start. 

SuperBASICs `list` command performs pretty printing when showing a program. I.e. it for instance automatically
indents certain parts of the program and does syntax highlighting. `moreorless` will not perform any pretty
printing when showing or editing a BASIC program. On the other hand it allows you to look at and edit the program 
in a much more comfortable way and you can search in the program's text. Additonally you can add your own indentation
when editing the source code.

## Some plans

As the data structure which represents the file contents in memory is dynamic I am in the process to extend this
software to be a practically usable text editor for the Foenix 256 line of computers. Be warned this is not finished 
by a long shot. This is how I plan to progress:

Short term goals  
- adding cutting copying and pasting of parts of lines and full lines
- adding search and replace 

Midterm goals
- replace tab characters at load by four blanks
- visualize line lengths larger than 80 in UI

After that possibly
- adding an undo feature (I have no clear plan on how to achieve this, yet)
- adding some sort of mouse support

My 6502 simulator [`6502profiler`](https://github.com/rmsk2/6502profiler) has been eminently useful in testing
the memory managment and linked list functionality.

# Building the software

You will need `64tass`, GNU `make` and a Python3 interpreter in order to build the software. Configure the
port in the makefile in order to use the target `upload` which, after bulding the software, uploads it to
your F256 via the USB debug port and executes it. Build the target `test` in order to run all test cases
(this requires `6502profiler`).