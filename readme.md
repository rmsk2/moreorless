# Moreorless

This is a simple text editor for the Foenix F256 family of modern retro computers. It allows you to load a text file 
(remark: SuperBASIC programs are also text files) into RAM and to navigate through it as well as editing the loaded 
file in 80x60 or 80x30 text mode. The following commands are supported (remark: Use the `Windows` key instead of 
the `Foenix` key when using a PS/2 keyboard.)

- Pressing `Cursor left` and `right` moves the cursor horizontally
- Pressing `Cursor up` and `down` moves the cursor one line up or down
- Pressing `Control+Cursor up` moves the visible section of the document one line up while
preserving the current cursor position. You can not move the cursor out of the visible screen
using this command.
- Pressing `Control+Cursor down` moves the visible section of the document one line down while
preserving the current cursor position. You can not move the cursor out of the visible screen
using this command.
- Pressing `Control+Cursor Right` moves the cursor to the end of the next word 
- Pressing `Control+Cursor Left` moves the cursor to the beginning of the previous word 
- Pressing `Foenix+Cursor down` moves the view one screen towards the end of the file
- Pressing `Foenix+Cursor up` moves the view one screen towards the beginning of the file
- Pressing `F1` resets the view to line one in 80x60 text mode
- Pressing `F2` resets the view to line one in 80x30 text mode
- Pressing `Alt+x` leaves the program and restarts BASIC
- Pressing `Foenix+g` moves you to the line number which was entered after pressing the key
- Pressing `Foenix+f` allows you to enter a string to search for in the document. If a non empty string is entered 
`SRCH` is  shown in the status line. If an empty string is entered the current search string is deleted. If
a search string was entered `moreorless` will immediately search for it in forward direction. You can press
 `F3` or `F7` explicitly to search forward or backward for the next occurance. All searches are case insensitive
and instead of printing the found string in reverse the cursor is moved to the start position of the search 
string in the line.
- Pressing `Foenix+u` unsets or deletes the search string. This also makes `SRCH` disappear
- Pressing `F3` searches for the next occurance of the search string when moving towards the end of the 
document. If it is found the line in which it appeared becomes the first line which is displayed. While
the search is in progress a `*` is shown in the upper left corner of the screen.
- Pressing `F7` searches for the next occurance of the search string when moving towards the start of the 
document. I.e. the search is done in backwards direction. If it is found the line in which it appeared becomes 
the first line which is displayed. Whilethe search is in progress a `*` is shown in the upper left corner of the screen.
- Pressing `delete` can be used to delete single characters and to merge a line with the one above and thereby
deleting the current line
- Pressing `Return` can be used to split a line in two lines, i.e. it creates a new line below the current one
- `Foenix+s` can be used to save the current state of the edited text. If no file name was specified yet, you
have to enter a new one.
- `Alt+b` creates a new file from the current state of the edited text by automatically prefixing each line with
a line number. This can be used to edit BASIC programs without line numbers and adding them while writing the
file to SD card or an IEC drive. The created file can then be loaded and executed.
- `Home` and `Shift+Home` can be used to move the cursor to the start or the end of a line
- Pressing `Foenix+m` sets a mark which determines the start position of copy and paste operations. That a mark
is set is visualized by an `M` in the top right corner of the screen. As soon as the document is changed or a copy
or cut operation has been successfully performed the mark is invalidated and the `M` disappears
- Pressing `Foenix+c` copies all the lines between the marked line and the current line into the clipboard. This uses
additional memory
- Pressing `Foenix+x` copies all the lines between the marked line and the current line into the clipboard and deletes
them from the document. Cutting a part of the document does not use any additional memory as the linked list
which is used to represent the document is simply split in two
- Pressing `Foenix+v` inserts the current clipboard contents (filled by `Foenix+c` or `Foenix+x`) into the document
starting at the current cursor position, i.e. the lines are inserted after the current line
- Pressing `Ctrl+c` copies all the characters *in the current line* which reside between the mark and the cursor 
position where `Ctrl+c` was pressed into the clipboard. To reiterate that: The mark has to be set at the same 
line where `Ctrl+c` was pressed.
- Pressing `Ctrl+x` copies all the characters *in the current line* which reside between the mark and the cursor 
position where `Ctrl+x` was pressed into the clipboard and then deletes them from the document.
- Pressing `Ctrl+v` inserts the contents of the clipboard (filled by `Ctrl+c` or `Ctrl+x`) at the current
cursor position
- Pressing `Alt+k` clears the clipboard and frees the associated memory
- Pressing `Alt+s` allows you to save the dcoument under a new name
- Pressing the `Tab` key inserts two spaces. `Ctrl+Tab` inserts four space characters
- Pressing `Foenix+r` allows you to set a replace string. This string is used when performing a replace operation
- Pressing `F5` tests whether the cursor is placed at the beginning of an occurance of the search string. If
this is the case the search string is replaced by the replace string. The replace operation is not performed
if the result of the operation would lead to a line which is longer than 80 characters or if a search string
has not been set
- Pressing `F2` lets you change the colour scheme by cycling through five alternatives
- When any other key is pressed the corresponding character is inserted at the current cursor position

If the document has unsaved changes a `*` appears in the top right corner of the screen. `moreorless` uses a 
single line feed (LF) or carriage return (CR) character as a line delimiter. The default is LF but this can be 
changed at program start to CR. If the alternate line ending character is encountered in the text it is replaced 
by a diamond shaped character.

