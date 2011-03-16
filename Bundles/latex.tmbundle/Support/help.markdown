# Installing LaTeX

To use `Typeset & View` and other commands from the LaTeX bundle you will need to install a TeX package separately.

We recommend that you use [MacTeX][] to install the necessary parts as it comes with a standard “no questions asked” installer.

As of this writing, the installer also takes care of updating your `PATH` variable (by modifying `/etc/profile`) so TextMate will be able to find the installed `pdflatex`. If you are using another distribution you may need to [setup the path manually](http://macromates.com/textmate/manual/shell_commands#search_path).

[mactex]: http://www.tug.org/mactex/

# Building a LaTeX File

## Standard Typesetting

Most of the time you will want to typeset the currently selected file. This is accomplished by the command `Typeset & View`, bound to `⌘R`. TextMate shows you, in its HTML output window, progress on the compile, as well as any errors that may occur.

Depending on the setting of the Keep log window open preference, this window may stay open, and you can click on any of the errors encountered, which will take you to the corresponding location in the LaTeX file, where that error is reported to have occurred. Keep in mind, that LaTeX occasionally reports errors very far from where the actual problem occurs. So compile often, so that you have less new text to worry about when looking for errors.

## Typesetting Multiple Passes

Because LaTeX processes files in a single pass, it is often required to compile more than once to resolve all references, or possibly even run `bibtex` and/or `makeindex` in-between. You can re-run LaTeX on the same file by clicking on the Run LaTeX button at the bottom of the Typeset & View window.  You will also find buttons there to allow you to run BibTeX or MakeIndex on the current file.

In addition, The `latexmk.pl` script does all the compiling necessary for things to be right. In order to tell TextMate to use `latexmk.pl` when compiling, you have to check the `Use Latexmk.pl`.

<!-- NOT NECESSARY ANY MORE: See [9.2 Static Variables](?static_variables) in the TextMate manual for how to setup environment variables. -->

<!-- Note further, that if you have some other complicated compiling system, using a makefile for example, you can use that instead of `latexmk.pl`. You can use the variable `TM_LATEX_OPTIONS` to set command line options for your script. -->

<!-- Probably not relevant any more: TODO: Update this section if a new command is created for `latexmk.pl` -->

## Using a Master File

### Using the `TM_LATEX_MASTER` Environment Variable

If you work on a large project, you would want to use TextMate's [support for projects](?working_with_multiple_files), and split your project in chapters, using a master file that then includes the various chapters via `\include`.

If you have created a project file, then you can set *project specific environment variables* via the project info button on the bottom right of the project drawer. You should set such a variable with a name of `TM_LATEX_MASTER` and the **absolute path to the master tex file** as value. If you are instead using a scratch folder, you can use the trick explained [here][scratch-folder]. Effectively, if a folder has a file called `.textmate_init`, then whatever shell code is specified there will be executed right before any command that is ran for a file located in this folder. So for instance this file could contain a line like this:

    export TM_LATEX_MASTER=master_file_or_whatever

This allows, among other things, creating folder specific variables for scratch projects.

When the `TM_LATEX_MASTER` variable is set, then all LaTeX commands use the master file pointed to by this variable as their basis. In particular, the `Typeset & View` and `Watch document` commands will typeset the master file, instead of whatever the currently active file is. So you can freely edit whatever chapter you are working on, and when you want to see the result you just press `⌘R` without having to worry about switching to the master file. The error window that may show up is arranged so that clicking any of the errors opens up the corresponding `\include`'d file where the error occurred, and places the caret at the appropriate location.

There is a way to arrange it so that the individual chapters can be compiled by themselves, and still work fine when included via the `\include` command. If that is something that might interest you, then [this thread from the mailing list][included-chapters] might interest you. 

TODO: Mention that `TM_LATEX_MASTER` can be relative to the project directory (or directory of current file) -- this way one can set it in the global preferences if one always use the same name of the master file.

[scratch-folder]: http://lists.macromates.com/pipermail/textmate/2006-July/012151.html
[included-chapters]: http://thread.gmane.org/gmane.editors.textmate.general/10474/focus=10481

### Using the %!TEX root directive

TextMate also supports embedded directives in your TeX file by placing a line at the beginning of your document that looks like the following `%!TEX root = my_root`  This allows you to specify a master file without using the `TM_LATEX_MASTER` environment variable.  The files you specify using the `root = ` directive can be either absolute or relative.

## Watching a document

### Introduction

When you watch a LaTeX document, it is continually monitored for changes.
When you save a change, the document will be typeset again, and the preview updated. The preamble (i.e. everything before the `\begin{document}` command) is recompiled only when you change it; the rest of the time, only the main body of the document is recompiled. So the update cycle is substantially faster than typesetting the whole document from scratch.

### Usage

Press ⌃⌘W to start watching a document. If the document is already being watched, you will instead be given the option to stop watching it. You can watch several documents simultaneously.

When you close the previewer, the associated watcher will automatically quit.

### Troubleshooting

In case of trouble, you may find some useful information in the system console. If you set the shell variable `TM_LATEX_WATCH_DEBUG=1` then additional diagnostic information is printed to the console, which may be helpful.

# Previewing a LaTeX File

The `Typeset & View` command has a second component, the `View` one. After a successful build, TextMate proceeds to show you the PDF file created if you have checked the `Show pdf automatically` checkbox in the preferences.  This preference is on by default.  If the preference is not checked, you can still view the file on demand by clicking the View button at the bottom of the `Typeset & View` window.  There are a number of possibilities at this point which will be explained in the following sections.

## Default Preview

Since Tiger, HTML windows can show PDF files. This is the standard behavior. The window that was used to show you the building progress now turns into a view of your PDF file, provided there were no errors.

## Installing PDF Browser Plug-In

An alternative to the default PDF viewing capability of Tiger is [Schubert’s PDF Browser Plugin][pdf-browser]. This has some nice additional features such as allowing you to print the PDF directly from the window and it works on Panther as well.

Note: If you have the Adobe Reader installed then you might have the problem that this installs a handler for PDF files which in the worst-case can cause TextMate to crash when displaying PDF files.

To avoid this open the preferences for Adobe Reader and go to the Internet category. There uncheck “Display in PDF browser using:” and “Check browser settings when starting Reader” — if the latter is not unchecked, it will take over again when it gets a chance. You may need to relaunch TextMate afterwards.

[pdf-browser]: http://www.schubert-it.com/pluginpdf/

## External Previewers

You can also setup an external previewer for showing the PDF output. Focus will then switch to that previewer. Any program that opens PDF files will do, but there are three standard options, Apple's own Preview,  [TeXniscope][], or [Skim][].  Skim is a very nice viewer that is under active development.

We recommend you use either Skim, if you are only going to be dealing with pdf files, or TeXniscope if you will also be dealing with dvi files. They both support pdfsync, though TeXniscope is not a universal binary as of this writing.

To use one of these previewers, you must set the Viewer preference in the Preferences panel.

[texshop]: http://www.uoregon.edu/~koch/texshop/
[texniscope]: http://www.ing.unipi.it/~d9615/homepage/texniscope.html
[skim]: http://skim-app.sourceforge.net/

## Preview Options

Preview options are somewhat complicated depending on the viewer you choose.  There are really two main cases:

1. If you chose to use the previewer built in to WebKit then the “keep log window open preference” has the following effect:
    * If there are no errors or warnings, the `Typeset & View` window will immediately switch to showing you the pdf file.
    * If there are no errors but some warnings then, if the “keep log window open” preference is checked you will see the warning messages, and you must click the `View in TextMate` button to see the pdf.  If the keep log window open preference is not checked then the warning messages will be ignored and you will see the pdf.
2. If you use an external viewer then the `Typeset & View` window will automatically close if there are no errors or warnings, unless the “keep log window open” preference is checked.

## Refreshing the Viewer
The `Typeset & View (PDF)` command uses a short Applescript to tell Skim, TeXniscope, or the TeXShop viewers to reload the pdf file once ALL the typesetting is complete.  This is more efficient than enabling the auto-refresh feature in the viewers because it often takes more than one run of LaTeX before the document is really ready to view.  In that case most viewers would try to reload the pdf multiple times.

# PDFSync

The [pdfsync][] package allows you to easily hop back and forth between the document and generated PDF version, granted you use an external previewer which supports pdfsync. In the following we will assume the use of TeXniscope or Skim.

[pdfsync]: http://itexmac.sourceforge.net/pdfsync.html

You need to perform the following steps to enable synchronization:

 1. In your LaTeX document add `\usepackage{pdfsync}` (near the top) to enable creation of synchronization data. The required `pdfsync.sty` file is normally not included with tex distributions but is included in the LaTeX bundle.

    If you use the `Typeset & View (PDF)` command (bound to `⌘R` by default) then it will setup `TEXINPUTS` so that the bundled `pdfsync.sty` is found.

    If you typeset your documents from elsewhere, you need to install `pdfsync.sty` e.g. in `~/Library/texmf` (this might depend on your distribution of tex).

 2. Set your viewer to `Skim`. This enables you to use the `Show in PDFViewer (pdfsync)` command bound to `⌃⌥⌘O` by default.

 3. In TeXniscope go to the preferences. There, set the following two options:

        Editor: mate
        Editor options: -l %line "%file"
In Skim these are already set by default.

    This assumes that you have installed `mate` (see Help → Terminal Usage… in TextMate). You may want to provide a full path to `mate` if it is not found by TeXniscope. After this is done, command-clicking (⌘) at a location in the PDF file (as shown in TeXniscope/Skim) should take you to the corresponding location in TextMate.

**Note 1:** PDFSync does not work when your filename contains a space.

**Note 2:** The granularity of the synchronization data is generally “per paragraph”, so going from TextMate to TeXniscope or back will generally locate just the paragraph nearest your desired position.

**Note 3:** Problems have been reported with the universal build of TeXniscope. So Intel users may want to run TeXniscope under Rosetta, or use Skim instead.

**Note 4:** In Skim, you need to shift-command-click, instead of command-clicking, to be taken back to TextMate.

# Working With LaTeX

This section describes the various LaTeX tasks, and how they can be accomplished with the commands provided in the bundle. Some of the commands whose behavior is clear from their name (like `Format ⇢ Bold` and friends) are not included here, so you will need to traverse the submenus of the LaTeX bundle to discover them.

## Automated Typing

Writing LaTeX often requires typing some amount of standard commands and environments. TextMate makes that a lot easier with a set of commands in the LaTeX bundle, that we'll discuss in this section.

### Completing Commands and Environments

The LaTeX bundle contains two commands that, if you type a lot of LaTeX, will become your best friends. They are `Insert Environment Based on Current Word`, bound by default to `⌘{`, and `Insert Command Based on Current Word`, bound by default to `⌃⌘}`. They create an environment/command based on the current word, or with a default editable text in the absence of a current word. They are smart enough to understand a number of “standard” shortcuts, also called triggers. For instance, typing `thm` and then calling the `Insert Environment Based on Current Word` command creates:

        \begin{theorem}
            | ← insertion point
        \end{theorem}

Similarly, typing `fig` followed by calling the `Insert Environment Based on Current Word` command creates a lot of the standard text required in a figure environment. You can further customize these commands.

These two commands understand a series of shortcuts, and use the current word if they don't recognize it as a shortcut. You can customize what these shortcuts are by editing the *LaTeX Configuration File*. This file is originally kept in the LaTeX bundle. When you first use the `Edit Configuration File` command, this file is copied to the file `~/Library/Preferences/com.macromates.textmate.latex_config.plist`. You can then edit this file whenever you want by executing this command, or delete it to return to the default settings.

This file follows the [Property List Format](?property_list_format). It consists of a top-level dictionary with six entries:

  * `commands`
  * `commands_beamer`
  * `environments`
  * `labeled_environments`
  * `environments_beamer`
  * `labeled_environments_beamer`

The versions with the word `beamer` added are the *extra* shortcuts/words that get recognized in LaTeX Beamer, *in addition to the non-beamer ones*. The `commands` and `commands_beamer` entries are dictionaries consisting of pairs, where the key is the shortcut to be recognized, and the value is the  text to be inserted when the shortcut is found. **All inserted text, for both commands and environments, is interpreted as a [Snippet](?snippets)**.

The four `environment` dictionaries are a bit different. They have key-value pairs, where the key is the *name* of the environment, i.e. the text to be placed inside the braces in `\begin{}`. The value is itself a dictionary with two entries:

  * `triggers` is the list of shortcuts/words that will trigger this environments to be inserted.
  * `content` is a string representing the text to be inserted inside the environment. If the environment is in one of the two `labeled\_environments` groups, then this text is inserted right after the closing brace in `\begin{env}`, so as to allow for the addition of labels. Otherwise, it is inserted starting on the next line.

See the many examples already present in the file.

**Note:** Up to TextMate Version 1.5.3 (1215), a different system was used to configure the behavior of the text to be inserted, using a number of environment variables. This system has been abandoned in favor of the Configuration File.

Another useful command is `Insert Environment Closer`, which is by default bound to `⌥⌘.`. This command locates the innermost `\begin{foo}` that hasn't been closed by a corresponding `\end{foo}` and inserts the closing part. Of course if you have used the `Insert Environment Based on Current Word` command, then you probably don't need this much.

Finally, there is a command to quickly insert commands for the various symbols, called `Insert Symbol based on Current Word`. It is bound by default to `⌘\`. It works in two stages:

  * First, you have to trigger the command, by typing a couple of letters first. The rules are basically as follows:
    * Single letters are converted to greek letters
    * Two letter combinations are converted to the various commands starting with those two letters (for instance pressing `in` would trigger commands like `\int`, `\inf`, `\infty` etc) with a few exceptions, like `sk` for skip.
    * Three letter combinations are converted to arrows, where the three digits signify the kind of arrow, for instance `lar` would stand for left arrows.
    * There's a couple of exceptions to these rules, which you can look at and alter in the LaTeX configuration file, under the `symbols` key.
  * Once you have triggered the command once, pressing it again cycles you through the various options. For instance, if you started with `e`, you would be cycling between `\epsilon` and `\varepsilon`. This is accomplished by this set of entries in the configuration file:

        "e" = "\\epsilon";
        "epsilon" = "varepsilon";
        "varepsilon" = "epsilon";

When you create your own additions to this list, keep in mind these two simple principle: For the item that is the initial trigger, like the `"e"` above,  the text to be used must contain the two backslashes. For the items used for cycling through options, it must not.

### List Environments (inserting \item)

The most commonly used environments are the three itemize environments, `itemize`, `enumerate` and `description`. These can be created by the `Insert Environment Based on Current Word` command via the shortcuts `it` and `en`, as well as `item` and `enum`, and the first `\item` is automatically entered for you. Then, when you want to create a new item, pressing `enter` (`⌅`) automatically inserts the required `\item` in front. This is a functionality common among most languages in TextMate that support some sort of list.

There is also a `Lines to List Environment` command, bound to `⌃⇧L`, which wraps the selected group of lines inside a list environment (`enumerate`, `itemize`, or `description`). Each non-blank line becomes an `\item` in the environment. If the first 20 characters of the line contain a `:` it is assumed that the environment will be a description environment and all the characters up to the `:` are placed inside left/right brackets.

### Wrapping Text

Often one wants to enclose the currently selected text in an environment, or a command. The LaTeX bundle offers a list of `Wrap Selection In…` commands for all tastes. Here they are:

* `Wrap Selection in Command` (`⌃⇧W`): Wraps the selected text in a LaTeX command, with default value `textbf`. This is a trigger with two parts: You can override the entire `textbf` word to get something like `emph` or whatever you want. Optionally, you can press tab to have the “text” part stay there, and the `bf` part get highlighted for overriding, so as to be able to get `textit` and `texttt` easily. It should however be mentioned that you can use `⌘B`, `⌘I`, and `⌘K` for stylistic changes (bold, italic, and typewriter).
* `Wrap Selection in Environment` (`⌃⇧⌘W`): Wraps the selected text in an environment. Also works without a selection.
* `Wrap Selection in Double Quotes` (`` ⌃` ``): Wraps the currently selected text in LaTeX double quotes, i.e. ` ``selection here'' `.
* `Wrap Selection in left…right` (`⌃⇧L`): Wraps the currently selected text in the \left-\right pair, so that if the selection is for instance `(text here)`, then it would become `\left(text here\right)`.
* `Wrap Selection in Display Math`
* `Wrap Selection in Math Mode`

