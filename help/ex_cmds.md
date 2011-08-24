# Ex commands

The following [ex](ex.html) commands are available:

  * <kbd>:!</kbd> <shell command> &mdash; filter lines through shell command
  * <kbd>:b[uffer]</kbd> <name> &mdash; switch current view to another document
  * <kbd>:bd[elete]</kbd> &mdash; close the current document, opens an untitled file if last document closed
  * <kbd>:cd</kbd> <directory> &mdash; change current working directory
  * <kbd>:close</kbd> &mdash; close the current view
  * <kbd>:copy address</kbd> &mdash; copy the affected line range to the target line address
  * <kbd>:delete</kbd> <filename> &mdash; delete affected line range, or current line by default
  * <kbd>:edit</kbd> <filename> &mdash; edit a new file
  * <kbd>:eval</kbd> &mdash; evaluate the affected lines (or the current line) as a Nu expression
  * <kbd>:export</kbd> var=[value] &mdash; export an environment variable
  * <kbd>:move address</kbd> &mdash; move the affected line range to the target line address
  * <kbd>:new</kbd> &mdash; edit a new file in a new horizontal split
  * <kbd>:pwd</kbd> &mdash; show the current working directory
  * <kbd>:quit</kbd> &mdash; close the current document, closes the window if last document closed
  * <kbd>:s</kbd> /RE/replacement/[g] &mdash; replace lines matching RE with replacement
  * <kbd>:sbuffer</kbd> <filename> &mdash; split view horizontally and edit another open document
  * <kbd>:set</kbd> option[=value] &mdash; set an option
  * <kbd>:setfiletype</kbd> <syntax> &mdash; change the language syntax of the document
  * <kbd>:split</kbd> [filename] &mdash; split the current view horizontally, and optionally edit another file
  * <kbd>:t address</kbd> <filename> &mdash; alias for `:copy`
  * <kbd>:tabedit</kbd> <filename> &mdash; edit another file in a new tab
  * <kbd>:tabnew</kbd> &mdash; edit a new file in a new tab
  * <kbd>:tbuffer</kbd> <filename> &mdash; switch to a tab showing <filename>, or open a new tab
  * <kbd>:vbuffer</kbd> <filename> &mdash; split view vertically and edit another open document
  * <kbd>:vnew</kbd> &mdash; edit a new file in a new vertical split
  * <kbd>:vsplit</kbd> [filename] &mdash; split the current view vertically, and optionally edit another file
  * <kbd>:w[rite]</kbd> [new filename] &mdash; save the document, optionally with a new name
  * <kbd>:wq</kbd> &mdash; write the document and close it
  * <kbd>:x[it]</kbd> &mdash; write the document and close it

