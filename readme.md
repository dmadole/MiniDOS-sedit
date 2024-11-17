# MiniDOS-sedit

This is a disk sector editor for Mini/DOS which allows viewing and modifying disk sectors at a logical sector and byte level. The program has two modes, a command line, and a visual-style hex editor.

The following are the commands that are valid at the command line. Note that each command can be abbreviated to any number of leading characters of each word, for example, "r l 0" is the same as "read lba 0".

|    Command    |                    Function                     |
|---------------|-------------------------------------------------|
| set drive <n> | Sets the disk being edited to drive <n>         |
| set <n>       | Shortcut for "set drive"                        |
| read lba <n>  | Reads the sector at LBA <n> into the buffer     |
| read au <n>   | Reads the first sector of allocation unit <n>   |
| read <n>      | Shortcut for "read lba"                         |
| read          | Reloads the sector already in the buffer        |
| au <n>        | Shortcut for "read au"                          |
| write lba <n> | Writes the buffer to the sector at LBA <n>      |
| write au <n>  | Writes the buffer to the first sector of au <n> |
| write <n>     | Shortcut for "write lba"                        |
| write         | Writes the buffer to the last sector accessed   |
| edit high     | Edits the buffer starting at offset 100h        |
| edit low      | Edits the buffer starting at offset 0           |
| edit <n>      | Edits the buffer starting at offset <n>         |
| edit          | Shortcut for "edit low"                         |
| display high  | Displays 256 bytes starting at offset 100h      |
| display low   | Displays 256 bytes starting at offset 0         |
| display       | Displays the last sector address accessed       |
| high          | Shortcut for "display high"                     |
| low           | Shortcut for "display low"                      |
| next lba      | Reads the sector after the last one accessed    |
| next          | Shortcut for "next lba"                         |
| previous lba  | Reads the sector before the last one accessed   |
| previous      | Shortcut for "previous lba"                     |
| zero          | Overwrites the buffer with all zero bytes       |
| quit          | Exits the program, discarding the buffer        |

The set command supports multiple disk drives under Mini/DOS when used with a compatible BIOS, and the read and write commands support 24-bit LBA, allowing 8GB of data space to be addressed.

The edit commands invoke the hex sector editor, which is visual in style, allowing the cursor to be moved around in the data bytes and values changed directly in place.

The only assumptions made about termianal control are the implementation of backspace, and of separate carriage return and line feed. Accordingly, vertical movement on screen is always on successive lines, even when moving backwards through the buffer.

The following keystrokes are valid in editor mode:

|     Key     |          Function          |
|-------------|----------------------------|
| `^C`        | Exit the editor            |
| `^H` or `H` | Move to prior digit        |
| `^J` or `J` | Move to next line          |
| `^K` or `K` | Move to prior line         |
| `^L` or `L` | Move next digit            |
| `^R` or `R` | Refresh display line       |
| `^X` or `X` | Exit the editor            |
| `Tab`       | Move to next byte          |
| `Space`     | Move to next digit         |
| `Backspace` | Move to prior digit        |
| `Return`    | Move to start of next line |

Note that following editor mode, the "write" command needs to be issued to commit the data back to disk. Otherwise, if another sector is read, or the program exited, any changes made int he buffer will be discarded.