## Completion

The LaTeX bundle adds the following words to the list of completions (accessed through `⎋`): corollary, definition, description, enumerate, equation, itemize, lemma, proof, proposition and verbatim. *Comment: Is that really used at all? Should we add (a lot) more words?*

LaTeX overrides the standard completion behavior when the caret is inside a `\cite{}` or `\ref{}` block, (as well as all other equivalent commands like `eqref`, `vref`, `prettyref`, `citeauthor` etc).

In the case where what is expected is a bibliography key, pressing escape when the caret is inside the braces offers completion with respect to all cite keys. This is accomplished by scanning all bib files linked to from the TeX file via a `\bibliography` command. For instance if the caret is right before the closing brace in `\cite{Ka}`, then pressing escape will offer as completion options all bibliography keys starting with `Ka`.

In the case where what is expected is a label, then pressing escape will similarly offer all matching labels from the TeX document. Depending on your naming conventions, this could for instance offer a list of all theorems: If the labels for theorems are all of the form `thm:labelname`, **and** you have included the colon (`:`) in the list of word characters in TextMate's preferences, then pressing escape when the caret is right before the closing brace in `\ref{thm}` will offer as completion options all labels corresponding to theorems.

If there are many matching completions, it is often more convenient to use the pull-down-list versions of the commands, which are triggered by `⌥⎋`.

