# Changing text

The <kbd>c</kbd> (change) [operator](operators.html) deletes the affected text
and enters insert mode. The <kbd>cw</kbd> is one of the most used commands: it
changes one word. The change command is not considered complete until you exit
insert mode with <kbd>&#x238B;</kbd> (escape). Back in normal mode, you can
repeat the change with the [dot command](dot.html).

The (uppercase) <kbd>C</kbd> command deletes from the current location
to the end of the line, and then enters insert mode. It is the same as
<kbd>c$</kbd>.

Use the <kbd>r</kbd> (replace) command to change a single character. Vico waits
for you to type the new character. In [visual mode](visual.html), the
<kbd>r</kbd> command changes the whole selection to the same character.

The <kbd>s</kbd> (substitute) command replaces one, or, given a count,
that many characters and then enters insert mode. The uppercase variant
<kbd>S</kbd> is line-oriented and replaces one or more lines.
