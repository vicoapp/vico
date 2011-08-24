# Moving by symbols

The <kbd>ctrl-]</kbd> key (in normal mode), jumps to the symbol under the caret.

If you have a [tags](http://ctags.sourceforge.net/) file, Vico will try to
lookup the current word as a tag. The `tags` file should be placed in
the windows current directory, ie the top-most directory displayed by
the [explorer](explorer.html).

If no tag was found, Vico tries to match the current word with a
[symbol](symbols.html). If more than one match is found, you are presented with
a menu.

If a tag or symbol is found, the current location is pushed on the
[tag stack](tagstack.html), and the caret is jumped to the new location.
Press <kbd>ctrl-t</kbd> to go back.

You can also use the <kbd>&#x21E7;&#x2318;T</kbd> key to search the
[symbol list](symbols.html).
