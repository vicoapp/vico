(let ((ex (ExMap defaultMap)))
    (ex define:"!"
        syntax:"rex|"
            as:"ex_bang:"
parameterNames:'("range" "shell command")
 documentation:<<-BANG_DOC_END
    Execute +shell command+ with the current shell
    (taken from the "SHELL" environment variable). The
    command runs in a non-interactive shell.
    
    If +range+ is given, the output from the command's
    "STDOUT" replaces the text in +range+. Otherwise,
    output is shown in an extension to the command
    popup.
BANG_DOC_END)
    (ex define:"#"
        syntax:"rc"
            as:"ex_goto:"
parameterNames:nil
 documentation:<<-GOTO_DOC_END
    Take the cursor to the first non-blank character of
    the line specified in +range+.

    If +range+ is omitted, the current line is used as
    the range.
GOTO_DOC_END)
    ;(ex define:"&"             syntax:"em"     as:"ex_subagain:")
    ;(ex define:'("*" "@")      syntax:"R"      as:"ex_at:")
    ;(ex define:"<"             syntax:"rc"     as:"ex_shift_left:")
    ;(ex define:">"             syntax:"rc"     as:"ex_shift_right:")
    ((ex define:'("buffer" "b")
         syntax:"E1"
             as:"ex_buffer:"
 parameterNames:'("buffer name")
  documentation:<<-BUFFER_DOC_END
      Switch the current split to display the buffer
      named +buffer name+. Does nothing if a buffer
      with the given name does not exist.
BUFFER_DOC_END)
        setCompletion:(ViBufferCompletion new))
    ((ex define:"sbuffer"
         syntax:"E1"
             as:"ex_buffer:"
 parameterNames:'("buffer name")
  documentation:<<-SPLIT_BUFFER_DOC_END
      Open a new horizontal split to display the
      buffer named +buffer name+. Does nothing if
      a buffer with the given name does not exist.
SPLIT_BUFFER_DOC_END)
        setCompletion:(ViBufferCompletion new))
    ((ex define:"vbuffer"
         syntax:"E1"
             as:"ex_buffer:"
 parameterNames:'("buffer name")
  documentation:<<-VERTICAL_BUFFER_DOC_END
      Open a new vertical split to display the
      buffer named +buffer name+. Does nothing if
      a buffer with the given name does not exist.
VERTICAL_BUFFER_DOC_END)
        setCompletion:(ViBufferCompletion new))
    ((ex define:"tbuffer"
         syntax:"E1"
             as:"ex_buffer:"
 parameterNames:'("buffer name")
  documentation:<<-TAB_BUFFER_DOC_END
      Open a new tab to display the buffer named
      +buffer name+. Does nothing if a buffer with
      the given name does not exist.
TAB_BUFFER_DOC_END)
        setCompletion:(ViBufferCompletion new))
    ((ex define:"bdelete"
         syntax:"!e1"
             as:"ex_bdelete:"
 parameterNames:'("buffer name")
  documentation:<<-BUFFER_DELETE_DOC_END
      Deletes the buffer named +buffer name+. This
      removes the buffer from the open buffer list
      and prevents it from being referenced by other
      commands that refer to a buffer by name.

      If +buffer name+ is not specified, the current
      buffer is deleted.

      If +!+ is not specified and the buffer has
      unsaved changes, the buffer will not be deleted.
BUFFER_DELETE_DOC_END)
        setCompletion:(ViBufferCompletion new))
    (ex define:'("cd" "chdir")
        syntax:"!e1x"
            as:"ex_cd:"
parameterNames:'("directory")
 documentation:<<-CD_DOC_END
      Changes the base directory for the current
      window to +directory+. If the directory does
      not exist, does nothing.

      If +directory+ is omitted, switches to the
      user's home directory.

      +!+ is accepted for historical reasons, but has
      no effect.
CD_DOC_END)
    (ex define:"close"
        syntax:"!"
            as:"ex_close:"
parameterNames:nil
 documentation:<<-CLOSE_DOC_END
      Closes the current view (split or tab) unless
      it is the last view in the window.
CLOSE_DOC_END)
    (ex define:'("copy" "t")
        syntax:"rL"
            as:"ex_copy:"
parameterNames:'("source lines" "destination line")
 documentation:<<-COPY_DOC_END
      Copies the lines given by +range+ and inserts
      them below +line+.

      If +range+ is omitted, the current line is used
      as the range.
COPY_DOC_END)
    (ex define:'("delete" "d")
        syntax:"rRc"
            as:"ex_delete:"
parameterNames:'("range" "destination register" "line count")
 documentation:<<-DELETE_DOC_END
      If +line count+ is not specified, deletes the
      lines in +range+ after storing them in
      +destination register+, which defaults to
      register x.

      If +line count+ is specified, deletes that many
      lines starting on the last line of +range+ after
      storing them in +destination register+.

      If +range+ is omitted, the current line is used
      as the range.
DELETE_DOC_END)
    (ex define:'("edit" "e")
        syntax:"!+e1x"
            as:"ex_edit:"
parameterNames:'("post-open command" "filename")
 documentation:<<-EDIT_DOC_END
      Opens +filename+ in the current view. If
      +post-open command+ is specified, it runs after
      the file has been opened.

      If +filename+ does not exist, a blank buffer is
      opened with that filename. Saving it will create
      the new file.

      If +!+ is not specified and the file open in the
      current view has unsaved changes, the file will
      not be opened.
EDIT_DOC_END)
    (ex define:"eval"
        syntax:"r"
            as:"ex_eval:"
parameterNames:nil
 documentation:<<-EVAL_DOC_END
      Evaluates the lines in +range+ as Nu code.
      
      If +range+ is omitted, the current line is used
      as the range.
EVAL_DOC_END)
    (ex define:"export"
        syntax:"E"
            as:"ex_export:"
parameterNames:'("variable=value")
 documentation:<<-EXPORT_DOC_END
      Sets +variable+ to +value+ in the current execution
      execution environment. This environment is used by
      bundles when they are executing external and
      internal commands.
EXPORT_DOC_END)
    ;(ex define:'("global" "g") syntax:"r%!/e|" as:"ex_global:")
    ;(ex define:"join"          syntax:"r!c"    as:"ex_join:")
    ;(ex define:'("mark" "k")   syntax:"re1"    as:"ex_mark:")
    ;(ex define:"map"           syntax:"!e"     as:"ex_map:")
    (ex define:'("move" "m")
        syntax:"rL"
            as:"ex_move:"
parameterNames:'("source range" "destination line")
 documentation:<<-MOVE_DOC_END
      Moves the lines in +source range+ to
      +destination line+.

      If +source range+ is omitted, the current line
      is used as the source range.
MOVE_DOC_END)
    ;(ex define:"put"           syntax:"rR"     as:"ex_put:")
    (ex define:"pwd"
        syntax:""
            as:"ex_pwd:"
parameterNames:nil
 documentation:<<-PWD_DOC_END
      Prints the current directory for the window. Commands
      run in this window will use this as their current
      working directory.
PWD_DOC_END)
    ;(ex define:"read"          syntax:"rfe1x"  as:"ex_read:")
    (ex define:'("s" "substitute")
        syntax:"r~c"
            as:"ex_substitute:"
parameterNames:'("range" "regular expression" "replacement" "flags" "line count")
 documentation:<<-SUB_DOC_END
      Replace all matches of +regular expression+ in
      +range+ with +replacement+. +flags+ are applied
      to +regular expression+ when matching.

      If +line count+ is specified, replaces matches in
      that many lines starting on the last line of
      +range+ instead of doing so directly in +range+.

      If +range+ is omitted, the current line is used
      as the range.
SUB_DOC_END)
    (ex define:"set"
        syntax:"e"
            as:"ex_set:"
parameterNames:'("option expression")
 documentation:<<-SET_DOC_END
      +option expression+ can have a few different forms:
       - +option+=+value+ sets the given option to the
         given value.
       - +nooption+ sets the given boolean option to false.
       - +option+ sets the given boolean option to true.
       - +option?+ prints the current value of the option.
         For boolean values, this is either "option" or
         "nooption".
       - +invoption+ or +option!+ toggles the given boolean
         option to the opposite of its current value.
       - "all" is currently not implemented, but will
         list all available options and their values.

      Options are typically user preferences, many though
      not all of which are available in the Vico preferences
      panel. They are currently set globally.
SET_DOC_END)
    ((ex define:"setfiletype"
         syntax:"E1"
             as:"ex_setfiletype:"
 parameterNames:'("filetype")
  documentation:<<-SETFILETYPE_DOC_END
      Sets the filetype of the buffer displayed in the
      current view to +filetype+.

      Filetypes are specified as bundle scopes, e.g.
      source.objc or text.haml.
SETFILETYPE_DOC_END)
        setCompletion:(ViSyntaxCompletion new))
    (ex define:"split"
        syntax:"e1x"
            as:"ex_split:"
parameterNames:'("filename")
 documentation:<<-SPLIT_DOC_END
      Opens a new horizontal split to display +filename+.
      The new split is opened above the current view, and
      the cursor is put into the new split.

      If +filename+ does not exist, a blank buffer is opened
      with that filename. Saving it will create the new file.

      If +filename+ is not specified, a new split is opened
      above the current one with the same file open at the
      same location.
SPLIT_DOC_END)
    (ex define:"vsplit"
        syntax:"e1x"
            as:"ex_vsplit:"
parameterNames:'("filename")
 documentation:<<-VSPLIT_DOC_END
      Opens a new vertical split to display +filename+. The
      new split is opened left of the current view, and the
      cursor is put into the new split.

      If +filename+ does not exist, a blank buffer is opened
      with that filename. Saving it will create the new file.

      If +filename+ is not specified, a new split is opened
      above the current one with the same file open at the
      same location.
VSPLIT_DOC_END)
    (ex define:"new"
        syntax:"e1x"
            as:"ex_new:"
parameterNames:'("filename")
 documentation:<<-NEW_DOC_END
      Opens a new horizontal split to display +filename+.
      The new split is opened above the current view, and
      the cursor is put into the new split.

      If +filename+ does not exist, a blank buffer is
      opened with that filename. Saving it will create the
      new file.

      If +filename+ is not specified, a blank buffer is
      opened with no filename. Saving it will require a
      filename.
NEW_DOC_END)
    (ex define:"vnew"
        syntax:"e1x"
            as:"ex_vnew:"
parameterNames:'("filename")
 documentation:<<-NEW_DOC_END
      Opens a new vertical split to display +filename+. The
      new split is opened left of the current view, and the
      cursor is put into the new split.

      If +filename+ does not exist, a blank buffer is
      opened with that filename. Saving it will create the
      new file.

      If +filename+ is not specified, a blank buffer is
      opened with no filename. Saving it will require a
      filename.
NEW_DOC_END)
    (ex define:'("tabedit" "tabnew")
        syntax:"+ex"
            as:"ex_tabedit:"
parameterNames:'("filename")
 documentation:<<-TAB_DOC_END
      Opens a new tab to display +filename+. The new
      tab is opened after the current one, and it takes
      the focus.

      If +filename+ does not exist, a blank buffer is
      opened with that filename. Saving it will create
      the new file.

      If +filename+ is not specified, a blank buffer is
      opened with no filename. Saving it will require a
      filename.
TAB_DOC_END)
    ;(ex define:"unmap"         syntax:"!e"     as:"ex_unmap:")
    ;(ex define:'("v" "vglobal") syntax:"r%/e|" as:"ex_vglobal:")
    ;(ex define:"version"        syntax:""      as:"ex_version:")
    (ex define:'("write" "w")
        syntax:"r%!f>e1x"
            as:"ex_write:"
parameterNames:nil
 documentation:<<-WRITE_DOC_END
      Writes +range+ of the current file to +filename+.

      Note: +range+ is not currently supported; specifying
      it will result in an error. If +range+ is omitted,
      the full file is used as the range.

      If +filename+ is not specified, writes to the name
      of the current buffer. If the buffer has no name,
      a save dialog will appear to allow you to choose
      a path and filename.

      If +!+ and +filename+ are both not specified, and the
      file on the filesystem was modified after it was
      last read by Vico, the file will not be overwritten.
WRITE_DOC_END)
    (ex define:"quit"
        syntax:"!"
            as:"ex_quit:"
parameterNames:nil
 documentation:<<-QUIT_DOC_END
      Closes the current view, like the close command.
      Unlike the close command, if this is the last view
      in the window, closes the current window as well.

      If +!+ is not specified and the file open in the
      current view has unsaved changes, the file will
      view will not be closed.
QUIT_DOC_END)
    (ex define:"wq"
        syntax:"r%!e1x"
            as:"ex_wq:"
parameterNames:'("range" "filename")
 documentation:<<-WRITEQUIT_DOC_END
      Writes +range+ of the current file to +filename+,
      then closes the current view as per "quit". In
      particular, if this is the last view in the window,
      closes the current window as well.

      Note: +range+ is not currently supported; specifying
      it will result in an error. If +range+ is omitted,
      the full file is used as the range.

      If +filename+ is not specified, writes to the name
      of the current buffer. If the buffer has no name,
      a save dialog will appear to allow you to choose
      a path and filename.

      If +!+ and +filename+ are both not specified, and
      the file on the filesystem was modified after it
      was last read or written by Vico, the file will
      not be overwritten and the view will not be closed.
WRITEQUIT_DOC_END)
    (ex define:'("xit" "exit")
        syntax:"r%!e1x"
            as:"ex_xit:"
parameterNames:'("range" "filename")
 documentation:<<-EXIT_DOC_END
      Writes +range+ of the current file to +filename+,
      then closes the current view as per "quit". In
      particular, if this is the last view in the window,
      closes the current window as well.

      Note: +range+ is not currently supported; specifying
      it will result in an error. If +range+ is omitted,
      the full file is used as the range.

      If +filename+ is not specified, writes to the name
      of the current buffer. If no changes were made, no
      write is done. If the buffer has no name, a save
      dialog will appear to allow you to choose a path and
      filename.

      If +!+ is not specified, and the file on the
      filesystem was modified after it was last read or
      written by Vico, the file will not be overwritten
      and the view will not be closed. If +filename+
      was specified, it *will* be written.
EXIT_DOC_END)
    (ex define:"yank"
        syntax:"rRc"
            as:"ex_yank:"
parameterNames:'("source range" "destination register" "line count")
 documentation:<<-YANK_DOC_END
      If +line count+ is not specified, stores the lines
      in +source range+ in +destination register+, which
      defaults to register x.

      If +line count+ is specified, stores that many
      lines starting on the last line of +source range+
      in +destination register+.

      If +source range+ is omitted, the current line is
      used as the range.
YANK_DOC_END)

    ; We can define these in straight Nu.
    (set console nil)
    (ex define:"console"
        syntax:""
            as:(do (command)
                 (if (== console nil)
                   (load "console")
                   (set console ((NuConsoleWindowController alloc) init)))

                 (console toggleConsole:nil))
parameterNames:nil
 documentation:<<-CONSOLE_DOC_END
      Toggles the Nu console to show or hide.
CONSOLE_DOC_END)

    (ex define:"reloadbundle"
        syntax:"e1x"
            as:(do (command)
                 (let (path
                        (if ((command arg) length)
                          (command arg)
                          (else
                               ((current-window) displayBaseURL))))
                   ((ViBundleStore defaultStore) loadBundleFromDirectory:path)))
parameterNames:'("bundle path")
 documentation:<<-RELOADBUNDLE_DOC_END
      Reloads the bundle at +bundle path+.

      If +bundle path+ is omitted, the working directory
      of the current window is used instead, as returned
      by the "pwd" command.
RELOADBUNDLE_DOC_END)
)