The software auto detects the presence of a RAM expansion cartridge and uses the extra RAM if it is
determined that such a cartridge is in fact present.

On the F256K keyboard autorepeat is implemented in software by `Moreorless`. Surprisingly enough this is
compatible with autorepeat by a PS/2 keyboard when used on the Junior. As the repeat frequency seems
to be slower with a real keyboard vertical scrolling appears to be slower on the Junior.

# Other limitations

- In order to spare me the pain to consider a gazillion edge and corner cases I have for the moment decided 
to split cut, copy and pasting data from and into the document into two different sets of commands. There
is one set of commands that can be used to copy and paste simple text **but not full lines**. These commands 
can be accessed through the key combinations `Foenix+m`, `Ctrl+c`, `Ctrl+x` and `Ctrl+v`. If you want to 
copy blocks of code or text which only consist of **of full lines** you can use `Foenix+m`, `Foenix+c`, 
`Foenix+x` and `Foenix+v` for that purpose.
- The maximum line length is 224 characters. Any file with lines longer than that will not be loaded. All characters 
which appear in columns 81 or higher are clipped, i.e. there is no horizontal scrolling. If `moreorless` 
encounters a line which is longer than 80 characters, a star is printed after the value specifiying the current 
column. Additonally `moreorless` does not allow to add characters to lines which are already longer than 80 characters 
but they can be split via `return` and they can shortened by pressing the `delete` key. A file that was only edited 
with `moreorless` will therefore never have lines with more than 80 characters.
- Due to the data structure selected (see below) there is quite a bit of memory management overhead, i.e.
in essence wasted memory. `Moreorless` uses roughly twice as much memory as would be needed to only store the 
file contents in RAM. On the other hand the files `const.txt` (47 KB) and `macbeth.txt` (125 KB) contained 
in this repo as an example can be loaded and viewed on an unexpanded F256 with RAM to spare. The file 
`grimm.txt` (286 KB) needs the RAM expansion but also leaves 90 KB free for additional text.

# A bit of technical Info

`Moreorless` uses a doubly linked list to organize the data of the file in RAM. Additionally the memory is
managed dynamically in units of 32 bytes. This also explains the odd number of 224 maximum characters per
line: A list entry links to seven data blocks each containing 32 bytes (7 * 32 = 224). The pointers used
in the linked list contain three bytes. The first two bytes give the address in the 16 bit memory window 
to which the 32 byte block is mapped when brought into view by the MMU and the third byte contains the 8K 
block number which can be written directly into the corresponding MMU register.

On an unexpanded system 384 KB (48 8 KB blocks) of RAM are managed by `moreorless`. There would be an 
additional 64 KB (eight 8 KB blocks) available which have been excluded as a reserve for future extensions.
When a RAM expansion cartridge is present the memory available to `moreorless` is increased to 640 KB.

# Remarks

## Viewing and editing SuperBASIC programs

`moreorless` allows you to create BASIC programs in a more or less usable (pun intended) editor. When you press 
`Alt+b` you can write the current contents of the file to the selected drive while `moreorless` adds the line 
numbers automatically. If you refrain from using `goto` and `gosub` you can therefore write SuperBASIC programs 
without using the built in screen editor.

It is also possible to load existing SuperBASIC programs with `moreorless` (i.e. files including the file numbers). 
SuperBASIC can cope with either LF or CR as a line ending character and CR seems to be the default. So if you 
can not load a SuperBASIC program into `moreorless` try to switch to the CR line ending at program start. 

SuperBASICs `list` command performs pretty printing when showing a program. I.e. it for instance automatically
indents certain parts of the program and does syntax highlighting. `moreorless` will not perform any pretty
printing when showing or editing a BASIC program. On the other hand it allows you to look at and edit the program 
in a much more comfortable way. Additonally you can add your own indentation when editing the source code. 

## Search and replace

If you want to perform a search and replace operation with `moreorless` you have to set a search string via 
`Foenix+f`. If you then place the cursor at the beginning of an occurance of the search string you can replace
that occurance with the replace string by pressing `F5`. You can then search for the next occrance via `F3` or
`F7`. The default replace string is the empty string but you can change that via `Foenix+r`. You can set the replace
string before setting a search string but you will not be able to actually perform the replace operation before a
search string is set.

## Some plans

I am in the process to extend this software to make it a better text editor. I have finished implementing the
features which I think are a must have. This is how I plan to progress:

Short term goals
- adding a command to indent a group of lines
- adding a command to un-indent a group of lines

Midterm goals
- use a beep to signal to the user that a command excecution is not possible

After that possibly
- adding an undo feature (I have no clear plan on how to achieve this, yet)
- adding some sort of mouse support

I am at the moment optimistic that I can keep the overall length of the assmebled program below 32KB which would 
allow to use the 8K block starting at $8000 as a window to map in some sort of yet unspecified extension code.

My 6502 simulator [`6502profiler`](https://github.com/rmsk2/6502profiler) has been eminently useful in testing
the memory managment, linked list functionality and any other piece of the software which is not part of the UI.

# Building the software

You will need `64tass`, GNU `make` and a Python3 interpreter in order to build the software. Configure the
port in the makefile in order to use the target `upload` which, after bulding the software, uploads it to
your F256 via the USB debug port and executes it. Build the target `test` in order to run all test cases
(this requires `6502profiler`).