Note further, that the completion commands will recursively search inside `\include`'d files as well, starting from either the current file or `TM_LATEX_MASTER`, if that is set.

The both the label and bibliography completion commands actually work even when not inside a `\ref{}` or `\cite{}` block. They will then insert the `\ref` or `\cite` for you. You can just start typing the first letters of the label or bibliography data you want, and then press `⌥⎋` to activate the commands.

## Advanced Tasks

### LaTeX Beamer

LaTeX has particular support for the [Beamer document class][beamer]. Namely, the “Insert Environment…” and “Insert Command…” commands understand more shortcuts, and also behave intelligently with respect to older shortcuts, adding overlay specifications where appropriate. The same goes for the “Lists ⇢ New Item” command.

In order for all this to work, make sure that the language for the document is set to “LaTeX Beamer” (⌃⇧⌥B).

[beamer]: http://latex-beamer.sourceforge.net/

### Drag and Drop

There are two key drag and drop commands in LaTeX: 

* You can drag an image file in to the document and have it surrounded by a complete figure environment. Using the modifier key `⌥` while dragging inserts the image inside a `center` environment. Using `⇧` instead inserts only the `\includegraphics` line.
* You can drag in another .tex file to have that file added to your document with an `\include` command.

### Templates

There are two template systems in place right now. The one is TextMate's built in Templates support. To start from a template file, select File ⇢ New From Template ⇢ LaTeX and choose the template you prefer. There are two choices:

