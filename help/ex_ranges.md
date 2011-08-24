# Ex command ranges

Many [ex commands](ex_cmds.html) accept a range of lines to operate
upon. The range precede the command name and consists of zero, one or
two line addresses separated with comma. 

A line address can be written as:

  * an absolute line number, ie <kbd>3</kbd>
  * <kbd>$</kbd> denotes the last line
  * <kbd>.</kbd> (a dot) referes to the current line
  * a mark (eg <kbd>'x</kbd>)
  * <kbd>%</kbd> denotes all lines, same as <kbd>1,$</kbd>
  * a forward search pattern, delimited by slashes, eg <kbd>/foo/</kbd>
  * a backward search pattern, delimited by question marks, eg <kbd>?foo?</kbd>

Additionally, a line offset may be appended to a line address with
<kbd>+</kbd> or <kbd>-</kbd>. For example, <kbd>.+2</kbd> means two
lines after the current line.

