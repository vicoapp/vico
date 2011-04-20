# Deleting text

The simplest deletion command is <kbd>x</kbd>. It deletes the character under
the caret. A count before deletes that many characters, e.g. <kbd>10x</kbd>
deletes 10 characters.

The <kbd>D</kbd> command deletes from the current location to the end of the
line.

The <kbd>d</kbd> command is an [operator](operators.html) and thus must be
combined with a motion command. For example, <kbd>dw</kbd> deletes a word,
<kbd>d3W</kbd> deletes 3 big words, and <kbd>dd</kbd> deletes the current line.

The <kbd>c</kbd> (change) command is similar to the <kbd>d</kbd> command, but
also enters insert mode.

  * [Changing text](change.html)

