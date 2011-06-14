# Ex command ranges

Many [ex commands](ex_cmds.html) accept a range of lines to operate
upon. The range preced the command name and consists of zero, one or
two line specifiers separated with comma. 

A line specifier can be written as:

  * an absolute line number, ie <kbd>3</kbd>
  * <kbd>$</kbd> denotes the last line
  * <kbd>.</kbd> (a dot) referes to the current line
  * a mark (eg <kbd>'x</kbd>)
  * <kbd>%</kbd> denotes all lines, same as <kbd>1,$</kbd>

Additionally, a line offset may be appended to a line specifier with
<kbd>+</kbd> or <kbd>-</kbd>. For example, <kbd>.+2</kbd> means two
lines after the current line.