* Article: Sets up a single file article document. Includes lots of nice packages for graphics, math, code listings, table of contents, etc.

* Exam: Sets up a single file exam document. If you write exams in LaTeX this is the template for you. Includes lots of nice packages for graphics, math, code listings, table of contents, etc.

The other system is specific to the LaTeX bundle, and it is triggered via the command `Insert LaTeX Template`. This template requires that you create a directory `~/Library/Application Support/LaTeX/Templates`. In there you can put any files you like. When you execute the command, it will offer you a pop-up list of all files in the directory, to choose from. Selecting one of these files will then result in the contents of that file being inserted at the cursor's location. This way you can create your own custom templates and store them there, and then you have quick and easy access to them. The command has a tab trigger of `temp`, so a typical workflow would be:

* Create new file (`⌘N`)
* Set Language to LaTeX (`⇧⌃⌘L`, possibly followed by `2`)
* Type `temp` and press tab
* Use arrows/keys/mouse to select template file and press return
* Start working on your masterpiece

# Preferences
## Global Preferences
You can bring up the Preferences panel for LaTeX by running the Preferences command or typing `⌥⌘,` in any LaTeX window.  The Preferences window allows you to set options for typesetting and viewing.  For typesetting you can set the following options:

* *Default Engine:*  You can choose a typesetting engine from the dropdown list.  Note:  This engine is the fallback engine.  The LaTeX `Typeset & View` command can override the default in two ways:
  + If you use a `%!TEX TS-program = ` directive in your source file. (See below)
  + If you include packages that indicate you should use plain LaTeX, or xeLaTeX
  
