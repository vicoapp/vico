# Visual mode

When you select text in Vico, you enter visual mode. This is similar to normal
mode in that keys act as commands. They do not replace the selected text (you
must use the [change](change.html) command for that).

Commands that require a motion ([operators](operators.html)) instead use the
selected text directly.

You can select text by dragging with the mouse, or with the <kbd>v</kbd> and
<kbd>V</kbd> commands. The latter enters visual **line mode**, where only
whole lines are selected. The selection is extended by moving around with the
regular [movement](movement.html) commands.

You can toggle between visual line mode and character mode by pressing
<kbd>v</kbd> while in line mode, or <kbd>V</kbd> while in visual character mode.

Press <kbd>&#x238B;</kbd> (escape) to cancel the selection and go back to normal
mode.

