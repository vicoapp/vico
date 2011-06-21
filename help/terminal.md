# Terminal usage

Vico includes a command line tool that can be used to launch vico from
the shell.

To use the tool from the command line, create a link from the
application bundle to a directory in your PATH. If you have a
<kbd>bin</kbd> directory in your home directory, create it as:

	ln -s /Applications/Vico.app/Contents/MacOS/vicotool ~/bin/vico

If you want to install it for all users on the machine, create the link
in a global directory (this requires administrator privileges):

	sudo ln -s /Applications/Vico.app/Contents/MacOS/vicotool /usr/local/bin/vico

If Vico is not stored in your /Applications folder, adjust the command
appropriately. Once the link is created, it will be kept up-to-date
when Vico is updated.

To open a file with Vico from the shell, simply type:

	vico filename

You can open multiple files at once, also using globbing characters (eg,
<kbd>vico *.py</kbd>). If you specify a directory, Vico will display a
new window with the directory selected in the explorer sidebar.

If you want to use Vico in your <kbd>$EDITOR</kbd> variable to edit
commit messages, you need to use the <kbd>-w</kbd> switch. This makes
Vico wait until the document is closed to return. The return code from
vicotool is 0 if the document saved successfully before closing, and
non-zero if it wasn't saved.

To see a quick description of the command line usage, use the
<kbd>-h</kbd> option:

	$ vico -h
	syntax: vicotool [-hrw] [-e string] [-f file] [-p params] [file ...]
	options:
	    -h            show this help
	    -e string     evaluate the string as a Nu script
	    -f file       read file and evaluate as a Nu script
	    -p params     read script parameters as a JSON string
	    -p -          read script parameters as JSON from standard input
	    -r            enter runloop (don't exit script immediately)
	    -w            wait for document to close