* *Options:*  If you have specific options that you will usually want to pass to the engine you have selected you can set them here.  Note:  If you have options that are specific to a single file you are better off to use the `%!TEX TS-options = ` directive at the top of your source file.

* *Use Latexmk.pl:*   TextMate includes the popular latexmmk.pl script which automatically runs latex, bibtex, and makeindex as many times as needed to resolve all cross references and citations in your file.  To use latexmk.pl just check this box.

Latexmk.pl will use the engine and any options you specify in the preferences window, or any `%!TEX` directives in an individual file.

* *Verbose TeX output:*  If you want to see the raw LaTeX log file in real time, check this box.

For Viewing the typeset file you can set the following options:

* *View in:*  Select from the viewers that are supported. We recommend you install and use Skim.
* *Show pdf automatically:*  If you want the viewer started automatically after typesetting check this box.
* *Keep log window open:*  If you want the log window to stay open so you can check on any errors or warnings check this box.

When using TextMate as the viewer, instead of an external viewer like Skim, you should keep the following in mind:  “Show pdf automatically” will not bring up the pdf file if there are any errors or warnings if “Keep log window open” is checked.  If “keep log window open” is not checked then the pdf file will automatically replace the log if there are no errors.  In this case any warnings you see will be ignored.

## Local Preferences
When working with LaTeX there are three local options that you can set on a per file basis.  As mentioned above these options will override the preferences that you set using the preferences interface.

