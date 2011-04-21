# The jumplist

Vico maintains a list of locations while you move around in files. Some movement
commands are considered "jumps", and those jumps are remembered in a list.

Generally, movement commands that generate jumps are those that
move more than a few lines. So the [word](move_words.html),
[character](move_chars.html) and [line search](line_search.html)
motion commands do not generate a jump, but the [line](move_lines.html)
and [search](searching.html) motions do.

You navigate the jumplist either by pressing the jumplist arrows in the toolbar,
or pressing <kbd>ctrl-o</kbd> to go back and <kbd>ctrl-i</kbd>
(or <kbd>tab</kbd>) to go forward. 

Only the last 100 jumps are remembered, and duplicates are removed.

