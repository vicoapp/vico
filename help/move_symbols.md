# Moving by symbols

The <kbd>ctrl-]</kbd> key (in normal mode), jumps to the symbol under the caret.

If you have a [tags](http://ctags.sourceforge.net/) file, Vico will try to
lookup the current word as a tag.

If no tag was found, Vico tries to match the current word with a
[symbol](symbols.html). If more than one match is found, you are presented with
a menu.

If a tag or symbol is found, the current location is pushed on the
[tag stack](tagstack.html), and the caret is jumped to the new location.
Press <kbd>ctrl-t</kbd> to go back.