The best way to set local options is to use the `%!TEX` directives.  They are as follows:

* `root`  This allows you to set a master file.  When you are working on a project where you have a master file that \inputs or \includes several other files you can set the master file using `%!TEX root = mymaster.tex`.  There is also a handy Bundle command that allows you to select the file you want to use as master.  In addition to the root directive you could also choose to set the `TM_LATEX_MASTER` environment variable.  This is a bit handier if you are working on a project and want to set the master file just once.

* `TS-program`  To override the typesetting engine for a particular file you can use this directive.  This can be a standard LaTeX typesetting engine like `xelatex`, `pdflatex`, or `latex` or this could refer to your own custom typesetting script.  For example `%!TEX TS-program = xelatex`

* `TS-options`  To add specific options that you want for your this particular file you can set them here.  Note:  Whatever options you choose to set using this directive will come after the built in options of `"-interaction=nonstopmode -file-line-error-style"`

# Credits

There were at least two or possibly three versions of a LaTeX bundle floating around in the early days of TextMate by (I think): Normand Mousseau, Gaetan Le Guelvouit and Andrew Ellis At some point, January 2005, Eric Hsu pulled together the threads into one package. From then on there have been contributions by Sune Foldager, Brad Miller, Allan Odgaard, Jeroen van der Ham, Robin Houston and Haris Skiadas. 

Happy LaTeXing!
