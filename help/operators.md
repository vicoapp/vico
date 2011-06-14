# Operator commands

Some commands must be combined with a motion command to be complete. These
commands are called operators, as they operate on the text affected by the
motion command.

The standard operator commands are:

  * <kbd>d</kbd> -- delete
  * <kbd>c</kbd> -- change
  * <kbd>y</kbd> -- yank, or copy
  * <kbd>=</kbd> -- indent
  * <kbd>&lt;</kbd> -- shift left
  * <kbd>&gt;</kbd> -- shift right
  * <kbd>!</kbd> -- filter through external command
  * <kbd>gu</kbd> -- lowercase
  * <kbd>gU</kbd> -- uppercase
  * <kbd>gq</kbd> -- format text

You combine the operator with a motion just by entering the motion command
after the operator. For example, <kbd>cw</kbd> **c**hanges a **w**ord.

All operator commands can be doubled to imply the current line. This way,
<kbd>dd</kbd> deletes the current line, <kbd>&gt;&gt;</kbd> shift the current
line one [shiftwidth](indent_settings.html) to the right and <kbd>yy</kbd>
copies (yanks) the line.

