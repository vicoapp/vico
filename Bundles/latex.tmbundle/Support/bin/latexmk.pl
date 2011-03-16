eval '(exit $?0)' && eval 'exec perl -x -S "$0" ${1+"$@"}' && 
eval 'exec perl -x -S  "$0" $argv:q'
if 0;
#!/usr/bin/perl -w
#!/opt/local/bin/perl -w
#!/usr/local/bin/perl -w
# The above code allows this script to be run under UNIX/LINUX without
# the need to adjust the path to the perl program in a "shebang" line.
# (The location of perl changes between different installations, and
# may even be different when several computers running different
# flavors of UNIX/LINUX share a copy of latex or other scripts.)  The
# script is started under the default command interpreter sh, and the
# evals in the first two lines restart the script under perl, and work
# under various flavors of sh.  The -x switch tells perl to start the
# script at the first #! line containing "perl".  The "if 0;" on the
# 3rd line converts the first two lines into a valid perl statement
# that does nothing.
#
# Source of the above: manpage for perlrun

# Delete #??!! when working

# See ?? <===============================

# Results of 8 Sep 2007:

# Some improvements relative to the issues below.

# ????????:
# Why is bibtex not always running right?  Or running when it shouldn't
# I've put in rdb_make_links in a few places.  
# and rdb_write
# Problem is that aux file is always out of date, until after a
# primary run.  Ensure fdb and c. is updated enough etc.
# I may have it correct now: fdb_write in makeB
# See also routine rdb_update_files_for_rule, and who calls it

# Apparently excess runs of latex after change in .tex file that entails 
#   change in bibliography.  

# Now I am missing diagnostics


## ???!!!!!!!!!!!!! Should I remove bibtex rule?  NO
## ?? Need to set dependence of extra bibtex rules on .bib file
## ?? Put $pass as variable in rule.

#=======================================


#??  Check all code for rdb stuff.
#??  Use of $update and $failure, etc
#    Especially in pvc.  Should I restore source file set up
#       if there is a latex error??????????????????????
#??  Force mode doesn't appear to do force (if error in latex file)
#??? Get banner back in.
#??  ==> Clean up of rdb.  It accumulates files that aren't in use any more.
#        Restrict to dependents (existent or not) discovered during
#        parse of log file, and its consequences.
#??  CORRECT DIAGNOSTICS ON CHANGED FILES IF THEY DIDN'T EXIST BEFORE
#??  Further corrections to deal with disappeared source files for custom dependencies.
#       Message repeatedly appears about remake when source file of cusdep doesn't exist.
#??  logfile w/o fdb file: don't set changed file, perhaps for generated exts.
#    Reconsider
#??  Do proper run-stuff for bibtex, makeindex, cus-deps.  OK I think
#    Parse and correctly find bst and ist files
#??  Remove superfluous code when it's working.  Mostly done.
#??  update_source_times in particular.  I think it's done OK
#??  Add making of other files to rdb.  Unify
#??  Ditto for printing and viewing?
#??  Update documentation

# ATTEMPT TO ALLOW FILENAMES WITH SPACES:
#    (as of 1 Apr 2006, and then 14 Sep. 2007)

# Problems:
# A.  Quoting filenames will not always work.  
#        a.  Under UNIX, quotes are legal in filenames, so when PERL
#            directly runs a binary, a quoted filename will be treated as
#            as a filename containing a quote character.  But when it calls
#            a shell, the quotes are handled by the shell as quotes.
#        b.  Under MSWin32, quotes are illegal filename characters, and tend
#            to be handled correctly.
#        c.  But under cygwin, results are not so clear (there are many 
#            combinations: native v. cygwin perl, native v cygwin programs
#            NT v. unix scripts, which shell is called.
# B.  TeX doesn't always handle filenames with spaces gracefully.
#        a.  UNIX/LINUX: The version on gluon2 Mar 31, 2006 to Sep. 2007) 
#            doesn't handle them at all.  (TeX treats space as separator.)
#        b.  At least some later versions actually do (Brad Miller e-mail, 
#            Sep. 2007).
#        c.  fptex [[e-TeXk, Version 3.141592-2.1 (Web2c 7.5.2)] does, on 
#            my MSWin at home.  In \input the filename must be in quotes.
#        d.  Bibtex [BibTeX (Web2c 7.5.2) 0.99c on my MSWin system at home,
#            Sep. 2007] does not allow names of bibfiles to have spaces.
# C.  =====> Using the shell for command lines is not safe, since special 
#     characters can cause lots of mayhem.
#     It will therefore be a good idea to sanitize filenames. 
#
# I've sanitized all calls out:
#     a. system and exec use a single argument, which forces
#        use of shell, under all circumstances
#        Thus I can safely use quotes on filenames:  They will be handled by 
#        the shell under UNIX, and simply passed on to the program under MSWin32.
#     b. I reorganized Run, Run_Detached to use single command line
#     c. All calls to Run and Run_Detached have quoted filenames.
#     d. So if a space-free filename with wildcards is given on latexmk's
#        command line, and it globs to space-containing filename(s), that
#        works (fptex on home computer, native NT tex)
#     e. ====> But globbing fails: the glob function takes space as filename 
#        separator.   ====================

#================= TO DO ================
#
# 1.  See ??  ESPECIALLY $MSWin_fudge_break
# 2.  Check fudged conditions in looping and make_files 
# 3.  Should not completely abort after a run that ends in failure from latex
#     Missing input files (including via custom dependency) should be checked for
#     a change in status
#         If sources for missing files from custom dependency 
#             are available, then do a rerun
#         If sources of any kind become available rerun (esp. for pvc)
#             rerun
#         Must parse log_file after unsuccessful run of latex: it may give
#             information about missing files. 
# 4.  Check file of bug reports and requests
# 5.  Rationalize bibtex warnings and errors.  Two almost identical routines.
#         Should 1. Use single routine
#                2. Convert errors to failure only in calling routine
#                3. Save first warning/error.


# To do: 
#   Rationalize again handling of include files.
#     Now I use kpsewhich to do searches, if file not found
#        (How do I avoid getting slowed down too much?)
#     Better parsing of log file for includes.
#   Document the assumptions at each stage of processing algorithm.
#   Option to restart previewer automatically, if it dies under -pvc
#   Test for already running previewer gets wrong answer if another
#     process has the viewed file in its command line

$my_name = 'latexmk';
$My_name = 'Latexmk';
$version_num = '3.21j';
$version_details = "$My_name, John Collins, 2 December 2007";


use Config;
use File::Copy;
use File::Basename;
use FileHandle;
use File::Find;
use Cwd;            # To be able to change cwd
use Cwd "chdir";    # Ensure $ENV{PWD}  tracks cwd
use Digest;

#use strict;

# Translation of signal names to numbers and vv:
%signo = ();
@signame = ();
if ( defined $Config{sig_name} ) {
   $i = 0;
   foreach $name (split(' ', $Config{sig_name})) {
      $signo{$name} = $i;
      $signame[$i] = $name;
      $i++;
   }
}
else {
   warn "Something wrong with the perl configuration: No signals?\n";
}

## Copyright John Collins 1998-2007
##           (username collins at node phys.psu.edu)
##      (and thanks to David Coppit (username david at node coppit.org) 
##           for suggestions) 
## Copyright Evan McLean
##         (modifications up to version 2)
## Copyright 1992 by David J. Musliner and The University of Michigan.
##         (original version)
##
##    This program is free software; you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation; either version 2 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with this program; if not, write to the Free Software
##    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307
##
##
##
##   NEW FEATURES, since v. 2.0:
##     1.  Correct algorithm for deciding how many times to run latex:
##         based on whether source file(s) change between runs
##     2.  Continuous preview works, and can be of ps file or dvi file
##     3.  pdf creation by pdflatex possible
##     4.  Defaults for commands are OS dependent.
##     5.  Parsing of log file instead of source file is used to
##         obtain dependencies, by default.
##
##   Modification log for 28 Mar 2007 onwards in detail
##
##      2 Dec 2007, John Collins  Arrange that changes in user file(s)
##                                during error run of (pdf)LaTeX
##                                provoke a rerun.  Changes in
##                                generated files only provoke rerun
##                                when the previous run is error-free.
##     19 Nov 2007, John Collins  3.21j
##     19 Nov 2007, John Collins  Correct comments
##     17 Nov 2007, John Collins  3.21i
##                                sub cus_dep_delete_dest, 
##                                cus_dep_require_primary_run,
##                                and their support in file data.
##      5 Nov 2007, John Collins  Correct some commands
##      5 Nov 2007, John Collins  3.21h
##                                Routines add_cus_dep, remove_cus_dep and 
##                                show_cus_dep
##     15 Oct 2007, John Collins  Correct bibtex-not-run bug
##                                3.21g
##      5 Oct 2007, John Collins  3.21f
##      4 Oct 2007, John Collins  Update make routine to handle error 
##                                  conditions better, without infinite
##                                  loop
##      1 Oct 2007, John Collins  Clean up
##     29 Sep 2007, John Collins  Correct bug in rdb_read and rdb_read_generated
##                                Revise parse_log & friends to enable more
##                                  reliable finding of missing files
##                                Correct $force_mode bug
##                                Improved log-file parsing (identified more
##                                  confusable non-file messages.
##     28 Sep 2007, John Collins  List (array) of patterns for no-file-found
##                                List (hash) of ignored lines in md5 calculation
##                                kpsewhich
##     27 Sep 2007, John Collins  V. 3.21e
##     27 Sep 2007, John Collins  Extra "No files" detection patterns 
##                                 in parse_log
##     26 Sep 2007, John Collins  Clean up message for -e
##     25 Sep 2007, John Collins  V. 3.21d
##     25 Sep 2007, John Collins  V. 3.21c
##                                 -e option
##     24 Sep 2007, John Collins  Correct date.  Clean comments.
##     23 Sep 2007, John Collins  Clean up file detection and use in 
##                                   parse_log  and relatives.
##                                rdb_create_rule ensures the source file is
##                                  in the source list.
##                                $fdb_ver is now 2.  Rule data includes 
##                                  source, dest, and base.
##      22 Sep 2007, John Collins  Correct handling of quoted filenames
##                                   containing spaces in parse_log
##                                 v. 3.21a: Fix comments
##                                 v. 3.21b: Multind support
##      21 Sep 2007, John Collins  Allow .latexmkrc as possible rc filename 
##                                   in current directory.  (Joe Wells patch)
##                                 Substitutions for command-line placeholders 
##                                   are global, to allow multiple
##                                   occurrences of placeholders in
##                                   command line. 
##                                 Hack applied to globbing routine
##                                   Now globbing routine works if a filespec 
##                                      has spaces, but no wildcards, and the 
##                                      file exists.
##                                   Glob routine is used for: 
##                                      MSWin, default_files.
##                                   Wildcarding only works without spaces or 
##                                      at UNIX-like command line, where it's 
##                                      done by shell, not program.
##      14 Sep 2007, John Collins  Do proper quoting of filenames.
##                                 Then filenames with spaces will
##                                 work if underlying external
##                                 programs support them.  
##      12 Sep 2007, John Collins  Bug correction
##      11 Sep 2007, John Collins  Ver. 3.21
##                                 Support for multibib.  
##      10 Sep 2007, John Collins  Set up dummy aux and fdb files
##                                 if no aux file and fdb file exist.
##                        This removes initial superfluous run on simple files
##       9 Sep 2007, John Collins  Keep old routines for now
##         THERE IS NOW A CHOICE makeA routines with make_preview_continuousA
##                           OR  makeB routines with make_preview_continuousB
##       8 Sep 2007, John Collins  Get new algorithm working, except
##                                   for rdb_primary_run.
##                                 Undo repeating of files in current
##                                   directory with and without './', etc.
##                                   Removed './' and '.\\' wherever needed.
##                                 fileparseA
##                                 Removed old subroutines
##       7 Sep 2007, John Collins  Start correction and improvement of
##                                 make algorithm
##      17 Aug 2007, John Collins  Fix setting of $updated
##                                 Viewer wasn't always updated
##      23 Jul 2007, John Collins  Aux files for source of bibtex run were
##                                   only primary aux file.  Correct to all
##                                   aux files.
##       9 Jul 2007, John Collins  Correct warning message
##       3 Jul 2007, John Collins  Miscellaneous clean-ups and corrections
##       2 Jul 2007, John Collins  Correct updating of viewer in pvc mode
##       3 May 2007, John Collins  
##       2 May 2007, John Collins  --dependents switch
##      18 Apr 2007, John Collins  Correct reading of fdb file when
##                                 rule is unknown
##      17 Apr 2007, John Collins  Correct rules to make pdf file
##       9 Apr 2007, John Collins  Clean up some superfluous bibtex and 
##                                 makeindex code (removed make_bbl, 
##                                 make_ind, and check_for_bibtex_errors)
##       6 Apr 2007, John Collins  Fix cus-dep code:
##                                 If source of cus-dep rule doesn't
##                                    exist, remove links
##       2 Apr 2007, John Collins  
##       1 Apr 2007, John Collins  Return codes for rdb_multipass_run
##                                 Substitutable place holders in command
##                                   specifications, with default settings
##                                   for backward compatibility.
##      30 Mar 2007, John Collins  
##      29 Mar 2007, John Collins  Correct cusdep code
##      28 Mar 2007, John Collins  Call this ver. 3.20.  There's a lot new.
##                                 Update cusdep specification
##
##   1998-2007, John Collins.  Many improvements and fixes.
##
##   Modified by Evan McLean (no longer available for support)
##   Original script (RCS version 2.3) called "go" written by David J. Musliner
##
## 2.0 - Final release, no enhancements.  LatexMk is no longer supported
##       by the author.
## 1.9 - Fixed bug that was introduced in 1.8 with path name fix.
##     - Fixed buglet in man page.
## 1.8 - Add not about announcement mailling list above.
##     - Added texput.dvi and texput.aux to files deleted with -c and/or
##       the -C options.
##     - Added landscape mode (-l option and a bunch of RC variables).
##     - Added sensing of "\epsfig{file=...}" forms in dependency generation.
##     - Fixed path names when specified tex file is not in the current
##       directory.
##     - Fixed combined use of -pvc and -s options.
##     - Fixed a bunch of speling errors in the source. :-)
##     - Fixed bugs in xdvi patches in contrib directory.
## 1.7 - Fixed -pvc continuous viewing to reattach to pre-existing
##       process correctly.
##     - Added $pscmd to allow changing process grepping for different
##       systems.
## 1.6 - Fixed buglet in help message
##     - Fixed bugs in detection of input and include files.
## 1.5 - Removed test message I accidentally left in version 1.4
##     - Made dvips use -o option instead of stdout redirection as some
##       people had problems with dvips not going to stdout by default.
##     - Fixed bug in input and include file detection
##     - Fixed dependency resolution process so it detects new .toc file
##       and makeindex files properly.
##     - Added dvi and postscript filtering options -dF and -pF.
##     - Added -v version commmand.
## 1.4 - Fixed bug in -pvc option.
##     - Made "-F" option include non-existant file in the dependency list.
##       (RC variable: $force_include_mode)
##     - Added .lot and .lof files to clean up list of extensions.
##     - Added file "texput.log" to list of files to clean for -c.
##     - LatexMk now handles file names in a similar fashion to latex.
##       The ".tex" extension is no longer enforced.
##     - Added $texfile_search RC variable to look for default files.
##     - Fixed \input and \include so they add ".tex" extension if necessary.
##     - Allow intermixing of file names and options.
##     - Added "-d" and banner options (-bm, -bs, and -bi).
##       (RC variables: $banner, $banner_message, $banner_scale,
##       $banner_intensity, $tmpdir)
##     - Fixed "-r" option to detect an command line syntax errors better.
## 1.3 - Added "-F" option, patch supplied by Patrick van der Smagt.
## 1.2 - Added "-C" option.
##     - Added $clean_ext and $clean_full_ext variables for RC files.
##     - Added custom dependency generation capabilities.
##     - Added command line and variable to specify custom RC file.
##     - Added reading of rc file in current directly.
## 1.1 - Fixed bug where Dependency file generation header is printed
##       rependatively.
##     - Fixed bug where TEXINPUTS path is searched for file that was
##       specified with absolute an pathname.
## 1.0 - Ripped from script by David J. Musliner (RCS version 2.3) called "go"
##     - Fixed a couple of file naming bugs
##        e.g. when calling latex, left the ".tex" extension off the end
##             of the file name which could do some interesting things
##             with some file names.
##     - Redirected output of dvips.  My version of dvips was a filter.
##     - Cleaned up the rc file mumbo jumbo and created a dependency file
##       instead.  Include dependencies are always searched for if a
##       dependency file doesn't exist.  The -i option regenerates the
##       dependency file.
##       Getting rid of the rc file stuff also gave the advantage of
##       not being restricted to one tex file per directory.
##     - Can specify multiple files on the command line or no files
##       on the command line.
##     - Removed lpr options stuff.  I would guess that generally,
##       you always use the same options in which case they can
##       be set up from an rc file with the $lpr variable.
##     - Removed the dviselect stuff.  If I ever get time (or money :-) )
##       I might put it back in if I find myself needing it or people
##       express interest in it.
##     - Made it possible to view dvi or postscript file automatically
##       depending on if -ps option selected.
##     - Made specification of dvi file viewer seperate for -pv and -pvc
##       options.
##-----------------------------------------------------------------------


## Explicit exit codes: 
##             10 = bad command line arguments
##             11 = file specified on command line not found
##                  or other file not found
##             12 = failure in some part of making files
##             13 = error in initialization file
##             20 = probable bug
##             or retcode from called program.


#Line length in log file that indicates wrapping.  
# This number EXCLUDES line-end characters, and is one-based
$log_wrap = 79;

#########################################################################
## Default parsing and file-handling settings

## Array of reg-exps for patterns in log-file for file-not-found
## Each item is the string in a regexp, without the enclosing slashes.
## First parenthesized part is the filename.
## Note the need to quote slashes and single right quotes to make them 
## appear in the regexp.
## Add items by push, e.g.,
##     push @file_not_found, '^No data file found `([^\\\']*)\\\'';
## will give match to line starting "No data file found `filename'"
@file_not_found = (
    '^No file\\s*(.*)\\.$',
    '^\\! LaTeX Error: File `([^\\\']*)\\\' not found\\.',
    '.*?:\\d*: LaTeX Error: File `([^\\\']*)\\\' not found\\.',
    '^LaTeX Warning: File `([^\\\']*)\\\' not found',
    '^Package .* file `([^\\\']*)\\\' not found',
);

## Hash mapping file extension (w/o period, e.g., 'eps') to a single regexp,
#  whose matching by a line in a file with that extension indicates that the 
#  line is to be ignored in the calculation of the hash number (md5 checksum)
#  for the file.  Typically used for ignoring datestamps in testing whether 
#  a file has changed.
#  Add items e.g., by
#     $hash_calc_ignore_pattern{'eps'} = '^%%CreationDate: ';
#  This makes the hash calculation for an eps file ignore lines starting with
#  '%%CreationDate: '
#  ?? Note that a file will be considered changed if 
#       (a) its size changes
#    or (b) its hash changes
#  So it is useful to ignore lines in the hash calculation only if they
#  are of a fixed size (as with a date/time stamp).
%hash_calc_ignore_pattern =();

#########################################################################
## Default document processing programs, and related settings,
## These are mostly the same on all systems.
## Most of these variables represents the external command needed to 
## perform a certain action.  Some represent switches.

## Commands to invoke latex, pdflatex
$latex  = 'latex %O %S';
$pdflatex = 'pdflatex %O %S';
## Switch(es) to make them silent:
$latex_silent_switch  = '-interaction=batchmode';
$pdflatex_silent_switch  = '-interaction=batchmode';

## Command to invoke bibtex
$bibtex  = 'bibtex %O %B';
# Switch(es) to make bibtex silent:
$bibtex_silent_switch  = '-terse';

## Command to invoke makeindex
$makeindex  = 'makeindex %O -o %D %S';
# Switch(es) to make makeinex silent:
$makeindex_silent_switch  = '-q';

## Command to convert dvi file to pdf file directly:
$dvipdf  = 'dvipdf %O %S %D';

## Command to convert dvi file to ps file:
$dvips  = 'dvips %O -o %D %S';
## Command to convert dvi file to ps file in landscape format:
$dvips_landscape = 'dvips -tlandscape %O -o %D %S';
# Switch(es) to get dvips to make ps file suitable for conversion to good pdf:
#    (If this is not used, ps file and hence pdf file contains bitmap fonts
#       (type 3), which look horrible under acroread.  An appropriate switch
#       ensures type 1 fonts are generated.  You can put this switch in the 
#       dvips command if you prefer.)
$dvips_pdf_switch = '-P pdf';
# Switch(es) to make dvips silent:
$dvips_silent_switch  = '-q';

## Command to convert ps file to pdf file:
$ps2pdf = 'ps2pdf  %O %S %D';

## Command to search for tex-related files
$kpsewhich = 'kpsewhich %S';


##Printing:
$print_type = 'ps';     # When printing, print the postscript file.
                        # Possible values: 'dvi', 'ps', 'pdf', 'none'

## Which treatment of default extensions and filenames with
##   multiple extensions is used, for given filename on
##   tex/latex's command line?  See sub find_basename for the
##   possibilities. 
## Current tex's treat extensions like UNIX teTeX:
$extension_treatment = 'unix';

$dvi_update_signal = undef;
$ps_update_signal = undef;
$pdf_update_signal = undef;

$dvi_update_command = undef;
$ps_update_command = undef;
$pdf_update_command = undef;

$new_viewer_always = 0;     # If 1, always open a new viewer in pvc mode.
                            # If 0, only open a new viewer if no previous
                            #     viewer for the same file is detected.

$quote_filenames = 1;       # Quote filenames in external commands

#########################################################################

################################################################
##  Special variables for system-dependent fudges, etc.
$MSWin_fudge_break = 1; # Give special treatment to ctrl/C and ctrl/break
                        #    in -pvc mode under MSWin
                        # Under MSWin32 (at least with perl 5.8 and WinXP)
                        #   when latemk is running another program, and the 
                        #   user gives ctrl/C or ctrl/break, to stop the 
                        #   daughter program, not only does it reach
                        #   the daughter, but also latexmk/perl, so
                        #   latexmk is stopped also.  In -pvc mode,
                        #   this is not normally desired.  So when the
                        #   $MSWin_fudge_break variable is set,
                        #   latexmk arranges to ignore ctrl/C and
                        #   ctrl/break during processing of files;
                        #   only the daughter programs receive them.
                        # This fudge is not applied in other
                        #   situations, since then having latexmk also
                        #   stopping because of the ctrl/C or
                        #   ctrl/break signal is desirable.
                        # The fudge is not needed under UNIX (at least
                        #   with Perl 5.005 on Solaris 8).  Only the
                        #   daughter programs receive the signal.  In
                        #   fact the inverse would be useful: In
                        #   normal processing, as opposed to -pvc, if
                        #   force mode (-f) is set, a ctrl/C is
                        #   received by a daughter program does not
                        #   also stop latexmk.  Under tcsh, we get
                        #   back to a command prompt, while latexmk
                        #   keeps running in the background!


################################################################


# System-dependent overrides:
if ( $^O eq "MSWin32" ) {
# Pure MSWindows configuration
    ## Configuration parameters:

    ## Use first existing case for $tmpdir:
    $tmpdir = $ENV{TMPDIR} || $ENV{TEMP} || '.';

    ## List of possibilities for the system-wide initialization file.  
    ## The first one found (if any) is used.
    @rc_system_files = ( 'C:/latexmk/LatexMk' );

    $search_path_separator = ';';  # Separator of elements in search_path

    # For both fptex and miktex, the following makes error messages explicit:
    $latex_silent_switch  = '-interaction=batchmode -c-style-errors';
    $pdflatex_silent_switch  = '-interaction=batchmode -c-style-errors';

    # For a pdf-file, "start x.pdf" starts the pdf viewer associated with
    #   pdf files, so no program name is needed:
    $pdf_previewer = 'start %O %S';
    $ps_previewer  = 'start %O %S';
    $ps_previewer_landscape  = $ps_previewer;
    $dvi_previewer  = 'start %O %S';
    $dvi_previewer_landscape = "$dvi_previewer";
    # Viewer update methods: 
    #    0 => auto update: viewer watches file (e.g., gv)
    #    1 => manual update: user must do something: e.g., click on window.
    #         (e.g., ghostview, MSWIN previewers, acroread under UNIX)
    #    2 => send signal.  Number of signal in $dvi_update_signal,
    #                         $ps_update_signal, $pdf_update_signal
    #    3 => viewer can't update, because it locks the file and the file 
    #         cannot be updated.  (acroread under MSWIN)
    #    4 => run a command to force the update.  The commands are 
    #         specified by the variables $dvi_update_command, 
    #         $ps_update_command, $pdf_update_command
    $dvi_update_method = 1;
    $ps_update_method = 1;
    $pdf_update_method = 3; # acroread locks the pdf file
    # Use NONE as flag that I am not implementing some commands:
    $lpr =
        'NONE $lpr variable is not configured to allow printing of ps files';
    $lpr_dvi =
        'NONE $lpr_dvi variable is not configured to allow printing of dvi files';
    $lpr_pdf =
        'NONE $lpr_pdf variable is not configured to allow printing of pdf files';
    # The $pscmd below holds a command to list running processes.  It
    # is used to find the process ID of the viewer looking at the
    # current output file.  The output of the command must include the
    # process number and the command line of the processes, since the
    # relevant process is identified by the name of file to be viewed.
    # Its use is not essential.
    $pscmd = 
        'NONE $pscmd variable is not configured to detect running processes';
    $pid_position = -1;     # offset of PID in output of pscmd.  
                            # Negative means I cannot use ps
}
elsif ( $^O eq "cygwin" ) {
    # The problem is a mixed MSWin32 and UNIX environment. 
    # Perl decides the OS is cygwin in two situations:
    # 1. When latexmk is run from a cygwin shell under a cygwin
    #    environment.  Perl behaves in a UNIX way.  This is OK, since
    #    the user is presumably expecting UNIXy behavior.  
    # 2. When CYGWIN exectuables are in the path, but latexmk is run
    #    from a native NT shell.  Presumably the user is expecting NT
    #    behavior. But perl behaves more UNIXy.  This causes some
    #    clashes. 
    # The issues to handle are:
    # 1.  Perl sees both MSWin32 and cygwin filenames.  This is 
    #     normally only an advantage.
    # 2.  Perl uses a UNIX shell in the system command
    #     This is a nasty problem: under native NT, there is a
    #     start command that knows about NT file associations, so that
    #     we can do, e.g., (under native NT) system("start file.pdf");
    #     But this won't work when perl has decided the OS is cygwin,
    #     even if it is invoked from a native NT command line.  An
    #     NT command processor must be used to deal with this.
    # 3.  External executables can be native NT (which only know
    #     NT-style file names) or cygwin executables (which normally
    #     know both cygwin UNIX-style file names and NT file names,
    #     but not always; some do not know about drive names, for
    #     example).
    #     Cygwin executables for tex and latex may only know cygwin
    #     filenames. 
    # 4.  The BIBINPUTS and TEXINPUTS environment variables may be
    #     UNIX-style or MSWin-style depending on whether native NT or
    #     cygwin executables are used.  They are therefore parsed
    #     differently.  Here is the clash:
    #        a. If a user is running under an NT shell, is using a
    #           native NT installation of tex (e.g., fptex or miktex),
    #           but has the cygwin executables in the path, then perl
    #           detects the OS as cygwin, but the user needs NT
    #           behavior from latexmk.
    #        b. If a user is running under an UNIX shell in a cygwin
    #           environment, and is using the cygwin installation of
    #           tex, then perl detects the OS as cygwin, and the user
    #           needs UNIX behavior from latexmk.
    #     Latexmk has no way of detecting the difference.  The two
    #     situations may even arise for the same user on the same
    #     computer simply by changing the order of directories in the
    #     path environment variable


    ## Configuration parameters: We'll assume native NT executables.
    ## The user should override if they are not.

    # This may fail: perl converts MSWin temp directory name to cygwin
    # format. Names containing this string cannot be handled by native
    # NT executables.
    $tmpdir = $ENV{TMPDIR} || $ENV{TEMP} || '.';

    ## List of possibilities for the system-wide initialization file.  
    ## The first one found (if any) is used.
    ## We can stay with MSWin files here, since perl understands them,
    @rc_system_files = ( 'C:/latexmk/LatexMk' );

    $search_path_separator = ';';  # Separator of elements in search_path
    # This is tricky.  The search_path_separator depends on the kind
    # of executable: native NT v. cygwin.  
    # So the user will have to override this.

    # For both fptex and miktex, the following makes error messages explicit:
    $latex_silent_switch  = '-interaction=batchmode -c-style-errors';
    $pdflatex_silent_switch  = '-interaction=batchmode -c-style-errors';

    # We will assume that files can be viewed by native NT programs.
    #  Then we must fix the start command/directive, so that the
    #  NT-native start command of a cmd.exe is used.
    # For a pdf-file, "start x.pdf" starts the pdf viewer associated with
    #   pdf files, so no program name is needed:
    $start_NT = "cmd /c start";
    $pdf_previewer = "$start_NT %O %S";
    $ps_previewer  = "$start_NT %O %S";
    $ps_previewer_landscape  = $ps_previewer;
    $dvi_previewer  = "$start_NT %O %S";
    $dvi_previewer_landscape = $dvi_previewer;
    # Viewer update methods: 
    #    0 => auto update: viewer watches file (e.g., gv)
    #    1 => manual update: user must do something: e.g., click on window.
    #         (e.g., ghostview, MSWIN previewers, acroread under UNIX)
    #    2 => send signal.  Number of signal in $dvi_update_signal,
    #                         $ps_update_signal, $pdf_update_signal
    #    3 => viewer can't update, because it locks the file and the file 
    #         cannot be updated.  (acroread under MSWIN)
    $dvi_update_method = 1;
    $ps_update_method = 1;
    $pdf_update_method = 3; # acroread locks the pdf file
    # Use NONE as flag that I am not implementing some commands:
    $lpr =
        'NONE $lpr variable is not configured to allow printing of ps files';
    $lpr_dvi =
        'NONE $lpr_dvi variable is not configured to allow printing of dvi files';
    $lpr_pdf =
        'NONE $lpr_pdf variable is not configured to allow printing of pdf files';
    # The $pscmd below holds a command to list running processes.  It
    # is used to find the process ID of the viewer looking at the
    # current output file.  The output of the command must include the
    # process number and the command line of the processes, since the
    # relevant process is identified by the name of file to be viewed.
    # Its use is not essential.
    # When the OS is detected as cygwin, there are two possibilities:
    #    a.  Latexmk was run from an NT prompt, but cygwin is in the
    #        path. Then the cygwin ps command will not see commands
    #        started from latexmk.  So we cannot use it.
    #    b.  Latexmk was started within a cygwin environment.  Then
    #        the ps command works as we need.
    # Only the user, not latemk knows which, so we default to not
    # using the ps command.  The user can override this in a
    # configuration file. 
    $pscmd = 
        'NONE $pscmd variable is not configured to detect running processes';
    $pid_position = -1;     # offset of PID in output of pscmd.  
                            # Negative means I cannot use ps
}
else {
    # Assume anything else is UNIX or clone

    ## Configuration parameters:


    ## Use first existing case for $tmpdir:
    $tmpdir = $ENV{TMPDIR} || '/tmp';

    ## List of possibilities for the system-wide initialization file.  
    ## The first one found (if any) is used.
    ## Normally on a UNIX it will be in a subdirectory of /opt/local/share or
    ## /usr/local/share, depending on the local conventions.
    ## /usr/local/lib/latexmk/LatexMk is put in the list for
    ## compatibility with older versions of latexmk.
    @rc_system_files = 
     ( '/opt/local/share/latexmk/LatexMk', 
       '/usr/local/share/latexmk/LatexMk',
       '/usr/local/lib/latexmk/LatexMk' );

    $search_path_separator = ':';  # Separator of elements in search_path

    $dvi_update_signal = $signo{USR1} 
         if ( defined $signo{USR1} ); # Suitable for xdvi
    $ps_update_signal = $signo{HUP} 
         if ( defined $signo{HUP} );  # Suitable for gv
    $pdf_update_signal = $signo{HUP} 
         if ( defined $signo{HUP} );  # Suitable for gv
    ## default document processing programs.
    # Viewer update methods: 
    #    0 => auto update: viewer watches file (e.g., gv)
    #    1 => manual update: user must do something: e.g., click on window.
    #         (e.g., ghostview, MSWIN previewers, acroread under UNIX)
    #    2 => send signal.  Number of signal in $dvi_update_signal,
    #                         $ps_update_signal, $pdf_update_signal
    #    3 => viewer can't update, because it locks the file and the file 
    #         cannot be updated.  (acroread under MSWIN)
    #    4 => Run command to update.  Command in $dvi_update_command, 
    #    $ps_update_command, $pdf_update_command.
    $dvi_previewer  = 'start xdvi %O %S';
    $dvi_previewer_landscape = 'start xdvi -paper usr %O %S';
    if ( defined $dvi_update_signal ) { 
        $dvi_update_method = 2;  # xdvi responds to signal to update
    } else {
        $dvi_update_method = 1;  
    }
#    if ( defined $ps_update_signal ) { 
#        $ps_update_method = 2;  # gv responds to signal to update
#        $ps_previewer  = 'start gv -nowatch';
#        $ps_previewer_landscape  = 'start gv -swap -nowatch';
#    } else {
#        $ps_update_method = 0;  # gv -watch watches the ps file
#        $ps_previewer  = 'start gv -watch';
#        $ps_previewer_landscape  = 'start gv -swap -watch';
#    }
    # Turn off the fancy options for gv.  Regular gv likes -watch etc
    #   GNU gv likes --watch etc.  User must configure
    $ps_update_method = 0;  # gv -watch watches the ps file
    $ps_previewer  = 'start gv %O %S';
    $ps_previewer_landscape  = 'start gv -swap %O %S';
    $pdf_previewer = 'start acroread %O %S';
    $pdf_update_method = 1;  # acroread under unix needs manual update
    $lpr = 'lpr %O %S';         # Assume lpr command prints postscript files correctly
    $lpr_dvi =
        'NONE $lpr_dvi variable is not configured to allow printing of dvi files';
    $lpr_pdf =
        'NONE $lpr_pdf variable is not configured to allow printing of pdf files';
    # The $pscmd below holds a command to list running processes.  It
    # is used to find the process ID of the viewer looking at the
    # current output file.  The output of the command must include the
    # process number and the command line of the processes, since the
    # relevant process is identified by the name of file to be viewed.
    # Uses:
    #   1.  In preview_continuous mode, to save running a previewer
    #       when one is already running on the relevant file.
    #   2.  With xdvi in preview_continuous mode, xdvi must be
    #       signalled to make it read a new dvi file.
    #
    # The following works on Solaris, LINUX, HP-UX, IRIX
    # Use -f to get full listing, including command line arguments.
    # Use -u $ENV{CMD} to get all processes started by current user (not just
    #   those associated with current terminal), but none of other users' 
    #   processes. 
    $pscmd = "ps -f -u $ENV{USER}"; 
    $pid_position = 1; # offset of PID in output of pscmd; first item is 0.  
    if ( $^O eq "linux" ) {
        # Ps on Redhat (at least v. 7.2) appears to truncate its output
        #    at 80 cols, so that a long command string is truncated.
        # Fix this with the --width option.  This option works under 
        #    other versions of linux even if not necessary (at least 
        #    for SUSE 7.2). 
        # However the option is not available under other UNIX-type 
        #    systems, e.g., Solaris 8.
        $pscmd = "ps --width 200 -f -u $ENV{USER}"; 
    }
    elsif ( $^O eq "darwin" ) {
        # OS-X on Macintosh
        $lpr_pdf  = 'lpr %O %S';  
        $pscmd = "ps -ww -u $ENV{USER}"; 
    }
}

## default parameters
$max_repeat = 5;        # Maximum times I repeat latex.  Normally
                        # 3 would be sufficient: 1st run generates aux file,
                        # 2nd run picks up aux file, and maybe toc, lof which 
                        # contain out-of-date information, e.g., wrong page
                        # references in toc, lof and index, and unresolved
                        # references in the middle of lines.  But the 
                        # formatting is more-or-less correct.  On the 3rd
                        # run, the page refs etc in toc, lof, etc are about
                        # correct, but some slight formatting changes may
                        # occur, which mess up page numbers in the toc and lof,
                        # Hence a 4th run is conceivably necessary. 
                        # At least one document class (JHEP.cls) works
			# in such a way that a 4th run is needed.  
                        # We allow an extra run for safety for a
			# maximum of 5. Needing further runs is
			# usually an indication of a problem; further
			# runs may not resolve the problem, and
			# instead could cause an infinite loop.
$clean_ext = "";        # space separated extensions of files that are
                        # to be deleted when doing cleanup, beyond
                        # standard set
$clean_full_ext = "";   # space separated extensions of files that are
                        # to be deleted when doing cleanup_full, beyond
                        # standard set and those in $clean_ext
@cus_dep_list = ();     # Custom dependency list
@default_files = ( '*.tex' );   # Array of LaTeX files to process when 
                        # no files are specified on the command line.
                        # Wildcards allowed
                        # Best used for project specific files.
@default_excluded_files = ( );   
                        # Array of LaTeX files to exclude when using
                        # @default_files, i.e., when no files are specified
                        # on the command line.
                        # Wildcards allowed
                        # Best used for project specific files.
$texfile_search = "";   # Specification for extra files to search for
                        # when no files are specified on the command line
                        # and the @default_files variable is empty.
                        # Space separated, and wildcards allowed.
                        # These files are IN ADDITION to *.tex in current 
                        # directory. 
                        # This variable is obsolete, and only in here for
                        # backward compatibility.

$fdb_ext = 'fdb_latexmk'; # Extension for the file for latexmk's
			  # file-database
                          # Make it long to avoid possible collisions.
$fdb_ver = 2;             # Version number for kind of fdb_file.


## default flag settings.
$silent = 0;            # silence latex's messages?
$landscape_mode = 0;	# default to portrait mode

# The following two arrays contain lists of extensions (without
# period) for files that are read in during a (pdf)LaTeX run but that
# are generated automatically from the previous run, as opposed to
# being user generated files (directly or indirectly from a custom
# dependency).  These files get two kinds of special treatment:
#     1.  In clean up, where depending on the kind of clean up, some
#         or all of these generated files are deleted.
#         (Note that special treatment is given to aux files.)
#     2.  In analyzing the results of a run of (pdf)LaTeX, to
#         determine if another run is needed.  With an error free run,
#         a rerun should be provoked by a change in any source file,
#         whether a user file or a generated file.  But with a run
#         that ends in an error, only a change in a user file during
#         the run (which might correct the error) should provoke a
#         rerun, but a change in a generated file should not.
# These arrays can be user-configured.
@generated_exts = ( 'aux', 'bbl', 'idx', 'ind', 'lof', 'lot', 'out', 'toc' );
     # N.B. 'out' is generated by hyperref package

# Which kinds of file do I have requests to make?
# If no requests at all are made, then I will make dvi file
# If particular requests are made then other files may also have to be
# made.  E.g., ps file requires a dvi file
$dvi_mode = 0;          # No dvi file requested
$postscript_mode = 0;           # No postscript file requested
$pdf_mode = 0;          # No pdf file requested to be made by pdflatex
                        # Possible values: 
                        #     0 don't create pdf file
                        #     1 to create pdf file by pdflatex
                        #     2 to create pdf file by ps2pdf
                        #     3 to create pdf file by dvipdf
$view = 'default';      # Default preview is of highest of dvi, ps, pdf
$sleep_time = 2;	# time to sleep b/w checks for file changes in -pvc mode
$banner = 0;            # Non-zero if we have a banner to insert
$banner_scale = 220;    # Original default scale
$banner_intensity = 0.95;  # Darkness of the banner message
$banner_message = 'DRAFT'; # Original default message
$do_cd = 0;     # Do not do cd to directory of source file.
                #   Thus behave like latex.
$dependents_list = 0;   # Whether to display list(s) of dependencies
@dir_stack = (); # Stack of pushed directories.
$cleanup_mode = 0;      # No cleanup of nonessential LaTex-related files.
                        # $cleanup_mode = 0: no cleanup
                        # $cleanup_mode = 1: full cleanup 
                        # $cleanup_mode = 2: cleanup except for dvi,
                        #                    dviF, pdf, ps, & psF 
$cleanup_fdb  = 0;      # No removal of file for latexmk's file-database
$cleanup_only = 0;      # When doing cleanup, do not go-on to making files
$diagnostics = 0;
$dvi_filter = '';	# DVI filter command
$ps_filter = '';	# Postscript filter command

$force_mode = 0;        # =1 to force processing past errors
$force_include_mode = 0;# =1 to ignore non-existent files when testing
                        # for dependency.  (I.e., don't treat them as error)
$go_mode = 0;           # =1 to force processing regardless of time-stamps
                        # =2 full clean-up first
$preview_mode = 0;
$preview_continuous_mode  = 0;
$printout_mode = 0;     # Don't print the file

# Do we make view file in temporary then move to final destination?
#  (To avoid premature updating by viewer).
$always_view_file_via_temporary = 0;      # Set to 1 if  viewed file is always
                                   #    made through a temporary.
$pvc_view_file_via_temporary = 1;  # Set to 1 if only in -pvc mode is viewed 
                                   #    file made through a temporary.

# State variables initialized here:

$updated = 0;           # Flags when something has been remade
                        # Used to allow convenient user message in -pvc mode
$waiting = 0;           # Flags whether we are in loop waiting for an event
                        # Used to avoid unnecessary repeated o/p in wait loop

# Used for some results of parsing log file:
$reference_changed = 0;
$bad_reference = 0;
$bad_citation = 0;


# Set search paths for includes.
# Set them early so that they can be overridden
$BIBINPUTS = $ENV{'BIBINPUTS'};
if (!$BIBINPUTS) { $BIBINPUTS = '.'; }
#?? OBSOLETE
$TEXINPUTS = $ENV{'TEXINPUTS'};
if (!$TEXINPUTS) { $TEXINPUTS = '.'; }

# Convert search paths to arrays:
# If any of the paths end in '//' then recursively search the
# directory.  After these operations, @BIBINPUTS  should
# have all the directories that need to be searched

@BIBINPUTS = find_dirs1 ($BIBINPUTS);


######################################################################
######################################################################
#
#  ???  UPDATE THE FOLLOWING!!
#
# We will need to determine whether source files for runs of various
# programs are out of date.  In a normal situation, this is done by
# asking whether the times of the source files are later than the
# destination files.  But this won't work for us, since a common
# situation is that a file is written on one run of latex, for
# example, and read back in on the next run (e.g., an .aux file).
# Some situations of this kind are standard in latex generally; others
# occur with particular macro packages or with particular
# postprocessors. 
#
# The correct criterion for whether a source is out-of-date is
# therefore NOT that its modification time is later than the
# destination file, but whether the contents of the source file have
# changed since the last successful run.  This also handles the case
# that the user undoes some changes to a source file by replacing the
# source file by reverting to an earlier version, which may well have
# an older time stamp.  Since a direct comparison of old and new files
# would involve storage and access of a large number of backup files,
# we instead use the md5 signature of the files.  (Previous versions
# of latexmk used the backup file method, but restricted to the case
# of .aux and .idx files, sufficient for most, but not all,
# situations.)
#
# We will have a database of (time, size, md5) for the relevant
# files. If the time and size of a file haven't changed, then the file
# is assumed not to have changed; this saves us from having to
# determine its md5 signature, which would involve reading the whole 
# file, which is naturally time-consuming, especially if network file
# access to a server is needed, and many files are involved, when most
# of them don't change.  It is of course possible to change a file
# without changing its size, but then to adjust its timestamp 
# to what it was previously; this requires a certain amount of
# perversity.  We can safely assume that if the user edits a file or
# changes its contents, then the file's timestamp changes.  The
# interesting case is that the timestamp does change, because the file
# has actually been written to, but that the contents do not change;
# it is for this that we use the md5 signature.  However, since
# computing the md5 signature involves reading the whole file, which
# may be large, we should avoid computing it more than necessary. 
#
# So we get the following structure:
#
#     1.  For each relevant run (latex, pdflatex, each instance of a
#         custom dependency) we have a database of the state of the
#         source files that were last used by the run.
#     2.  On an initial startup, the database for a primary tex file
#         is read that was created by a previous run of latex or
#         pdflatex, if this exists.  
#     3.  If the file doesn't exist, then the criterion for
#         out-of-dateness for an initial run is that it goes by file
#         timestamps, as in previous versions of latexmk, with due
#         (dis)regard to those files that are known to be generated by
#         latex and re-read on the next run.
#     4.  Immediately before a run, the database is updated to
#         represent the current conditions of the run's source files.
#     5.  After the run, it is determined whether any of the source
#         files have changed.  This covers both files written by the
#         run, which are therefore in a dependency loop, and files that
#         the user may have updated during the run.  (The last often
#         happens when latex takes a long time, for a big document,
#         and the user makes edits before latex has finished.  This is
#         particularly prevalent when latexmk is used with
#         preview-continuous mode.)
#     6.  In the case of latex or pdflatex, the custom dependencies
#         must also be checked and redone if out-of-date.
#     7.  If any source files have changed, the run is redone,
#         starting at step 1.
#     8.  There is naturally a limit on the number of reruns, to avoid
#         infinite loops from bugs and from pathological or unforeseen
#         conditions. 
#     9.  After the run is done, the run's file database is updated.
#         (By hypothesis, the sizes and md5s are correct, if the run
#         is successful.)
#    10.  To allow reuse of data from previous runs, the file database
#         is written to a file after every complete set of passes
#         through latex or pdflatex.  (Note that there is separate
#         information for latex and pdflatex; the necessary
#         information won't coincide: Out-of-dateness for the files
#         for each program concerns the properties of the files when
#         the other program was run, and the set of source files could
#         be different, e.g., for graphics files.)  
#
# We therefore maintain the following data structures.:
#
#     a.  For each run (latex, pdflatex, each custom dependency) a
#         database is maintained.  This is a hash from filenames to a
#         reference to an array:  [time, size, md5].  The semantics of
#         the database is that it represents the state of the source
#         files used in the run.  During a run it represents the state
#         immediately before the run; after a run, with all reruns, it
#         represents the state of the files used, modified by having
#         the latest timestamps for generated files.
#     b.  There is a global database for all files, which represents
#         the current state.  This saves having to recompute the md5
#         signatures of a changed file used in more than one run
#         (e.g., latex and pdflatex).
#     c.  Each of latex and pdflatex has a list of the relevant custom
#         dependencies. 
#
# In all the following a fdb-hash is a hash of the form:
#                      filename -> [time, size, md5] 
# If a file is found to disappear, its entry is removed from the hash.
# In returns from fdb access routines, a size entry of -1 indicates a
# non-existent file.


# List of known rules.  Rule types: primary, 
#     external (calls program), internal (calls routine), cusdep.

%known_rules = ( 'latex'  => 'primary',  'pdflatex'  => 'primary', 
              );
%primaries = ();    # Hash of rules for primary part of make.  Keys are 
                    # currently 'latex', 'pdflatex' or both.  Value is
                    # currently irrelevant.  Use hash for ease of lookup
   # Make remove this later, if use makeB

# Hashes, whose keys give names of particular kinds of rule.  We use
# hashes for ease of lookup.
%possible_one_time = ( 'view' => 1, 'print' => 1 );
%requested_filerules = ();  # Hash for rules corresponding to requested files.  
                    # The keys are the rulenames and the value is 
                    # currently irrelevant.
%one_time = ();     # Hash for requested one-time-only rules, currently
                    # possible values 'print' and 'view'.  Potentially
                    # 'update_view' in future.


%rule_db = ();      # Database of all rules:
                    # Hash: rulename -> [array of rule data]
                    # Rule data:
                    #   0: [ cmd_type, ext_cmd, int_cmd, out_of_date-crit, 
                    #       source, dest, base, out_of_date,
		    #       out_of_date_user, time_of_last_run ]
                    # where 
                    #     cmd_type is 'primary', 'external' or 'cusdep',
                    #     ext_cmd is string for associated external command
                    #       with substitutions (%D for destination, %S
		    #       for source, %B for base of current rule,
		    #       %R for base of primary tex file, %T for
		    #       texfile name, and %O for options.
                    #     int_cmd specifies any internal command to be
		    #       used to implement the application of the
		    #       rule.  If this is present, it overrides
		    #       the external command, and it is the
		    #       responsibility of the perl subroutine
		    #       specified in intcmd to execute the
		    #       external command if this is appropriate.
		    #       This variable intcmd is a reference to an array,  
                    #       $$intcmd[0] = internal routine
                    #       $$intcmd[1...] = its arguments (if any)
                    #     out_of_date_crit specifies method of determining
                    #       whether a file is out-of-date:
                    #         0 for never
                    #         1 for usual: whether there is a source
		    #              file change 
                    #         2 for dest earlier than source
                    #         3 for method 2 at first run, 1 thereafter
                    #              (used when don't have file data from
		    #              previous run).
                    #     source = name of primary source file, if any
                    #     dest   = name of primary destination file,
		    #              if any
                    #     base   = base name, if any, of files for
		    #              this rule
                    #     out_of_date = 1 if it has been detected that
		    #                     this rule needs to be run
		    #                     (typically because a source
		    #                     file has changed).
                    #                   0 otherwise
                    #     out_of_date_user is like out_of_date, except
                    #         that the detection of out-of-dateness
                    #         has been made from a change of a
		    #         putative user file, i.e., one that is
		    #         not a generated file (e.g., aux). This
		    #         kind of out-of-dateness should provoke a
		    #         rerun where or not there was an error
		    #         during a run of (pdf)LaTeX.  Normally,
		    #         if there is an error, one should wait
		    #         for the user to correct the error.  But
		    #         it is possible the error condition is
		    #         already corrected during the run, e.g.,
		    #         by the user changing a source file in
		    #         response to an error message. 
                    #     time_of_last_run = time that this rule was
		    #              last applied.  (In standard units
		    #              from perl, to be directly compared
		    #              with file modification times.)
                    #     changed flags whether special changes have been made
                    #          that require file-existence status to be ignored
                    #   1: {Hash sourcefile -> [source-file data] }
                    # Source-file data array: 
                    #   0: time
                    #   1: size
                    #   2: md5
                    #   3: name of rule to make this file
                    #   4: whether the file is of the kind made by epstopdf.sty 
                    #      during a primary run.  It will have been read during
                    #      the run, so that even though the file changes during
                    #      a primary run, there is no need to trigger another 
                    #      run because of this.

%fdb_current = ();  # Fdb-hash for all files used.


#==================================================
## Read rc files:

sub read_first_rc_file_in_list {
    foreach my $rc_file ( @_ ) {
        #print "===Testing for rc file \"$rc_file\" ...\n";
        if ( -e $rc_file ) {
            #print "===Reading rc file \"$rc_file\" ...\n";
            process_rc_file( $rc_file );
            return;
        }
    }
}

# Read system rc file:
read_first_rc_file_in_list( @rc_system_files );
# Read user rc file.
read_first_rc_file_in_list( "$ENV{'HOME'}/.latexmkrc" );
# Read rc file in current directory.
read_first_rc_file_in_list( "latexmkrc", ".latexmkrc" );

#==================================================

#show_array ("BIBINPUTS", @BIBINPUTS); die;

## Process command line args.
@command_line_file_list = ();
$bad_options = 0;

#print "Command line arguments:\n"; for ($i = 0; $i <= $#ARGV; $i++ ) {  print "$i: '$ARGV[$i]'\n"; }

while ($_ = $ARGV[0])
{
  # Make -- and - equivalent at beginning of option:
  s/^--/-/;
  shift;
  if (/^-c$/)        { $cleanup_mode = 2; $cleanup_only = 1; }
  elsif (/^-C$/)     { $cleanup_mode = 1; $cleanup_only = 1; }
  elsif (/^-CA$/)    { $cleanup_mode = 1; $cleanup_fdb = 1; $cleanup_only = 1;}
  elsif (/^-CF$/)    { $cleanup_fdb = 1; }
  elsif (/^-cd$/)    { $do_cd = 1; }
  elsif (/^-cd-$/)   { $do_cd = 0; }
  elsif (/^-commands$/) { &print_commands; exit; }
  elsif (/^-d$/)     { $banner = 1; }
  elsif (/^-dependents$/) { $dependents_list = 1; }
  elsif (/^-nodependents$/ || /^-dependents-$/) { $dependents_list = 0; }
  elsif (/^-dvi$/)   { $dvi_mode = 1; }
  elsif (/^-dvi-$/)  { $dvi_mode = 0; }
  elsif (/^-F$/)     { $force_include_mode = 1; }
  elsif (/^-F-$/)    { $force_include_mode = 0; }
  elsif (/^-f$/)     { $force_mode = 1; }
  elsif (/^-f-$/)    { $force_mode = 0; }
  elsif (/^-g$/)     { $go_mode = 1; }
  elsif (/^-g-$/)    { $go_mode = 0; }
  elsif (/^-gg$/)    { 
     $go_mode = 2; $cleanup_mode = 1; $cleanup_fdb = 1; $cleanup_only = 0; 
  }
  elsif ( /^-h$/ || /^-help$/ )   { &print_help; exit;}
  elsif (/^-diagnostics/) { $diagnostics = 1; }
  elsif (/^-l$/)     { $landscape_mode = 1; }
  elsif (/^-new-viewer$/) {
                       $new_viewer_always = 1; 
  }
  elsif (/^-new-viewer-$/) {
                       $new_viewer_always = 0; 
  }
  elsif (/^-l-$/)    { $landscape_mode = 0; }
  elsif (/^-p$/)     { $printout_mode = 1; 
                       $preview_continuous_mode = 0; # to avoid conflicts
                       $preview_mode = 0;  
                     }
  elsif (/^-p-$/)    { $printout_mode = 0; }
  elsif (/^-pdfdvi$/){ $pdf_mode = 3; }
  elsif (/^-pdfps$/) { $pdf_mode = 2; }
  elsif (/^-pdf$/)   { $pdf_mode = 1; }
  elsif (/^-pdf-$/)  { $pdf_mode = 0; }
  elsif (/^-print=(.*)$/) {
      $value = $1;
      if ( $value =~ /^dvi$|^ps$|^pdf$/ ) {
          $print_type = $value;
          $printout_mode = 1;
      }
      else {
          &exit_help("$My_name: unknown print type '$value' in option '$_'");
      }
  }
  elsif (/^-ps$/)    { $postscript_mode = 1; }
  elsif (/^-ps-$/)   { $postscript_mode = 0; }
  elsif (/^-pv$/)    { $preview_mode = 1; 
                       $preview_continuous_mode = 0; # to avoid conflicts
                       $printout_mode = 0; 
                     }
  elsif (/^-pv-$/)   { $preview_mode = 0; }
  elsif (/^-pvc$/)   { $preview_continuous_mode = 1;
                       $force_mode = 0;    # So that errors do not cause loops
                       $preview_mode = 0;  # to avoid conflicts
                       $printout_mode = 0; 
                     }
  elsif (/^-pvc-$/)  { $preview_continuous_mode = 0; }
  elsif (/^-silent$/ || /^-quiet$/ ){ $silent = 1; }
  elsif (/^-v$/ || /^-version$/)   { 
      print "\n$version_details. Version $version_num\n"; 
      exit; 
  }
  elsif (/^-verbose$/)  { $silent = 0; }
  elsif (/^-view=default$/) { $view = "default";}
  elsif (/^-view=dvi$/)     { $view = "dvi";}
  elsif (/^-view=none$/)    { $view = "none";}
  elsif (/^-view=ps$/)      { $view = "ps";}
  elsif (/^-view=pdf$/)     { $view = "pdf"; }
  elsif (/^-e$/) {  
     if ( $ARGV[0] eq '' ) {
        &exit_help( "No code to execute specified after -e switch"); 
     }
     else {
         execute_code_string( $ARGV[0] );
     } 
     shift;
  }
  elsif (/^-r$/) {  
     if ( $ARGV[0] eq '' ) {
        &exit_help( "No RC file specified after -r switch"); 
     }
     if ( -e $ARGV[0] ) {
	process_rc_file( $ARGV[0] );
     } 
     else {
	$! = 11;
	die "$My_name: RC file [$ARGV[0]] does not exist\n"; 
     }
     shift; 
  }
  elsif (/^-bm$/) {
     if ( $ARGV[0] eq '' ) {
	&exit_help( "No message specified after -bm switch");
     }
     $banner = 1; $banner_message = $ARGV[0];
     shift; 
  }
  elsif (/^-bi$/) {
     if ( $ARGV[0] eq '' ) {
	&exit_help( "No intensity specified after -bi switch");
     }
     $banner_intensity = $ARGV[0];
     shift; 
  }
  elsif (/^-bs$/) {
     if ( $ARGV[0] eq '' ) {
	&exit_help( "No scale specified after -bs switch");
     }
     $banner_scale = $ARGV[0];
     shift; 
  }
  elsif (/^-dF$/) {
     if ( $ARGV[0] eq '' ) {
	&exit_help( "No dvi filter specified after -dF switch");
     }
     $dvi_filter = $ARGV[0];
     shift; 
  }
  elsif (/^-pF$/) {
     if ( $ARGV[0] eq '' ) {
        &exit_help( "No ps filter specified after -pF switch");
     }
     $ps_filter = $ARGV[0];
     shift; 
  }
  elsif (/^-/) {
     warn "$My_name: $_ bad option\n"; 
     $bad_options++;
  }
  else {
     push @command_line_file_list, $_ ; 
  }
}

if ( $bad_options > 0 ) {
    &exit_help( "Bad options specified" );
}

warn "$My_name: This is $version_details, version: $version_num.\n",
     "**** Report bugs etc to John Collins <collins at phys.psu.edu>. ****\n"
   unless $silent;

# For backward compatibility, convert $texfile_search to @default_files
# Since $texfile_search is initialized to "", a nonzero value indicates
# that an initialization file has set it.
if ( $texfile_search ne "" ) {
    @default_files = split / /, "*.tex $texfile_search";
}

#printA "A: Command line file list:\n";
#for ($i = 0; $i <= $#command_line_file_list; $i++ ) {  print "$i: '$command_line_file_list[$i]'\n"; }

#Glob the filenames command line if the script was not invoked under a 
#   UNIX-like environment.
#   Cases: (1) MS/MSwin native    Glob
#                      (OS detected as MSWin32)
#          (2) MS/MSwin cygwin    Glob [because we do not know whether
#                  the cmd interpreter is UNIXy (and does glob) or is
#                  native MS-Win (and does not glob).]
#                      (OS detected as cygwin)
#          (3) UNIX               Don't glob (cmd interpreter does it)
#                      (Currently, I assume this is everything else)
if ( ($^O eq "MSWin32") || ($^O eq "cygwin") ) {
    # Preserve ordering of files
    @file_list = glob_list1(@command_line_file_list);
#print "A1:File list:\n";
#for ($i = 0; $i <= $#file_list; $i++ ) {  print "$i: '$file_list[$i]'\n"; }
}
else {
    @file_list = @command_line_file_list;
#print "A2:File list:\n";
#for ($i = 0; $i <= $#file_list; $i++ ) {  print "$i: '$file_list[$i]'\n"; }
}
@file_list = uniq1( @file_list );


# Check we haven't selected mutually exclusive modes.
# Note that -c overides all other options, but doesn't cause
# an error if they are selected.
if (($printout_mode && ( $preview_mode || $preview_continuous_mode ))
    || ( $preview_mode && $preview_continuous_mode ))
{
  # Each of the options -p, -pv, -pvc turns the other off.
  # So the only reason to arrive here is an incorrect inititalization
  #   file, or a bug.
  &exit_help( "Conflicting options (print, preview, preview_continuous) selected");
}

if ( @command_line_file_list ) {   
    # At least one file specified on command line (before possible globbing).
    if ( !@file_list ) {
        &exit_help( "Wildcards in file names didn't match any files");
    }
}
else {
    # No files specified on command line, try and find some
    # Evaluate in order specified.  The user may have some special
    #   for wanting processing in a particular order, especially
    #   if there are no wild cards.
    # Preserve ordering of files
    my @file_list1 = uniq1( glob_list1(@default_files) );
    my @excluded_file_list = uniq1( glob_list1(@default_excluded_files) );
    # Make hash of excluded files, for easy checking:
    my %excl = ();
    foreach my $file (@excluded_file_list) {
	$excl{$file} = '';
    }
    foreach my $file (@file_list1) {
	push( @file_list, $file)  unless ( exists $excl{$file} );
    }    
    if ( !@file_list ) {
	&exit_help( "No file name specified, and I couldn't find any");
    }
}

$num_files = $#file_list + 1;
$num_specified = $#command_line_file_list + 1;

#print "Command line file list:\n";
#for ($i = 0; $i <= $#command_line_file_list; $i++ ) {  print "$i: '$command_line_file_list[$i]'\n"; }
#print "File list:\n";
#for ($i = 0; $i <= $#file_list; $i++ ) {  print "$i: '$file_list[$i]'\n"; }


# If selected a preview-continuous mode, make sure exactly one filename was specified
if ($preview_continuous_mode && ($num_files != 1) ) {
    if ($num_specified > 1) {
        &exit_help( 
          "Need to specify exactly one filename for ".
              "preview-continuous mode\n".
          "    but $num_specified were specified"
        );
    }
    elsif ($num_specified == 1) {
        &exit_help( 
          "Need to specify exactly one filename for ".
              "preview-continuous mode\n".
          "    but wildcarding produced $num_files files"
        );
    }
    else {
        &exit_help( 
          "Need to specify exactly one filename for ".
              "preview-continuous mode.\n".
          "    Since none were specified on the command line, I looked for \n".
          "    files in '@default_files'.\n".
          "    But I found $num_files files, not 1."
        );
    }
}

# Normalize the commands, to have place-holders for source, dest etc:
&fix_cmds;

# If landscape mode, change dvips processor, and the previewers:
if ( $landscape_mode )
{
  $dvips = $dvips_landscape;
  $dvi_previewer = $dvi_previewer_landscape;
  $ps_previewer = $ps_previewer_landscape;
}

if ( $silent ) { 
    add_option( \$latex, " $latex_silent_switch" ); 
    add_option( \$pdflatex, " $pdflatex_silent_switch" ); 
    add_option( \$bibtex, " $bibtex_silent_switch" ); 
    add_option( \$makeindex, " $makeindex_silent_switch" ); 
    add_option( \$dvips, " $dvips_silent_switch" ); 
}

# Which kind of file do we preview?
if ( $view eq "default" ) {
    # If default viewer requested, use "highest" of dvi, ps and pdf
    #    that was requested by user.  
    # No explicit request means view dvi.
    $view = "dvi";
    if ( $postscript_mode ) { $view = "ps"; }
    if ( $pdf_mode ) { $view = "pdf"; }
}

if ( ! ( $dvi_mode || $pdf_mode || $postscript_mode || $printout_mode) ) {
    print "No specific requests made, so default to dvi by latex\n";
    $dvi_mode = 1;
}

# Set new-style requested rules:
if ( $dvi_mode ) { $requested_filerules{'latex'} = 1; }
if ( $pdf_mode == 1 ) { $requested_filerules{'pdflatex'} = 1; }
elsif ( $pdf_mode == 2 ) { $requested_filerules{'ps2pdf'} = 1; }
elsif ( $pdf_mode == 3 ) { $requested_filerules{'dvipdf'} = 1; }
if ( $postscript_mode ) { $requested_filerules{'dvips'} = 1; }
if ( $printout_mode ) { $one_time{'print'} = 1; }
if ( $preview_continuous_mode || $preview_mode ) { $one_time{'view'} = 1; }
if ( length($dvi_filter) != 0 ) { $requested_filerules{'dvi_filter'} = 1; }
if ( length($ps_filter) != 0 )  { $requested_filerules{'ps_filter'} = 1; }
if ( $banner ) { $requested_filerules{'dvips'} = 1; }


%possible_primaries = ();
foreach (&rdb_possible_primaries) {
    $possible_primaries{$_} = 1;
}

#print "POSSIBLE PRIMARIES: ";
#foreach (keys %possible_primaries ) {print "$_, ";}
#print "\n";


if ( $pdf_mode == 2 ) {
    # We generate pdf from ps.  Make sure we have the correct kind of ps.
    add_option( \$dvips, " $dvips_pdf_switch" );
}


# Make convenient forms for lookup.
# Extensions always have period.

# Convert @generated_exts to a hash for ease of look up, with exts
#    preceeded by a '.' 
# %generated_exts_all is used in analyzing file changes, to
#    distinguish changes in user files from changes in generated files.
%generated_exts_all = ();
foreach (@generated_exts ) {
    $generated_exts_all{".$_"} = 1;
}

$quell_uptodate_msgs = $silent; 
   # Whether to quell informational messages when files are uptodate
   # Will turn off in -pvc mode

# Process for each file.
# The value of $bibtex_mode set in an initialization file may get
# overridden, during file processing, so save it:
#?? Unneeded now: $save_bibtex_mode = $bibtex_mode;

$failure_count = 0;
$last_failed = 0;    # Flag whether failed on making last file
                     # This is used for showing suitable error diagnostics
FILE:
foreach $filename ( @file_list )
{
    # Global variables for making of current file:
    $updated = 0;
    $failure = 0;        # Set nonzero to indicate failure at some point of 
                         # a make.  Use value as exit code if I exit.
    $failure_msg = '';   # Indicate reason for failure
#?? Unneeded now:     $bibtex_mode = $save_bibtex_mode;

    if ( $do_cd ) {
       ($filename, $path) = fileparse( $filename );
       warn "$My_name: Changing directory to '$path'\n";
       pushd( $path );
    }
    else {
	$path = '';
    }


    ## remove extension from filename if was given.
    if ( &find_basename($filename, $root_filename, $texfile_name) )
    {
	if ( $force_mode ) {
	   warn "$My_name: Could not find file [$texfile_name]\n";
	}
	else {
            &ifcd_popd;
	    &exit_msg1( "Could not find file [$texfile_name]",
			11);
	}
    }

    # Initialize basic dependency information:

    # For use under error conditions:
    @default_includes = ($texfile_name, "$root_filename.aux");  

    $fdb_file = "$root_filename.$fdb_ext";
    
    if ($cleanup_fdb) { unlink $fdb_file; }
    if ( $cleanup_mode > 0 ) {
        my @extra_generated = ();
        my @aux_files = ();
        rdb_read_generatedB( $fdb_file, \@extra_generated, \@aux_files );
        if ( ($go_mode == 2) && !$silent ) {
            warn "$My_name: Removing all generated files\n" unless $silent;
	}
        if ($diagnostics) {
            show_array( "For deletion:\n Extra_generated:", @extra_generated );
            show_array( " Aux files:", @aux_files );
	}
        # Add to the generated files, some log file and some backup
        #    files used in previous versions of latexmk
        &cleanup1( 'blg', 'ilg', 'log', 'aux.bak', 'idx.bak', 
                   split(' ',$clean_ext), 
                   @generated_exts 
                 );
        unlink( 'texput.log', @extra_generated, "texput.aux", @aux_files );
        if ( $cleanup_mode == 1 ) { 
            &cleanup1( 'dvi', 'dviF', 'ps', 'psF', 'pdf',
                       split(' ', $clean_full_ext)
                     );
        }
    }
    if ($cleanup_only) { next FILE; }

    # Initialize file and rule databases.
    %rule_list = ();
    &rdb_make_rule_list;
    &rdb_set_rules(\%rule_list);


#??? The following are not needed if use makeB.  
#    ?? They may be set too early?
# Arrays and hashes for picking out accessible rules.
# Distinguish rules for making files and others
    @accessible_all = sort ( &rdb_accessible( keys %requested_filerules, keys %one_time ));
    %accessible_filerules = ();
    foreach (@accessible_all) {
        unless ( /view/ || /print/ ) { $accessible_filerules{$_} = 1; }
    }
    @accessible_filerules = sort  keys %accessible_filerules;

#    show_array ( "=======All rules used", @accessible_all );
#    show_array ( "=======Requested file rules", sort keys %requested_filerules );
#    show_array ( "=======Rules for files", @accessible_filerules );

    if ( $diagnostics ) {
       print "$My_name: Rules after start up for '$texfile_name'\n";
       rdb_show();
    }

    %primaries = ();
    foreach (@accessible_all) {
        if ( ($_ eq 'latex') || ($_ eq 'pdflatex') ) { $primaries{$_} = 1; }
    }

    $have_fdb = 0;
    if ( (! -e $fdb_file) && (! -e "$root_filename.aux") ) {
        # No aux and no fdb file => set up trivial aux file 
        #    and corresponding fdb_file.  Arrange them to provoke one run 
        #    as minimum, but no more if actual aux file is trivial.
        #    (Useful on big files without cross references.)
        &set_trivial_aux_fdb;
    }

    if ( -e $fdb_file ) {
        $rdb_errors = rdb_read( $fdb_file );
        $have_fdb = ($rdb_errors == 0);
    }
    if (!$have_fdb) { 
        # We didn't get a valid set of data on files used in
        # previous run.  So use filetime criterion for make
        # instead of change from previous run, until we have
        # done our own make.
	rdb_recurseA( [keys %possible_primaries],
		      sub{ if ( $$Ptest_kind == 1 ) { $$Ptest_kind = 3;} }
        );
        if ( -e "$root_filename.log" ) {
	    rdb_for_some( [keys %possible_primaries], \&rdb_set_from_logB );
	}
    }
    if ($go_mode) {
        # Force everything to be remade.
	rdb_recurseA( [keys %requested_filerules], sub{$$Pout_of_date=1;}  );
    }


    if ( $diagnostics ) {
       print "$My_name: Rules after initialization\n";
       rdb_show();
    }

    #************************************************************

    if ( $preview_continuous_mode ) { 
        &make_preview_continuousB; 
        # Will probably exit by ctrl/C and never arrive here.
        next FILE;
    }


## Handling of failures:
##    Variable $failure is set to indicate a failure, with information
##       put in $failure_msg.  
##    These variables should be set to 0 and '' at any point at which it
##       should be assumed that no failures have occurred.
##    When after a routine is called it is found that $failure is set, then
##       processing should normally be aborted, e.g., by return.
##    Then there is a cascade of returns back to the outermost level whose 
##       responsibility is to handle the error.
##    Exception: An outer level routine may reset $failure and $failure_msg
##       after initial processing, when the error condition may get 
##       ameliorated later.
    #Initialize failure flags now.
    $failure = 0;
    $failure_msg = '';
    $failure = rdb_makeB( keys %requested_filerules );
    if ($failure > 0) { next FILE;}
    rdb_for_some( [keys %one_time], \&rdb_run1 );
} # end FILE
continue {
    if ($dependents_list) { rdb_list(); }
    # Handle any errors
    if ( $failure > 0 ) {
        if ( $failure_msg ) {
            #Remove trailing space
            $failure_msg =~ s/\s*$//;
            warn "$My_name: Did not finish processing file: $failure_msg\n";
            $failure = 1;
        }
        $failure_count ++;
        $last_failed = 1;
    }
    else {
        $last_failed = 0;
    }
    &ifcd_popd;
}
# If we get here without going through the continue section:
if ( $do_cd && ($#dir_stack > -1) ) {
   # Just in case we did an abnormal exit from the loop
   warn "$My_name: Potential bug: dir_stack not yet unwound, undoing all directory changes now\n";
   &finish_dir_stack;
}

if ($failure_count > 0) {
    if ( $last_failed <= 0 ) {
        # Error occured, but not on last file, so
        #     user may not have seen error messages
        warn "\n------------\n";
        warn "$My_name: Some operations failed.\n";
    }
    if ( !$force_mode ) {
      warn "$My_name: Use the -f option to force complete processing.\n";
    }
    exit 12;
}



# end MAIN PROGRAM
#############################################################

sub fix_cmds {
   # If commands do not have placeholders for %S etc, put them in
    foreach ($latex, $pdflatex, $lpr, $lpr_dvi, $lpr_pdf,
             $pdf_previewer, $ps_previewer, $ps_previewer_landscape,
             $dvi_previewer, $dvi_previewer_landscape,
             $kpsewhich
    ) {
        # Source only
        if ( $_ && ! /%/ ) { $_ .= " %O %S"; }
    }
    foreach ($bibtex) {
        # Base only
        if ( $_ && ! /%/ ) { $_ .= " %O %B"; }
    }
    foreach ($dvipdf, $ps2pdf) {
        # Source and dest without flag for destination
        if ( $_ && ! /%/ ) { $_ .= " %O %S %D"; }
    }
    foreach ($dvips, $makeindex) {
        # Source and dest with -o dest before source
        if ( $_ && ! /%/ ) { $_ .= " %O -o %D %S"; }
    }
    foreach ($dvi_filter, $ps_filter) {
        # Source and dest, but as filters
        if ( $_ && ! /%/ ) { $_ .= " %O <%S >%D"; }
    }
} #END fix_cmds

#############################################################

sub add_option {
    # Call add_option( \$cmd, $opt )
    # Add option to command
    if ( ${$_[0]} !~ /%/ ) { &fix_cmds; }
    ${$_[0]} =~ s/%O/$_[1] %O/;
} #END add_option

#############################################################

sub rdb_make_rule_list {
# Substitutions: %S = source, %D = dest, %B = this rule's base
#                %T = texfile, %R = root = base for latex.

    # Defaults for dvi, ps, and pdf files
    my $dvi_final = "%R.dvi";
    my $ps_final  = "%R.ps";
    my $pdf_final = "%R.pdf";
    if ( length($dvi_filter) > 0) {
        $dvi_final = "%R.dviF";
    }
    if ( length($ps_filter) > 0) {
        $ps_final = "%R.psF";
    }

    my $print_file = '';
    my $print_cmd = '';
    if ( $print_type eq 'dvi' ) {
	$print_file = $dvi_final;
	$print_cmd = $lpr_dvi;
    }
    elsif ( $print_type eq 'pdf' ) {
	$print_file = $pdf_final;
	$print_cmd = $lpr_pdf;
    }
    elsif ( $print_type eq 'ps' ) {
	$print_file = $ps_final;
	$print_cmd = $lpr;
    }

    my $view_file = '';
    my $viewer = '';
    if ( $view eq 'dvi' ) { 
        $view_file = $dvi_final; 
        $viewer = $dvi_previewer;
    }
    if ( $view eq 'pdf' ) { 
        $view_file = $pdf_final; 
        $viewer = $pdf_previewer;
    }
    if ( $view eq 'ps'  ) { 
        $view_file = $ps_final;
        $viewer = $ps_previewer;
    }
# For test_kind: Use file contents for latex and friends, but file time for the others.
# This is because, especially for dvi file, the contents of the file may contain
#    a pointer to a file to be included, not the contents of the file! 
    %rule_list = (
        'latex'    => [ 'primary',  "$latex",     '',            "%T",        "%B.dvi",  "%R", 1 ],
        'pdflatex' => [ 'primary',  "$pdflatex",  '',            "%T",        "%B.pdf",  "%R", 1 ],
        'dvipdf'   => [ 'external', "$dvipdf",    'do_viewfile', $dvi_final,  "%B.pdf",  "%R", 2 ],
        'dvips'    => [ 'external', "$dvips",     'do_viewfile', $dvi_final,  "%B.ps",   "%R", 2 ],
        'dvifilter'=> [ 'external', $dvi_filter,  'do_viewfile', "%B.dvi",    "%B.dviF", "%R", 2 ],
        'ps2pdf'   => [ 'external', "$ps2pdf",    'do_viewfile', $ps_final,   "%B.pdf",  "%R", 2 ],
        'psfilter' => [ 'external', $ps_filter,   'do_viewfile', "%B.ps",     "%B.psF",  "%R", 2 ],
        'print'    => [ 'external', "$print_cmd", 'if_source',   $print_file, "",        "",   2 ],
        'view'     => [ 'external', "$viewer",    'if_source',   $view_file,  "",        "",   2 ],
    );
    %source_list = ();
    foreach my $rule (keys %rule_list) {
        $source_list{$rule} = [];
        my $PAsources = $source_list{$rule};
        my ( $cmd_type, $cmd, $source, $dest, $root ) = @{$rule_list{$rule}};
        if ($source) {
	    push @$PAsources, [ $rule, $source, '' ];
	}
    }

# Ensure we only have one way to make pdf file, and that it is appropriate:
    if ($pdf_mode == 1) { delete $rule_list{'dvipdf'}; delete $rule_list{'ps2pdf'}; }
    elsif ($pdf_mode == 2) { delete $rule_list{'dvipdf'}; delete $rule_list{'pdflatex'}; }
    else { delete $rule_list{'pdflatex'}; delete $rule_list{'ps2pdf'}; }

} # END rdb_make_rule_list 

#************************************************************

sub rdb_set_rules {
    # Call rdb_set_rules( \%rule_list, ...)
    # Set up rule database from definitions

    # Map of files to rules that MAKE them:
    local %from_rules = ();
    %rule_db = ();

    foreach my $Prule_list (@_) {
	foreach my $rule ( sort keys %$Prule_list) {
	    my ( $cmd_type, $ext_cmd, $int_cmd, $source, $dest, $base, $test_kind ) = @{$$Prule_list{$rule}};
	    my $needs_making = 0;
	    # Substitute in the filename variables, since we will use
	    # those for determining filenames.  But delay expanding $cmd 
	    # until run time, in case of changes.
	    foreach ($base, $source, $dest ) { 
		s/%R/$root_filename/;
	    }
	    foreach ($source, $dest ) { 
		s/%B/$base/;
		s/%T/$texfile_name/;
	    }
    #        print "$rule: $cmd_type, EC='$ext_cmd', IC='$int_cmd', $test_kind,\n",
    #              "    S='$source', D='$dest', B='$base' $needs_making\n";
	    rdb_create_rule( $rule, $cmd_type, $ext_cmd, $int_cmd, $test_kind, 
			     $source, $dest, $base,
			     $needs_making );
	    if ($dest)   { $from_rules{$dest} = $rule ; }
	}
	rdb_for_all( 
	    0,
	    sub{ 
    #            my ($base, $path, $ext) = fileparse( $file, '\.[^\.]*' );
    #            if ( exists $from_rules{$file} && ! exists $generated_exts_all{$ext} ) { 
    #                # Show how to make this file.  But don't worry about generated
    #                # files.
		if ( exists $from_rules{$file} ) { 
		    $$Pfrom_rule = $from_rules{$file}; 
		}
    #??            print "$rule: $file, $$Pfrom_rule\n";
	    }
	);
    } # End arguments of subroutine
    &rdb_make_links;
} # END rdb_set_rules

#************************************************************

sub rdb_make_links {
# ?? Problem if there are multiple rules for getting a file.  Notably pdf.
#    Which one to choose?
    # Create $from_rule if there's a suitable rule.
    # Map files to rules:
    local %from_rules = ();
    rdb_for_all( sub{ if($$Pdest){$from_rules{$$Pdest} = $rule;} } );
#??    foreach (sort keys %from_rules) {print "D='$_' F='$from_rules{$_}\n";}
    rdb_for_all( 
        0,
        sub{ 
            if ( exists $from_rules{$file} ) { $$Pfrom_rule = $from_rules{$file}; }
#??            print "$rule: $file, $$Pfrom_rule\n";
	}
    );
    rdb_for_all( 
        0,
        sub{ 
            if ( exists $from_rules{$file} ) { 
                $$Pfrom_rule = $from_rules{$file}; 
            }
            if ( $$Pfrom_rule && (! rdb_rule_exists( $$Pfrom_rule ) ) ) {
                $$Pfrom_rule = '';
	    }
#??            print "$rule: $file, $$Pfrom_rule\n";
	}
    );
} # END rdb_make_links

#************************************************************

sub set_trivial_aux_fdb {
    # 1. Write aux file EXACTLY as would be written if the tex file
    #    had no cross references, etc. I.e., a minimal .aux file. 
    # 2. Write a corresponding fdb file
    # 3. Provoke a run of (pdf)latex (actually of all primaries). 

    local $aux_file = "$root_filename.aux";
    open( aux_file, '>', $aux_file )
        or die "Cannot write file '$aux_file'\n";
    print aux_file "\\relax \n";
    close(aux_file);

    foreach my $rule (keys %primaries ) { 
        rdb_ensure_file( $rule, $texfile_name );
        rdb_ensure_file( $rule, $aux_file );
        rdb_one_rule(  $rule,  
                       sub{ $$Pout_of_date = 1; }
                    );
    }
    &rdb_write( $fdb_file );
} #END set_trivial_aux_fdb

#************************************************************
#### Particular actions
#************************************************************
#************************************************************

sub do_cusdep {
    # Unconditional application of custom-dependency
    # except that rule is not applied if the source file source 
    # does not exist, and an error is returned if the dest is not made.
    #
    # Assumes rule context for the custom-dependency, and that my first 
    # argument is the name of the subroutine to apply
    my $func_name = $_[0];
    my $return = 0;
    if ( !-e $$Psource ) {
        # Source does not exist.  Users of this rule will need to turn
        # it off when custom dependencies are reset
	if ( !$silent ) {
#            warn "$My_name: In trying to apply custom-dependency rule\n",
#            "  to make '$$Pdest' from '$$Psource'\n",
#            "  the source file has disappeared since the last run\n";
	}
        # Treat as successful
    }
    elsif ( !$func_name ) {
        warn "$My_name: Possible misconfiguration or bug:\n",
        "  In trying to apply custom-dependency rule\n",
        "  to make '$$Pdest' from '$$Psource'\n",
        "  the function name is blank.\n";
    }
    elsif ( ! defined &$func_name ) {
        warn "$My_name: Misconfiguration or bug,",
        " in trying to apply custom-dependency rule\n",
        "  to make '$$Pdest' from '$$Psource'\n",
        "  function name '$func_name' does not exists.\n";
    }
    else {
	my $cusdep_ret = &$func_name( $$Pbase );
        if ( defined $cusdep_ret && ($cusdep_ret != 0) ) {
	    $return = $cusdep_ret;
	    if ($return) {
                warn "Rule '$rule', function '$func_name'\n",
                     "   failed with return code = $return\n";
	    }
	}
        elsif ( !-e $$Pdest ) {
            # Destination non-existent, but routine failed to give an error
            warn "$My_name: In running custom-dependency rule\n",
            "  to make '$$Pdest' from '$$Psource'\n",
            "  function '$func_name' did not make the destination.\n";
	    $return = -1;
	}
    }
    return $return;
}  # END do_cusdep

#************************************************************

sub do_viewfile {
    # Unconditionally make file for viewing, going through temporary file if
    # Assumes rule context

    my $return = 0;
    my ($base, $path, $ext) = fileparseA( $$Pdest );
    if ( &view_file_via_temporary ) {
        my $tmpfile = tempfile1( "${root_filename}_tmp", $ext );
        $return = &rdb_ext_cmd1( '', '', $tmpfile );
        move( $tmpfile, $$Pdest );
    }
    else {
        $return = &rdb_ext_cmd;
    }
    return $return;
} #END do_viewfile

#************************************************************

sub if_source {
    # Unconditionally apply rule if source file exists.
    # Assumes rule context
    if ( -e $$Psource ) {
        return &rdb_ext_cmd;
    }
    else {
	return -1;
    }
} #END if_source

#************************************************************
#### Subroutines
#************************************************************
#************************************************************

# Finds the basename of the root file
# Arguments:
#  1 - Filename to breakdown
#  2 - Where to place base file
#  3 - Where to place tex file
#  Returns non-zero if tex file does not exist
#
# The rules for determining this depend on the implementation of TeX.
# The variable $extension_treatment determines which rules are used.

sub find_basename
#?? Need to use kpsewhich, if possible
{
  local($given_name, $base_name, $ext, $path, $tex_name);
  $given_name = $_[0];
  if ( "$extension_treatment" eq "miktex_old" ) {
       # Miktex v. 1.20d: 
       #   1. If the filename has an extension, then use it.
       #   2. Else append ".tex".
       #   3. The basename is obtained from the filename by
       #      removing the path component, and the extension, if it
       #      exists.  If a filename has a multiple extension, then
       #      all parts of the extension are removed. 
       #   4. The names of generated files (log, aux) are obtained by
       #      appending .log, .aux, etc to the basename.  Note that
       #      these are all in the CURRENT directory, and the drive/path
       #      part of the originally given filename is ignored.
       #
       #   Thus when the given filename is "\tmp\a.b.c", the tex
       #   filename is the same, and the basename is "a".

       ($base_name, $path, $ext) = fileparse( $given_name, '\..*' );
       if ( "$ext" eq "") { $tex_name = "$given_name.tex"; }
       else { $tex_name = $given_name; }
       $_[1] = $base_name;
       $_[2] = $tex_name;
  }
  elsif ( "$extension_treatment" eq "unix" ) {
       # unix (at least web2c 7.3.1) => 
       #   1. If filename.tex exists, use it, 
       #   2. else if filename exists, use it.
       #   3. The base filename is obtained by deleting the path
       #      component and, if an extension exists, the last
       #      component of the extension, even if the extension is
       #      null.  (A name ending in "." has a null extension.)
       #   4. The names of generated files (log, aux) are obtained by
       #      appending .log, .aux, etc to the basename.  Note that
       #      these are all in the CURRENT directory, and the drive/path
       #      part of the originally given filename is ignored.
       #
       #   Thus when the given filename is "/tmp/a.b.c", there are two
       #   cases: 
       #      a.  /tmp/a.b.c.tex exists.  Then this is the tex file,
       #          and the basename is "a.b.c".
       #      b.  /tmp/a.b.c.tex does not exist.  Then the tex file is
       #          "/tmp/a.b.c", and the basename is "a.b".

      if ( -e "$given_name.tex" ) {
         $tex_name = "$given_name.tex";
      }
      else {
         $tex_name = "$given_name";
      }
      ($base_name, $path, $ext) = fileparse( $tex_name, '\.[^\.]*' );
      $_[1] = $base_name;
      $_[2] = $tex_name;
  }
  else {
     die "$My_name: Incorrect configuration gives \$extension_treatment=",
         "'$extension_treatment'\n";
  }
   if ($diagnostics) {
      print "Given='$given_name', tex='$tex_name', base='$base_name'\n";
  }
  return ! -e $tex_name;
} #END find_basename

#************************************************************

sub make_preview_continuousB {
  # Version for use with makeB
    local @changed = ();
    local @disappeared = ();
    local @no_dest = ();       # Non-existent destination files
    local @rules_to_apply = ();
    local $failure = 0;
    local $runs = 0;
    local %rules_applied = ();
    local $updated = 0;

  # How do we persuade viewer to update.  Default is to do nothing.
  my $viewer_update_method = 0;
  my $viewer_update_signal = undef;
  my $viewer_update_command = undef;
  # Extension of file:
  my $ext;
  # Command to run viewer.  '' for none
  my $viewer = undef;

  # What to make?
  my @targets = keys %requested_filerules;

  $quell_uptodate_msgs = 1;
  local $view_file = '';
  rdb_one_rule( 'view', sub{ $view_file = $$Psource; } );
  if ( $view eq 'dvi' ) {
     $viewer_update_method = $dvi_update_method;
     $viewer_update_signal = $dvi_update_signal;
     if (defined $dvi_update_command) {
         $viewer_update_command = $dvi_update_command;
     }
  } 
  elsif ( $view eq 'none' ) {
      warn "Not using a previewer\n";
      $view_file = '';
  }
  elsif ( $view eq 'ps' ) {
     $viewer_update_method = $ps_update_method;
     $viewer_update_signal = $ps_update_signal;
     if (defined $ps_update_command) {
         $viewer_update_command = $ps_update_command;
     }
  }
  elsif ( $view eq 'pdf' ) {
     $viewer_update_method = $pdf_update_method;
     $viewer_update_signal = $pdf_update_signal;
     if (defined $pdf_update_command) {
         $viewer_update_command = $pdf_update_command;
     }
  }
  else {
      warn "$My_name:  BUG: Invalid preview method '$view'\n";
      exit 20;
  }

  # Viewer information:
  my $viewer_running = 0;    # No viewer running yet
  my $viewer_process = 0;    # default: no viewer process number known
  my $need_to_get_viewer_process = 0;
       # This will be used when we start a viewer that will be updated
       # by use of a signal.  The process number returned by the startup
       # of the viewer may not be that of the viewer, but may, for example,
       # be that of a script that starts the viewer.  But the startup time
       # may be signficant, so we will wait until the next needed update before
       # determining the process number of the viewer.

  if ( ($view_file ne '') && (-e $view_file) && !$new_viewer_always ) {
      # Is a viewer already running?
      #    (We'll save starting up another viewer.)
      $viewer_process = &find_process_id( $view_file );
      if ( $viewer_process ) {
          warn "$My_name: Previewer is already running\n" 
              if !$silent;
          $viewer_running = 1;
          $need_to_get_viewer_process = 0;
      }
  }
  # Loop forever, rebuilding .dvi and .ps as necessary.
  # Set $first_time to flag first run (to save unnecessary diagnostics)
CHANGE:
  for (my $first_time = 1; 1; $first_time = 0 ) {
     $updated = 0;
     $failure = 0;
     $failure_msg = '';
     if ( $MSWin_fudge_break && ($^O eq "MSWin32") ) {
        # Fudge under MSWin32 ONLY, to stop perl/latexmk from
        #   catching ctrl/C and ctrl/break, and let it only reach
        #   downstream programs. See comments at first definition of
        #   $MSWin_fudge_break.
        $SIG{BREAK} = $SIG{INT} = 'IGNORE';
     }
     $failure = rdb_makeB( @targets );

##     warn "=========Viewer PID = $viewer_process; updated=$updated\n";

     if ( $MSWin_fudge_break && ($^O eq "MSWin32") ) {
        $SIG{BREAK} = $SIG{INT} = 'DEFAULT';
     }
     if ( $failure > 0 ) {
        if ( !$failure_msg ) {
	    $failure_msg = 'Failure to make the files correctly';
	}
        # There will be files changed during the run that are irrelevant.
        # We need to wait for the user to change the files.
        # So set the GENERATED files as up-to-date
        rdb_for_some( [keys %current_primaries], \&rdb_update_gen_files );

        $failure_msg =~ s/\s*$//;  #Remove trailing space
        warn "$My_name: $failure_msg\n",
 "    ==> You will need to change a source file before I do another run <==\n";
     }
     elsif ( ($view_file ne '') && (-e $view_file) && $updated && $viewer_running ) {
         # A viewer is running.  Explicitly get it to update screen if we have to do it:
         if ($viewer_update_method == 2) {
	     if ($need_to_get_viewer_process ) {
                 $viewer_process = &find_process_id(  $view_file );
                 $need_to_get_viewer_process = 0;
	     }
             if (defined $viewer_update_signal) {
                 print "$My_name: signalling viewer, process ID $viewer_process\n"
                    if $diagnostics ;
	         kill $viewer_update_signal, $viewer_process;
	     }
             else {
                 warn "$My_name: viewer is supposed to be sent a signal\n",
                      "  but no signal is defined.  Misconfiguration or bug?\n";
             }
         }
         elsif ($viewer_update_method == 4) {
             if (defined $viewer_update_command) {
		 warn "RUN $viewer_update_command\n";
 	         my ($update_pid, $update_retcode) 
                    = &Run_msg( $viewer_update_command );
                 if ($update_retcode != 0) {
		     warn "$My_name: I could not run command to update viewer\n";
	         }
	     }
             else {
                 warn "$My_name: viewer is supposed to be updated by running a command,\n",
                      "  but no command is defined.  Misconfiguration or bug?\n";
             }       
	 }
     }
     elsif ( ($view_file ne '') && (-e $view_file) && !$viewer_running ) {
         # Start the viewer
	 if ( !$silent ) {
             if ($new_viewer_always) {
                 warn "$My_name: starting previewer for '$view_file'\n",
                      "------------\n";
	     }
             else {
                 warn "$My_name: I have not found a previewer that ",
                      "is already running. \n",
                      "   So I will start it for '$view_file'\n",
                      "------------\n";
	     }
         }
         local $retcode = rdb_makeB ( 'view' );
         if ( $retcode != 0 ) {
             if ($force_mode) {
                 warn "$My_name: I could not run previewer\n";
             }
             else {
                 &exit_msg1( "I could not run previewer", $retcode);
             }
         }
         else {
             $viewer_running = 1;
             if ($viewer_update_method == 2) {
                 # If viewer will be update by sending it a signal,
                 #   then tell myself to get the viewer's true process
                 #   number later.  
                 # Just at this moment the process started above, that has 
                 #   process number $viewer_process, may just be a startup
                 #   script and not the viewer itself.
                 $need_to_get_viewer_process = 1;
	     }
	 } # end analyze result of trying to run viewer
     } # end start viewer
     if ( $first_time || $updated || $failure ) {
        print "\n=== Watching for updated files. Use ctrl/C to stop ...\n";
     }
     $waiting = 1; if ($diagnostics) { warn "WAITING\n"; }
     WAIT: while (1) {
        sleep($sleep_time);
        &rdb_clear_change_record;
        rdb_recurseA( [@targets], \&rdb_flag_changes_here );
        if ( &rdb_count_changes > 0) { 
            &rdb_diagnose_changes
                unless $silent;
#??? 
	    warn "$My_name: File(s) changed or not used in previous run(s).  Remake files.\n"; 
            last WAIT;
        }
     # Does this do this job????
        local $new_files = 0;
        rdb_for_some( [keys %current_primaries], sub{ $new_files += &rdb_find_new_filesB } );
        if ($new_files > 0) {
	    warn "$My_name: New file(s) found.\n";
            last WAIT; 
        }
     } # end WAIT:
     $waiting = 0; if ($diagnostics) { warn "NOT       WAITING\n"; }
  } #end infinite_loop CHANGE:
} #END sub make_preview_continuousB

#************************************************************

sub process_rc_file {
    # Usage process_rc_file( filename )
    # Run rc_file whose name is given in first argument
    #    Exit with code 11 if file could not be read.  
    #      (In general this is not QUITE the right error)
    #    Exit with code 13 if there is a syntax error or other problem.
    # ???Should I leave the exiting to the caller (perhaps as an option)?
    #     But I can always catch it with an eval if necessary.
    #     That confuses ctrl/C and ctrl/break handling.
    my $rc_file = $_[0];
    warn "$My_name: Executing PERL code in file '$rc_file'...\n" 
        if  $diagnostics;
    do( $rc_file );
    # The return value from the do is not useful, since it is the value of 
    #    the last expression evaluated, which could be anything.
    # The correct test of errors is on the values of $! and $@.

# This is not entirely correct.  On gluon2:
#      rc_file does open of file, and $! has error, apparently innocuous
#      See ~/proposal/06/latexmkrc-effect

    my $OK = 1;
    if ( $! ) {
        # Get both numeric error and its string, by forcing numeric and 
        #   string contexts:
        my $err_no = $!+0;
        my $err_string = "$!";
        warn "$My_name: Initialization file '$rc_file' could not be read,\n",
             "   or it gave some other problem. Error code \$! = $err_no.\n",
             "   Error string = '$err_string'\n";
	$! = 256;
        $OK = 0;
    }
    if ( $@ ) {
	$! = 256;
        # Indent the error message to make it easier to locate
        my $indented = prefix( $@, "    " );
        $@ = "";
        warn "$My_name: Initialization file '$rc_file' gave an error:\n",
            "$indented";
        $OK = 0;
    }
    if ( ! $OK ) { 
        die "$My_name: Stopping because of problem with rc file\n"; 
    }
} #END process_rc_file

#************************************************************

sub execute_code_string {
    # Usage execute_code_string( string_of_code )
    # Run the PERL code contained in first argument
    #    Exit with code 13 if there is a syntax error or other problem.
    # ???Should I leave the exiting to the caller (perhaps as an option)?
    #     But I can always catch it with an eval if necessary.
    #     That confuses ctrl/C and ctrl/break handling.
    my $code = $_[0];
    warn "$My_name: Executing initialization code specified by -e:\n",
         "   '$code'...\n" 
        if  $diagnostics;
    eval $code;
    # The return value from the eval is not useful, since it is the value of 
    #    the last expression evaluated, which could be anything.
    # The correct test of errors is on the values of $! and $@.

    if ( $@ ) {
	$! = 256;
        my $message = $@;
        $@ = "";
        $message =~ s/\s*$//;
        die "$My_name: ",
            "Stopping because executing following code from command line\n",
            "    $code\n",
            "gave an error:\n",
            "    $message\n";
    }
} #END execute_code_string

#************************************************************

sub cleanup1 {
    # Usage: cleanup1( exts_without_period, ... )
    foreach (@_) { unlink("$root_filename.$_"); }
} #END cleanup1

#************************************************************
#************************************************************
#************************************************************

#   Error handling routines, warning routines, help

#************************************************************

sub die_trace {
    # Call: die_trace( message );
    &traceback;   # argument(s) passed unchanged
    die "\n";
} #END die_trace

#************************************************************

sub traceback {
    # Call: &traceback 
    # or traceback( message,  )
    my $msg = shift;
    if ($msg) { warn "$msg\n"; }
    warn "Traceback:\n";
    my $i=0;     # Start with immediate caller
    while ( my ($pack, $file, $line, $func) = caller($i++) ) {
        if ($func eq 'die_trace') { next; }
        warn "   $func called from line $line\n";
    }
} #END traceback

#************************************************************

sub exit_msg1
{
  # exit_msg1( error_message, retcode [, action])
  #    1. display error message
  #    2. if action set, then restore aux file
  #    3. exit with retcode
  warn "\n------------\n";
  warn "$My_name: $_[0].\n";
  warn "-- Use the -f option to force complete processing.\n";

  my $retcode = $_[1];
  if ($retcode >= 256) {
     # Retcode is the kind returned by system from an external command
     # which is 256 * command's_retcode
     $retcode /= 256;
  }
  exit $retcode;
} #END exit_msg1

#************************************************************

sub warn_running {
   # Message about running program:
    if ( $silent ) {
        warn "$My_name: @_\n";
    }
    else {
        warn "------------\n@_\n------------\n";
    }
} #END warn_running

#************************************************************

sub exit_help
# Exit giving diagnostic from arguments and how to get help.
{
    warn "\n$My_name: @_\n",
         "Use\n",
         "   $my_name -help\nto get usage information\n";
    exit 10;
} #END exit_help


#************************************************************

sub print_help
{
  print
  "$My_name $version_num: Automatic LaTeX document generation routine\n\n",
  "Usage: $my_name [latexmk_options] [filename ...]\n\n",
  "  Latexmk_options:\n",
  "   -bm <message> - Print message across the page when converting to postscript\n",
  "   -bi <intensity> - Set contrast or intensity of banner\n",
  "   -bs <scale> - Set scale for banner\n",
  "   -commands  - list commands used by $my_name for processing files\n",
  "   -c     - clean up (remove) all nonessential files, except\n",
  "            dvi, ps and pdf files.\n",
  "            This and the other clean-ups are instead of a regular make.\n",
  "   -C     - clean up (remove) all nonessential files\n",
  "            including aux, dep, dvi, postscript and pdf files\n",
  "            But exclude file of database of file information\n",
  "   -CA     - clean up (remove) absolutely ALL nonessential files\n",
  "            including aux, dep, dvi, postscript and pdf files,\n",
  "            and file of database of file information\n",
  "   -CF     - Remove file of database of file information before doing \n",
  "            other actions\n",
  "   -cd    - Change to directory of source file when processing it\n",
  "   -cd-   - Do NOT change to directory of source file when processing it\n",
  "   -dependents   - Show list of dependent files after processing\n",
  "   -dependents-  - Do not show list of dependent files after processing\n",
  "   -dF <filter> - Filter to apply to dvi file\n",
  "   -dvi   - generate dvi\n",
  "   -dvi-  - turn off required dvi\n",
  "   -e <code> - Execute specified PERL code\n",
  "   -f     - force continued processing past errors\n",
  "   -f-    - turn off forced continuing processing past errors\n",
  "   -F     - Ignore non-existent files when testing for dependencies\n",
  "   -F-    - Turn off -F\n",
  "   -gg    - Super go mode: clean out generated files (-CA), and then\n",
  "            process files regardless of file timestamps\n",
  "   -g     - process regardless of file timestamps\n",
  "   -g-    - Turn off -g\n",
  "   -h     - print help\n",
  "   -help - print help\n",
  "   -l     - force landscape mode\n",
  "   -l-    - turn off -l\n",
  "   -new-viewer   - in -pvc mode, always start a new viewer\n",
  "   -new-viewer-  - in -pvc mode, start a new viewer only if needed\n",
  "   -nodependents  - Do not show list of dependent files after processing\n",
  "   -pdf   - generate pdf by pdflatex\n",
  "   -pdfdvi - generate pdf by dvipdf\n",
  "   -pdfps - generate pdf by ps2pdf\n",
  "   -pdf-  - turn off pdf\n",
  "   -ps    - generate postscript\n",
  "   -ps-   - turn off postscript\n",
  "   -pF <filter> - Filter to apply to postscript file\n",
  "   -p     - print document after generating postscript.\n",
  "            (Can also .dvi or .pdf files -- see documentation)\n",
  "   -print=dvi     - when file is to be printed, print the dvi file\n",
  "   -print=ps      - when file is to be printed, print the ps file (default)\n",
  "   -print=pdf     - when file is to be printed, print the pdf file\n",
  "   -pv    - preview document.  (Side effect turn off continuous preview)\n",
  "   -pv-   - turn off preview mode\n",
  "   -pvc   - preview document and continuously update.  (This also turns\n",
  "                on force mode, so errors do not cause $my_name to stop.)\n",
  "            (Side effect: turn off ordinary preview mode.)\n",
  "   -pvc-  - turn off -pvc\n",
  "   -r <file> - Read custom RC file\n",
  "   -silent  - silence progress messages from called programs\n",
  "   -v     - display program version\n",
  "   -verbose - display usual progress messages from called programs\n",
  "   -version      - display program version\n",
  "   -view=default - viewer is default (dvi, ps, pdf)\n",
  "   -view=dvi     - viewer is for dvi\n",
  "   -view=none    - no viewer is used\n",
  "   -view=ps      - viewer is for ps\n",
  "   -view=pdf     - viewer is for pdf\n",
  "   filename = the root filename of LaTeX document\n",
  "\n",
  "-p, -pv and -pvc are mutually exclusive\n",
  "-h, -c and -C overides all other options.\n",
  "-pv and -pvc require one and only one filename specified\n",
  "All options can be introduced by '-' or '--'.  (E.g., --help or -help.)\n",
  "Contents of RC file specified by -r overrides options specified\n",
  "  before the -r option on the command line\n";

} #END print_help

#************************************************************
sub print_commands
{
  warn "Commands used by $my_name:\n",
       "   To run latex, I use \"$latex\"\n",
       "   To run pdflatex, I use \"$pdflatex\"\n",
       "   To run bibtex, I use \"$bibtex\"\n",
       "   To run makeindex, I use \"$makeindex\"\n",
       "   To make a ps file from a dvi file, I use \"$dvips\"\n",
       "   To make a ps file from a dvi file with landscape format, ",
           "I use \"$dvips_landscape\"\n",
       "   To make a pdf file from a dvi file, I use \"$dvipdf\"\n",
       "   To make a pdf file from a ps file, I use \"$ps2pdf\"\n",
       "   To view a pdf file, I use \"$pdf_previewer\"\n",
       "   To view a ps file, I use \"$ps_previewer\"\n",
       "   To view a ps file in landscape format, ",
            "I use \"$ps_previewer_landscape\"\n",
       "   To view a dvi file, I use \"$dvi_previewer\"\n",
       "   To view a dvi file in landscape format, ",
            "I use \"$dvi_previewer_landscape\"\n",
       "   To print a ps file, I use \"$lpr\"\n",
       "   To print a dvi file, I use \"$lpr_dvi\"\n",
       "   To print a pdf file, I use \"$lpr_pdf\"\n",
       "   To find running processes, I use \"$pscmd\", \n",
       "      and the process number is at position $pid_position\n";
   warn "Notes:\n",
        "  Command starting with \"start\" is run detached\n",
        "  Command that is just \"start\" without any other command, is\n",
        "     used under MS-Windows to run the command the operating system\n",
        "     has associated with the relevant file.\n",
        "  Command starting with \"NONE\" is not used at all\n";
} #END print_commands

#************************************************************

sub view_file_via_temporary {
    return $always_view_file_via_temporary 
           || ($pvc_view_file_via_temporary && $preview_continuous_mode);
} #END view_file_via_temporary

#************************************************************
#### Tex-related utilities


sub check_bibtex_log {
    # Check for bibtex warnings:
    # Usage: check_bibtex_log( base_of_bibtex_run )
    # return 0: OK, 1: bibtex warnings, 2: bibtex errors, 
    #        3: could not open .blg file.

    my $base = $_[0];
    my $log_name = "$base.blg";
    my $log_file = new FileHandle;
    open( $log_file, "<$log_name" )
      or return 3;
    my $have_warning = 0;
    my $have_error = 0;
    while (<$log_file>) {
        if (/Warning--/) { 
            #print "Bibtex warning: $_"; 
            $have_warning = 1;
        }
        if (/error message/) { 
            #print "Bibtex error: $_"; 
            $have_error = 1;
        }
    }
    close $log_file;
    if ($have_error) {return 2;}
    if ($have_warning) {return 1;}
    return 0;
} #END check_bibtex_log

#**************************************************

sub clean_file_name{
    # Convert filename found in log file to true filename.
    # Used normally only by parse_logB, below
    # 1. For names of form 
    #    `"string".ext', which arises e.g., from \jobname.bbl:
    #    when the base filename contains spaces, \jobname has quotes.
    #    and from \includegraphics with basename specified.
    # 2. Or "string.ext" from \includegraphcs with basename and ext specified.
    my $filename = $_[0];
    $filename =~ s/^\"([^\"]*)\"(.*)$/$1$2/;
    return $filename;
}
# ------------------------------

sub parse_logB {
# Scan log file for: dependent files
#    reference_changed, bad_reference, bad_citation
# Return value: 1 if success, 0 if no log file.
# Set global variables:
#   %dependents: maps definite dependents to code:
#      0 = from missing-file line
#            May have no extension
#            May be missing path
#      1 = from 'File: ... Graphic file (type ...)' line
#            no path.  Should exist, but may need a search, by kpsewhich.
#      2 = from regular '(...' coding for input file, 
#            Has NO path, which it would do if LaTeX file
#            Highly likely to be mis-parsed line
#      3 = ditto, but has a path character ('/').  
#            Should be LaTeX file that exists.
#            If it doesn't exist, we have probably a mis-parsed line.
#            There's no need to do a search.
#      4 = definitive, which in this subroutine is only
#          done for default dependents
# Treat the following specially, since they have special rules
#   @bbl_files to list of .bbl files.
#   %idx_files to map from .idx files to .ind files.
# Also set
#   $reference_changed, $bad_reference, $bad_citation
# Trivial or default values if log file does not exist/cannot be opened


    # Returned info:
    %dependents = ();
    foreach (@default_includes) { $dependents{$_} = 4; }
    @bbl_files = ();
    %idx_files = ();    # Maps idx_file to (ind_file, base)

    $reference_changed = 0;
    $bad_reference = 0;
    $bad_citation = 0;

    my $log_name = "$root_filename.log";
    my $log_file = new FileHandle;
    if ( ! open( $log_file, "<$log_name" ) ) {
        return 0;
    }

LINE:
    while(<$log_file>) { 
        chomp;
        if ( $. == 1 ){
	    if ( /^This is / ) {
	        # First line OK
                next LINE;
            } else {
                warn "$My_name: Error on first line of '$log_name'.  ".
                    "This is apparently not a TeX log file.\n";
                close $log_file;
                $failure = 1;
                $failure_msg = "Log file '$log_name' appears to have wrong format.";
                return 0;
	    }
	}
        # Handle wrapped lines:
        # They are lines brutally broken at exactly $log_wrap chars 
        #    excluding line-end.
        my $len = length($_);
        while ($len == $log_wrap) {
            my $extra = <$log_file>;
            chomp $extra;
            $len = length($extra);
            $_ .= $extra;
        }
        # Check for changed references, bad references and bad citations:
        if (/Rerun to get/) { 
            warn "$My_name: References changed.\n";
            $reference_changed = 1;
        } 
	if (/LaTeX Warning: (Reference[^\001]*undefined)./) { 
	    warn "$My_name: $1 \n";
	    $bad_reference = 1;
	} 
	if (/LaTeX Warning: (Citation[^\001]*undefined)./) {
	    warn "$My_name: $1 \n";
	    $bad_citation = 1;
	}
	if ( /^Document Class: / ) {
	    # Class sign-on line
	    next LINE;
	}
	if ( /^\(Font\)/ ) {
	    # Font info line
	    next LINE;
	}
	if ( /^Output written on / ) {
	    # Latex message
	    next LINE;
	}
	if ( /^Overfull / 
	     || /^Underfull / 
             || /^or enter new name\. \(Default extension: .*\)/ 
             || /^\*\*\* \(cannot \\read from terminal in nonstop modes\)/
           ) {
	    # Latex error/warning, etc.
	    next LINE;
	}
	if ( /^Writing index file (.*)$/ ) {
	    my $idx_file = $1;
	    # Typically, there is trailing space, not part of filename:
	    $idx_file =~ s/\s*$//;
	    $idx_file = clean_file_name($idx_file);
	    my ($idx_base, $idx_path, $idx_ext) = fileparseA( $idx_file );
	    $idx_base = $idx_path.$idx_base;
	    if ( $idx_ext eq '.idx' ) {
		warn "$My_name: Index file '$idx_file' written\n"
		  unless $silent;
		$idx_files{$idx_file} = [ "$idx_base.ind", $idx_base ];
	    }
	    else {
		warn "$My_name: Index file '$idx_file' written\n",
		     "  ==> but it has an extension I do not know how to handle <==\n";
	    }

	    next LINE;
	}
	if ( /^No file (.*?\.bbl)./ ) {
	    # Notice that the
	    my $bbl_file = clean_file_name($1);
	    warn "$My_name: Non-existent bbl file '$bbl_file'\n $_\n";
    	    $dependents{$bbl_file} = 0;
	    push @bbl_files, $bbl_file;
	    next LINE;
	}
	foreach my $pattern (@file_not_found) {
	    if ( /$pattern/ ) {
		my $file = clean_file_name($1);
		warn "$My_name: Missing input file: '$file' from line\n  '$_'\n"
		    unless $silent;
		$dependents{$file} = 0;
		next LINE;
	    }
	}
	if ( /^File: ([^\s\[]*) Graphic file \(type / ) {
	    # First line of message from includegraphics/x
	    $dependents{$1} = 1;
	    next LINE;
	}
	# Now test for generic lines to ignore, only after special cases!
	if ( /^File: / ) {
	   # Package sign-on line. Includegraphics/x also produces a line 
	   # with this signature, but I've already handled it.
	   next LINE;
	}
	if ( /^Package: / ) {
	    # Package sign-on line
	    next LINE;
	}
	if (/^\! LaTeX Error: / ) {
	    next LINE;
	}
	if (/^No pages of output\./) {
	    warn "$My_name: Log file says no output from latex\n"
	       unless $silent;
	    next LINE;
	}
   INCLUDE_CANDIDATE:
        while ( /\((.*$)/ ) {
        # Filename found by
        # '(', then filename, then terminator.
        # Terminators: obvious candidates: ')':  end of reading file
        #                                  '(':  beginning of next file
        #                                  ' ':  space is an obvious separator
        #                                  ' [': start of page: latex
        #                                        and pdflatex put a
        #                                        space before the '['
        #                                  '[':  start of config file
        #                                        in pdflatex, after
        #                                        basefilename.
        #                                  '{':  some kind of grouping
        # Problem: 
        #   All or almost all special characters are allowed in
        #   filenames under some OS, notably UNIX.  Luckily most cases
        #   are rare, if only because the special characters need
        #   escaping.  BUT 2 important cases are characters that are
        #   natural punctuation
        #   Under MSWin, spaces are common (e.g., "C:\Program Files")
        #   Under VAX/VMS, '[' delimits directory names.  This is
        #   tricky to handle.  But I think few users use this OS
        #   anymore.
        #
        # Solution: use ' [', but not '[' as first try at delimiter.
	# Then if candidate filename is of form 'name1[name2]', then
	#   try splitting it.  If 'name1' and/or 'name2' exists, put
	#   it/them in list, else just put 'name1[name2]' in list.
	# So form of filename is now:
	#  '(', 
	# then any number of characters that are NOT ')', '(', or '{'
	#   (these form the filename);
	# then ' [', or ' (', or ')', or end-of-string.
	# That fails for pdflatex
	# In log file:
	#   '(' => start of reading of file, followed by filename
	#   ')' => end of reading of file
	#   '[' => start of page (normally preceeded by space)
	# Remember: 
	#    filename (on VAX/VMS) may include '[' and ']' (directory
	#             separators) 
	#    filenames (on MS-Win) commonly include space.

	# First step: replace $_ by whole of line after the '('
	#             Thus $_ is putative filename followed by other stuff.
            $_ = $1; 
            if ( /^([^\(^\)^\{]*?)\s\[/ ) {
                # Terminator: space then '['
                # Use *? in condition: to pick up first ' [' as terminator
                # 'file [' should give good filename.
            }
            elsif ( /^([^\(^\)^\{]*)\s(?=\()/ ) {
                # Terminator is ' (', but '(' isn't in matched string,
                # so we keep the '(' ready for the next match
            }
            elsif  ( /^([^\(^\)^\{]*)(\))/ ) {
                # Terminator is ')'
            }
            elsif ( /^([^\(^\)^\{]*?)\s*\{/ ) {
                # Terminator: arbitrary space then '{'
                # Use *? in condition: to pick up first ' [' as terminator
                # 'file [' should give good filename.
            }
	    else {
                #Terminator is end-of-string
            }
            $_ = $';       # Put $_ equal to the unmatched tail of string '
            my $include_candidate = $1;
            $include_candidate =~ s/\s*$//;   # Remove trailing space.
            if ( $include_candidate eq "[]" ) {
                # Part of overfull hbox message
                next INCLUDE_CANDIDATE;
            }
            if ( $include_candidate =~ /^\\/ ) {
                # Part of font message
                next INCLUDE_CANDIDATE;
            }
            # Make list of new include files; sometimes more than one.
            my @new_includes = ($include_candidate);
            if ( $include_candidate =~ /^(.+)\[([^\]]+)\]$/ ) {
                # Construct of form 'file1[file2]', as produced by pdflatex
                if ( -e $1 ) {
                    # If the first component exists, we probably have the
                    #   pdflatex form
                    @new_includes = ($1, $2);
	        }
                else {
                    # We have something else.
                    # So leave the original candidate in the list
	        }
	    }
	INCLUDE_NAME:
            foreach my $include_name (@new_includes) {
	        my ($base, $path, $ext) = fileparseB( $include_name );
                if ( ($path eq './') || ($path eq '.\\') ) {
                    $include_name = $base.$ext;
		}
                if ( $include_name !~ m'[/|\\]' ) {
                    # Filename does not include a path character
                    # High potential for misparsed line
		    $dependents{$include_name} = 2;
		} else {
		    $dependents{$include_name} = 3;
		}
		if ( $ext eq '.bbl' ) {
  		    warn "$My_name: Input bbl file '$include_name'\n"
		       unless $silent;
  		    push @bbl_files, $include_name;
		}
	    } # INCLUDE_NAME
        } # INCLUDE_CANDIDATE
    } # LINE
    close($log_file);

    # Default includes are always definitive:
    foreach (@default_includes) { $dependents{$_} = 4; }

    ###print "New parse: \n";
    ###foreach (sort keys %dependents) { print "  '$_': $dependents{$_}\n"; }

    my @misparsed = ();
    my @missing = ();
    my @not_found = ();
CANDIDATE:
    foreach my $candidate (keys %dependents) {
        my $code = $dependents{$candidate};
        if ( -e $candidate ) {
	    $dependents{$candidate} = 4;
	}
	elsif ($code == 1) {
            # Graphics file that is supposed to have been read.
            # Candidate name is as given in source file, not as path
            #   to actual file.
            # We have already tested that file doesn't exist, as given.
            #   so use kpsewhich.  
            # If the file still is not found, assume non-existent;
            my @kpse_result = kpsewhich( $candidate );
            if ($#kpse_result > -1) {
                $dependents{$kpse_result[0]} = 4;
		delete $dependents{$candidate};
		next CANDIDATE;
	    }
	    else {
		push @not_found, $candidate;
	    }
	}
        elsif ($code == 2) {
            # Candidate is from '(...' construct in log file, for input file
            #    which should include pathname if valid input file.
            # Name does not have pathname-characteristic character (hence
            #    $code==2.
            # Candidate file does not exist with given name
            # Almost surely result of a misparsed line in log file.
	    delete $dependents{$candidate};
            push @misparse, $candidate;
	}
	elsif ($code == 0) {
            my ($base, $path, $ext) = fileparseA($candidate);
            $ext =~ s/^\.//;
            if ( ($ext eq '') && (-e "$path$base.tex") ) {
                $dependents{"$path$base.tex"} = 4;
		delete $dependents{$candidate};
	    }
	    push @missing, $candidate;
	}
    }

    
    if ( $diagnostics ) {
        @misparse = uniqs( @misparse );
        @missing = uniqs( @missing );
        @not_found = uniqs( @not_found );
        my @dependents = sort( keys %dependents );

        my $dependents = $#dependents + 1;
        my $misparse = $#misparse + 1;
        my $missing = $#missing + 1;
        my $not_found = $#not_found + 1;
        my $exist = $dependents - $not_found - $missing;
        my $bbl = $#bbl_files + 1;

        print "$dependents dependent files detected, of which ",
              "$exist exist, $not_found were not found,\n",
	      "   and $missing appear not to exist.\n";
        print "Dependents:\n";
        foreach (@dependents) { print "   $_\n"; }
        if ($not_found > 0) {
	    print "Not found:\n";
	    foreach (@not_found) { print "   $_\n"; }
	}
        if ($missing > 0) {
	    print "Not existent:\n";
	    foreach (@missing) { print "   $_\n"; }
	}
        if ( $bbl > 0 ) {
            print "Input bbl files:\n";
            foreach (@bbl_files) { print "   $_\n"; }
        }

        if ( $misparse > 0 ) {
	    print "$misparse\n";
            print "Apparent input files appearently from misunderstood lines in .log file:\n";
            foreach ( @misparse ) { print "   $_\n"; }
        }
    }

    return 1;
} #END parse_logB

#************************************************************

sub parse_aux {
    #Usage: parse_aux( $aux_file, \@new_bib_files, \@new_aux_files )
    # Parse aux_file (recursively) for bib files.  
    # If can't open aux file, then
    #    Return 0 and leave @new_bib_files empty
    # Else set @new_bib_files from information in the aux files
    #    And:
    #    Return 1 if no problems
    #    Return 2 with @new_bib_files empty if there are no \bibdata
    #      lines. 
    #    Return 3 if I couldn't locate all the bib_files
    # Set @new_aux_files to aux files parsed

    my $aux_file = $_[0];
    local $Pbib_files = $_[1];
    local $Paux_files = $_[2];
   
    @$Pbib_files = ();
    @$Paux_files = ();

    parse_aux1( $aux_file );
    if ($#{$Paux_files} < 0) {
       return 0;
    }
    @$Pbib_files = uniqs( @$Pbib_files );

    if ( $#{$Pbib_files} == -1 ) {
        warn "$My_name: No .bib files listed in .aux file '$aux_file' \n",
        return 2;
    }
    my $bibret = &find_file_list1( $Pbib_files, $Pbib_files,
                                  '.bib', \@BIBINPUTS );
    @$Pbib_files = uniqs( @$Pbib_files );
    if ($bibret == 0) {
        warn "$My_name: Found bibliography file(s) [@$Pbib_files]\n" 
        unless $silent;
    }
    else {
        warn "$My_name: Failed to find one or more bibliography files ",
             "in [@$Pbib_files]\n";
        if ($force_mode) {
            warn "==== Force_mode is on, so I will continue.  ",
                 "But there may be problems ===\n";
        }
        else {
            #$failure = -1;
            #$failure_msg = 'Failed to find one or more bib files';
            #warn "$My_name: Failed to find one or more bib files\n";
        }
        return 3;
    }
    return 1;
} #END parse_aux

#************************************************************

sub parse_aux1
# Parse single aux file for bib files.  
# Usage: &parse_aux1( aux_file_name )
#   Append newly found bib_filenames in @$Pbib_files, already 
#        initialized/in use.
#   Append aux_file_name to @$Paux_files if aux file opened
#   Recursively check \@input aux files
#   Return 1 if success in opening $aux_file_name and parsing it
#   Return 0 if fail to open it
{
   my $aux_file = $_[0];
   my $aux_fh = new FileHandle;
   if (! open($aux_fh, $aux_file) ) { 
       warn "$My_name: Couldn't find aux file '$aux_file'\n";
       return 0; 
   }
   push @$Paux_files, $aux_file;
AUX_LINE:
   while (<$aux_fh>) {
      if ( /^\\bibdata\{(.*)\}/ ) { 
          # \\bibdata{comma_separated_list_of_bib_file_names}
          # (Without the '.bib' extension)
          push( @$Pbib_files, split /,/, $1 ); 
      }
      elsif ( /^\\\@input\{(.*)\}/ ) { 
          # \\@input{next_aux_file_name}
	  &parse_aux1( $1 );
      }
   }
   close($aux_fh);
   return 1;
} #END parse_aux1

#************************************************************

#************************************************************
#************************************************************
#************************************************************

#   Manipulations of main file database:

#************************************************************

sub fdb_get {
    # Call: fdb_get(filename)
    # Returns an array (time, size, md5) for the current state of the
    #    named file.
    # For non-existent file, deletes entry in fdb_current, and returns (0,-1,0) 
    my $file = shift;
    my ($new_time, $new_size) = get_time_size($file);
    my @nofile =  (0,-1,0);     # What we use for initializing
				# a new entry in fdb or flagging
				# non-existent file
    if ( $new_size < 0 ) {
        delete $fdb_current{$file};
        return @nofile;
    }
    my $recalculate_md5 = 0;
    if ( ! exists $fdb_current{$file} ) {
        # Ensure we have a record.  
        $fdb_current{$file} = [@nofile];
        $recalculate_md5 = 1;
    }
    my $file_data = $fdb_current{$file};
    my ( $time, $size, $md5 ) = @$file_data;
    if ( ($new_time != $time) || ($new_size != $size) ) {
        # Only force recalculation of md5 if time or size changed
        # Else we assume file is really unchanged.
        $recalculate_md5 = 1;
    }
    if ($recalculate_md5) {
        @$file_data = ( $new_time, $new_size, get_checksum_md5( $file ) );
    }
    return @$file_data;;
} #END fdb_get

#************************************************************

sub fdb_show {
    # Displays contents of fdb
    foreach my $file ( sort keys %fdb_current ) {
        print "'$file': @{$fdb_current{$file}}\n";
    }
} #END fdb_show

#************************************************************
#************************************************************
#************************************************************

# Routines for manipulating rule database

#************************************************************

sub rdb_read {
    # Call: rdb_read( $in_name  )
    # Sets rule database from saved file, in format written by rdb_write.
    # Returns -1 if file could not be read else number of errors.
    # Thus return value on success is 0
    my $in_name = $_[0];

    my $in_handle = new FileHandle;
    $in_handle->open( $in_name, '<' )
       or return ();
    my $errors = 0;
    my $state = 0;   # Outside a section 
    my $rule = '';
    my $run_time = 0;
    my $source = '';
    my $dest = '';
    my $base = '';
    local %new_sources = ();  # Hash: rule => { file=>[ time, size, md5, fromrule ] }
    my $new_source = undef;   # Reference to hash of sources for current rule
LINE:
    while ( <$in_handle> ) {
        # Remove leading and trailing white space.
        s/^\s*//;
        s/\s*$//;
        # Ignore blank lines and comments
        if ( /^$/ || /^#/ || /^%/ ) { next LINE;}
        if ( /^\[\"([^\"]+)\"\]/ ) {
            # Start of section
	    $rule = $1;
#??             print "--- Starting rule '$rule'\n";
            my $tail = $'; #'  Single quote in comment tricks the parser in
                           # emacs from misparsing an isolated single quote
            $run_time = 0;
            $source = $dest = $base = '';
            if ( $tail =~ /^\s*(\S+)\s*$/ ) {
                $run_time = $1;
	    }
            elsif ( $tail =~ /^\s*(\S+)\s+\"([^\"]*)\"\s+\"([^\"]*)\"\s+\"([^\"]*)\"\s*$/ ) {
                $run_time = $1;
                $source = $2;
                $dest = $3;
                $base = $4;
	    }
            if ( rdb_rule_exists( $rule ) ) {
                rdb_one_rule( $rule, 
                              sub{ $$Ptest_kind = 1; 
                                   $$Prun_time = $run_time;
                                   #??if ($source) { $$Psource = $source; }
                                   #??if ($dest) { $$Pdest = $dest; }
                                   #??if ($base) { $$Pbase = $base; }
                                 }                                      
                             );
	    }
            elsif ($rule =~ /^cusdep\s+(\S+)\s+(\S+)\s+(.+)$/ ) {
                # Create custom dependency
                my $fromext = $1;
                my $toext = $2;
                my $base = $3;
                $source = "$base.$fromext";
                $dest =   "$base.$toext";
                my $PAnew_cmd = ['do_cusdep', ''];
                foreach my $dep ( @cus_dep_list ) {
                    my ($tryfromext,$trytoext,$must,$func_name) = split(' ',$dep);
                    if ( ($tryfromext eq $fromext) && ($trytoext eq $toext) ) {
                       $$PAnew_cmd[1] = $func_name;
                    }
                }
                rdb_create_rule( $rule, 'cusdep', '', $PAnew_cmd, 1, 
                                 $source, $dest, $base, 0, $run_time );
	    }
            elsif ( $rule =~ /^(makeindex|bibtex)\s*(.*)$/ ) {
                my $rule_generic = $1;
                if ( ! $source ) {
                    # If fdb_file was old-style (v. 1)
                    $source = $2;
                    my $path = '';
                    my $ext = '';
                    ($base, $path, $ext) = fileparseA( $source );
                    $base = $path.$base;
                    if ($rule_generic eq 'makeindex') {
                        $dest = "$base.ind";
		    }
                    elsif ($rule_generic eq 'bibtex') {
                        $dest = "$base.bbl";
                        $source = "$base.aux";
		    }
	        }
  	        warn "$My_name: File-database '$in_name': setting rule '$rule'\n"
                   if $diagnostics;
                my $cmd_type = 'external';
                my $ext_cmd = ${$rule_generic};
		warn "  Rule kind = '$rule_generic'; ext_cmd = '$ext_cmd';\n",
		     "  source = '$source'; dest = '$dest'; base = '$base';\n"
                   if $diagnostics;
                rdb_create_rule( $rule, $cmd_type, $ext_cmd, '', 1, 
                                 $source, $dest, $base, 0, $run_time);
	    }
            else {
  	        warn "$My_name: In file-database '$in_name' rule '$rule'\n",
                     "   is not in use in this session\n"
                if $diagnostics;
 	        $new_source = undef;
	        $state = 3;
	        next LINE;
	    }
            $new_source = $new_sources{$rule} = {};
	    $state = 1;  #Reading a section
	}
	elsif ( /^\"([^\"]*)\"\s+(\S+)\s+(\S+)\s+(\S+)\s+\"([^\"]*)\"/ ) {
            # Source file line
            if ($state == 3) {
                # The rule is not being currently used.
                next LINE;
            }
	    my $file = $1;
	    my $time = $2;
	    my $size = $3;
	    my $md5 = $4;
            my $from_rule = $5;
#??            print "  --- File '$file'\n";
            if ($state != 1) {
                warn "$My_name: In file-database '$in_name' ",
  		     "line $. is outside a section:\n   '$_'\n";
		$errors++;
		next LINE;
	    }
	    rdb_ensure_file( $rule, $file );
            rdb_set_file1( $rule, $file, $time, $size, $md5 );
            # Save the rest of the data, especially the from_fule until we know all 
            #   the rules, otherwise the from_rule may not exist.
            # Also we'll have a better chance of looping through files.
	    ${$new_source}{$file} = [ $time, $size, $md5, $from_rule ];
	}
	elsif ($state == 0) {
            # Outside a section.  Nothing to do.
	}
	else {
	    warn "$My_name: In file-database '$in_name' ",
                 "line $. is of wrong format:\n   '$_'\n";
	    $errors++;
	    next LINE;
	}
    }
    undef $in_handle;
    # Set cus dependencies.
    &rdb_set_dependentsA( keys %rule_db );

#?? Check from_rules exist.

    return $errors;
}  # END rdb_read

#************************************************************

sub rdb_read_generatedB {
    # Call: rdb_read_generatedB( $in_name, \@extra_generated, \@aux_files )
    # From rule database in saved file, in format written by rdb_write,
    # finds the non-basic generated files that are to be deleted by a cleanup. 
    # Returns an array of these files, or an empty array if the file 
    # does not exist or cannot be opened.
    my ($in_name, $Pgenerated, $Paux_files) = @_;
    @$Pgenerated = ();
    @$Paux_files = ();

    my $in_handle = new FileHandle;
    $in_handle->open( $in_name, '<' )
       or return ();
    my $rule = '';
    my $run_time = 0;
    my $source = '';
    my $dest = '';
    my $base = '';
    my $ext = '';
    my $path = '';
    my $state = 0;   # Outside a section 
LINE:
    while ( <$in_handle> ) {
        # Remove leading and trailing white space.
        s/^\s*//;
        s/\s*$//;
        # Ignore blank lines and comments
        if ( /^$/ || /^#/ || /^%/ ) { next LINE;}
        if ( /^\[\"([^\"]+)\"\]/ ) {
            # Start of section
	    $rule = $1;
            my $tail = $'; #'  Single quote in comment tricks the parser in
                           # emacs from misparsing an isolated single quote
            $run_time = 0;
            $source = $dest = $base = '';
            if ( $tail =~ /^\s*(\S+)\s+\"([^\"]*)\"\s+\"([^\"]*)\"\s+\"([^\"]*)\"\s*$/ ) {
                $source = $2;
                $dest = $3;
                $base = $4;
	    }
            else { next LINE; }
            if ( $rule =~ /^makeindex/ ) {
                push @$Pgenerated, $source, $dest, "$base.ilg";
	    }
            elsif ( $rule =~ /^bibtex/ ) {
                push @$Pgenerated, $dest, "$base.blg";
                push @$Paux_files, $source;
	    }
	    $state = 1;  #Reading a section
	}
	elsif ( /^\"([^\"]*)\"\s+(\S+)\s+(\S+)\s+(\S+)\s+\"([^\"]*)\"/ ) {
            # Source file line
            if ($state == 3) {
                # The rule is not being currently used.
                next LINE;
            }
	    my $file = $1;
            ($base, $path, $ext) = fileparseA( $file );
            if ( $ext eq '.aux' ) { push @$Paux_files, $file; }
	}
	elsif ($state == 0) {
            # Outside a section.  Nothing to do.
	}
	else {
	    warn "$My_name: In file-database '$in_name' ",
                 "line $. is of wrong format:\n   '$_'\n";
	    next LINE;
	}
    } # LINE
    undef $in_handle;

}  # END rdb_read_generatedB

#************************************************************

sub rdb_write {
    # Call: rdb_write( $out_name )
    # Writes to the given file name the database of file and rule data
    #   accessible from the primary rules.
    # Returns 1 on success, 0 if file couldn't be opened.
    local $out_name = $_[0];
    local $out_handle = new FileHandle;
    if ( ($out_name eq "") || ($out_name eq "-") ) {
        # Open STDOUT
        $out_handle->open( '>-' );
    }
    else {
       $out_handle->open( $out_name, '>' );
    }
    if (!$out_handle) { return 0; }

    local %current_primaries = ();   # Hash whose keys are primary rules 
                # needed, i.e., known latex-like rules which trigger
                # circular dependencies
    local @pre_primary = ();   # Array of rules
    local @post_primary = ();  # Array of rules
    local @one_time = ();      # Array of rules
    &rdb_classify_rules( \%possible_primaries, keys %requested_filerules );

    print $out_handle "# Fdb version $fdb_ver\n";
    my @rules = sort( 
                  rdb_accessible( 
                     uniq1( keys %known_rules, keys %current_primaries )));
    rdb_for_some(
       \@rules,
       sub { print $out_handle "[\"$rule\"] $$Prun_time \"$$Psource\" \"$$Pdest\" \"$$Pbase\" \n"; },
       sub { print $out_handle "  \"$file\" $$Ptime $$Psize $$Pmd5 \"$$Pfrom_rule\"\n"; },
    );
    undef $out_handle;
    return 1;
} #END rdb_write

#************************************************************

sub rdb_set_from_logB {
    # Assume rule context.  
    # This is intended to be applied only for a primary (LaTeX-like) rule
    # Starting from the log_file, set current details for the current rule.

    # Rules should only be primary
    if ( $$Pcmd_type ne 'primary' ) {
	warn "\n$My_name: ==========$My_name: Probable BUG======= \n   ",
             "   rdb_set_from_logB called to set files ",
             "for non-primary rule '$rule'\n\n";
        return;
    }


#??    # We'll prune this by all files determined to be needed for source files.
#??    my %unneeded_source = %$PHsource;

    # Parse log file to find relevant filenames
    # Result in the following variables:
    local %dependents = ();   # Maps files to status
    local @bbl_files = ();
    local %idx_files = ();    # Maps idx_file to (ind_file, base)

    # The following are also returned, but are global, to be used by caller
    # $reference_changed, $bad_reference $bad_citation

    &parse_logB;

  IDX_FILE:
    foreach my $idx_file ( keys %idx_files ) {
	my ($ind_file, $ind_base) = @{$idx_files{$idx_file}};
        my $from_rule = "makeindex $idx_file";
        if ( ! rdb_rule_exists( $from_rule ) ){
            print "!!!===Creating rule '$from_rule': '$ind_file' from '$idx_file'\n"
                  if ($diagnostics);
            rdb_create_rule( $from_rule, 'external', $makeindex, '', 1, 
                             $idx_file, $ind_file, $ind_base, 1, 0);
            foreach my $primary ( keys %primaries ) {
                print "  ===Source file '$ind_file' for '$primary'\n"
                  if ($diagnostics > -1);
                rdb_ensure_file( $primary, $ind_file, $from_rule );
	    }
	}
        if ( ! -e $ind_file ) { 
            # Failure was non-existence of makable file
            # Leave failure issue to other rules.
	    $failure = 0;
	}
    }

  BBL_FILE:
    foreach my $bbl_file ( uniqs( @bbl_files ) ) {
	my ($bbl_base, $bbl_path, $bbl_ext) = fileparseA( $bbl_file );
        $bbl_base = $bbl_path.$bbl_base;
        my @new_bib_files;
        my @new_aux_files;
        &parse_aux( "$bbl_base.aux", \@new_bib_files, \@new_aux_files );
        my $from_rule = "bibtex $bbl_base";
        if ( ! rdb_rule_exists( $from_rule ) ){
            print "!!!===Creating rule '$from_rule'\n"
              if ($diagnostics);
            rdb_create_rule( $from_rule, 'external', $bibtex, '', 1, 
                             "$bbl_base.aux", $bbl_file, $bbl_base, 1, 0);
            foreach my $source ( @new_bib_files, @new_aux_files ) {
                print "  ===Source file '$source'\n"
                  if ($diagnostics);
                rdb_ensure_file( $from_rule, $source );
	    }
            foreach my $primary ( keys %primaries ) {
                print "  ===Source file '$bbl_file' for '$primary'\n"
                  if ($diagnostics);
                rdb_ensure_file( $primary, $bbl_file, $from_rule );
                if ( ! -e $bbl_file ) { 
                    # Failure was non-existence of makable file
                    # Leave failure issue to other rules.
		    $failure = 0;
		}
	    }
	}
    }

NEW_SOURCE:
    foreach my $new_source (keys %dependents) {
	foreach my $primary ( keys %primaries ) {
            rdb_ensure_file( $primary, $new_source );
	}
    }

    my @more_sources = &rdb_set_dependentsA( $rule );
    my $num_new = $#more_sources + 1;
    foreach (@more_sources) { 
	$dependents{$_} = 4;
        if ( ! -e $_ ) { 
            # Failure was non-existence of makable file
            # Leave failure issue to other rules.
            $failure = 0; 
            $$Pchanged = 1; # New files can be made.  Ignore error.
        }
    }
    if ($diagnostics) {
	if ($num_new > 0 ) {
	    print "$num_new new source files for rule '$rule':\n";
	    foreach (@more_sources) { print "   '$_'\n"; }
	}
	else {
	    print "No new source files for rule '$rule':\n";
	}
    }

    my @files_not_needed = ();
    foreach (keys %$PHsource) { 
        if ( ! exists $dependents{$_} ) {
            print "Removing no-longer-needed dependent '$_' from rule '$rule'\n"
              if $diagnostics>-1;
            push @files_not_needed, $_;
	}
    }
    rdb_remove_files( $rule, @files_not_needed );

} # END rdb_set_from_logB

#************************************************************

sub rdb_find_new_filesB {
    # Call: rdb_find_new_filesB
    # Assumes rule context for primary rule.
    # Deal with files which were missing and for which a method
    # of finding them has become available:
    #   (a) A newly available source file for a custom dependency.
    #   (b) When there was no extension, a file with appropriate
    #       extension
    #   (c) When there was no extension, and a newly available source 
    #       file for a custom dependency can make it.

    my %new_includes = ();

MISSING_FILE:
    foreach my $missing ( keys %$PHsource ) {
        next if ( $$PHsource{$missing} != 0 ); 
        my ($base, $path, $ext) = fileparseA( $missing );
        $ext =~ s/^\.//;
        if ( -e "$missing.tex" ) { 
            $new_includes{"$missing.tex"} = 1;
        }
        if ( -e $missing ) { 
	    $new_includes{$missing} = 1;
        }
        if ( $ext ne "" ) {
            foreach my $dep (@cus_dep_list){
               my ($fromext,$toext) = split(' ',$dep);
               if ( ( "$ext" eq "$toext" )
                    && ( -e "$path$base.$fromext" )
	 	  )  {
                  # Source file for the missing file exists
                  # So we have a real include file, and it will be made
                  # next time by rdb_set_dependents
                  $new_includes{$missing} = 1;
               }
	       else {
                   # no point testing the $toext if the file doesn't exist.
	       }
               next MISSING_FILE;
	    }
       }
       else {
           # $_ doesn't exist, $_.tex doesn't exist,
           # and $_ doesn't have an extension
           foreach my $dep (@cus_dep_list){
              my ($fromext,$toext) = split(' ',$dep);
              if ( -e "$path$base.$fromext" ) {
                  # Source file for the missing file exists
                  # So we have a real include file, and it will be made
                  # next time by &rdb__dependents
                  $new_includes{"$path$base.$toext"} = 1;
#                  next MISSING_FILE;
              }
              if ( -e "$path$base.$toext" ) {
                  # We've found the extension for the missing file,
                  # and the file exists
                  $new_includes{"$path$base.$toext"} = 1;
#                  next MISSING_FILE;
              }
	   }
       }
    } # end MISSING_FILES

    # Sometimes bad line-breaks in log file (etc) create the
    # impression of a missing file e.g., ./file, but with an incorrect
    # extension.  The above tests find the file with an extension,
    # e.g., ./file.tex, but it is already in the list.  So now I will
    # remove files in the new_include list that are already in the
    # include list.  Also handle aliasing of file.tex and ./file.tex.
    # For example, I once found:
# (./qcdbook.aux (./to-do.aux) (./ideas.aux) (./intro.aux) (./why.aux) (./basics
#.aux) (./classics.aux)

    my $found = 0;
    foreach my $file (keys %new_includes) {
        my $stripped = $file;
        $stripped =~ s{^\./}{};
        if ( exists $PHsource{$file} ) {
	    delete $new_includes{$file};
	}
        else {
	    $found ++;
	    rdb_ensure_file( $rule, $file );
	}
    }

## ?? Is this correct?  I used to use @includes
#    rdb_update_files_for_rule( keys %PHsources );
    if ( $diagnostics && ( $found > 0 ) ) {
	warn "$My_name: Detected previously missing files:\n";
        foreach ( sort keys %new_includes ) {
            warn "   '$_'\n";
	}
    }
    return $found;
} # END rdb_find_new_filesB

#************************************************************

sub rdb_update_files_for_rule {
#=========== APPEARS NOT TO BE USED! =========================
# Usage: rdb_update_files_for_rule( source_files ...)
# Assume rule context.  
# Update list of source files for current rule, treating properly cases
# where file didn't exist before run, etc
    foreach my $file ( @_ ) {
        if ( ! rdb_file_exists( $rule, $file ) ) {
            # File that didn't appear in the source files for the run 
            #    before.  Two cases: (a) it was created during the run;
            #    (b) it existed before the run.  
            # If case (a), then the file was non-existent before the 
            #    run, so we must now label it as non-existent, and
            # we trigger a new run
#??            print "?? Adding '$file' to '$rule'\n";
            rdb_ensure_file( $rule, $file );
            my $file_time = get_mtime0( $file );
            if ( ($$Ptest_kind == 2) || ($$Ptest_kind == 3) ) {
                # Test wrt destination time, but exclude files
                # which appear to be generated (according to extension)
                # Assume generated files up-to-date after last run.
                # I.e., last run was valid.
                my $ext = ext( $file );

                if ( (! exists $generated_exts_all{$ext} )
                     && ($file_time >= $dest_mtime) 
                   ) {
                    # Only changes since the mtime of the destination matter,
                    #   and only non-generated files count.
                    # Non-existent destination etc gives $dest_mtime=0
                    # so this will automatically give out-of-date condition
                    # Flag out-of-date for a file by treating it as non-existent
		    rdb_set_file1( $rule, $file, 0, -1, 0);
		}
	    }
            elsif ($file_time >= $$Prun_time ) {
                # File generated during run.  So treat as non-existent at beginning
                rdb_set_file1( $rule, $file, 0, -1, 0);
                $$Pout_of_date = 1;
	    }
            # Else default of current state of file is correct.
	} # END not previously existent file
    } # END file
} # END rdb_update_files_for_rule

#************************************************************

sub rdb_set_dependentsA {
    # Call rdb_set_dependentsA( rules ...)
    # Returns array (sorted), of new source files.
    local @new_sources = ();
    rdb_recurseA( [@_],  0, \&rdb_one_depA );
    &rdb_make_links;
    return uniqs( @new_sources );
} #END rdb_set_dependentsA

#************************************************************

sub rdb_one_depA {
    # Helper for finding dependencies.  One case, $rule and $file given
    # Assume file (and rule) context for DESTINATION file.
    local $new_dest = $file;
    my ($base_name, $path, $toext) = fileparseA( $new_dest );
    $base_name = $path.$base_name;
    $toext =~ s/^\.//;
DEP:
    foreach my $dep ( @cus_dep_list ) {
        my ($fromext,$proptoext,$must,$func_name) = split(' ',$dep);
        if ( $toext eq $proptoext ) {
            my $source = "$base_name.$fromext";
	    # Found match of rule
            if ($diagnostics) {
                print "Found cusdep:  $source to make $rule:$new_dest ====\n";
            }
	    if ( -e $source ) {
	        $$Pfrom_rule = "cusdep $fromext $toext $base_name";
#??		print "?? Ensuring rule for '$$Pfrom_rule'\n";
                local @PAnew_cmd = ( 'do_cusdep', $func_name );
                if ( !-e $new_dest ) {
		    push @new_sources, $new_dest;
		}
                if (! rdb_rule_exists( $$Pfrom_rule ) ) {
                    rdb_create_rule( $$Pfrom_rule, 'cusdep', '', \@PAnew_cmd, 3, 
                                     $source, $new_dest, $base_name, 0 );
		}
                else {
		    rdb_one_rule( 
                       $$Pfrom_rule, 
                       sub{ @$PAint_cmd = @PAnew_cmd; $$Pdest = $new_dest;}
                    );
		}
		return;
	    }
            else {
                # Source file does not exist
                if ( !$force_mode && ( $must != 0 ) ) {
                    # But it is required that the source exist ($must !=0)
                    $failure = 1;
                    $failure_msg = "File '$base_name.$fromext' does not exist ".
                                   "to build '$base_name.$toext'";
                    return;
		}
                elsif ( $$Pfrom_rule =~ /^cusdep $fromext $toext / )  {
                    # Source file does not exist, destination has the rule set.
                    # So turn the from_rule off
		    $$Pfrom_rule = '';
		}
		else {
		}
	    }
	}
        elsif ( ($toext eq '') && (! -e $file ) ) {
            # Empty extension and non-existent destination
            #   This normally results from  \includegraphics{A}
            #    without graphics extension for file, when file does
            #    not exist.  So we will try to find something to make it.
            my $source = "$base_name.$fromext";
            if ( -e $source ) {
                $new_dest = "$base_name.$proptoext";
	        my $from_rule = "cusdep $fromext $toext $base_name";
                push @new_sources, $new_dest;
		print "Ensuring rule for '$from_rule', to make '$new_dest'\n"
		    if $diagnostics > -1;
                local @PAnew_cmd = ( 'do_cusdep', $func_name );
                if (! rdb_rule_exists( $from_rule ) ) {
                    rdb_create_rule( $from_rule, 'cusdep', '', \@PAnew_cmd, 3, 
                                     $source, $new_dest, $base_name, 0);
		}
                else {
		    rdb_one_rule( 
                       $$Pfrom_rule, 
                       sub{ @$PAint_cmd = @PAnew_cmd; $$Pdest = $new_dest;}
                    );
		}
                rdb_ensure_file( $rule, $new_dest, $from_rule );
		return;
	    }
        } # End of Rule found
    } # End DEP
} #END rdb_one_depA

#************************************************************

sub rdb_list {
    # Call: rdb_list()
    # List rules and their source files
    print "===Rules:\n";
    local $count_rules = 0;
    my @accessible_all = rdb_accessible( keys %requested_filerules ); 
    rdb_for_some( 
        \@accessible_all,
	sub{ $count_rules++; 
             print "Rule '$rule' depends on:\n"; 
           },
	sub{ print "    '$file'\n"; }
    );
    if ($count_rules <= 0) {
	print "   ---No rules defined\n";
    }
} #END rdb_list

#************************************************************

sub rdb_show {
    # Call: rdb_show()
    # Displays contents of rule data base.
    # Side effect: Exercises access routines!
    print "===Rules:\n";
    local $count_rules = 0;
    rdb_for_all( 
	sub{ $count_rules++; 
             print "  [$rule]: '$$Pcmd_type' '$$Pext_cmd' '@$PAint_cmd' $$Ptest_kind ",
                   "'$$Psource' '$$Pdest' '$$Pbase' $$Pout_of_date $$Pout_of_date_user\n"; },
	sub{ print "    '$file': $$Ptime $$Psize $$Pmd5 '$$Pfrom_rule'\n"; }
    );
    if ($count_rules <= 0) {
	print "   ---No rules defined\n";
    }
} #END rdb_show

#************************************************************

sub rdb_accessible {
    # Call: rdb_accessible( rule, ...)
    # Returns array of rules accessible from the given rules
    local @accessible = ();
    rdb_recurseA( [@_], sub{ push @accessible, $rule; } );
    return @accessible;
} #END rdb_accessible

#************************************************************

sub rdb_possible_primaries {
    # Returns array of possible primaries
    my @rules = ();
    foreach my $rule ( keys %known_rules ) {
        if ( $known_rules{$rule} eq 'primary') {
	    push @rules, $rule;
	}
    }
    return @rules;
} #END rdb_possible_primaries

#************************************************************
#************************************************************
#************************************************************

# Routines for makes.  NEW VERSIONS ??

#????????Debugging routines:
sub R1 {print "===START $rule\n"}
sub R2 {print "===END $rule\n"}
sub F1 {print "   ---START $file\n"}
sub F2 {print "   ---END $file\n"}
#************************************************************

sub rdb_makeB {
    # Call: rdb_makeB( target, ... )
    # Makes the targets and prerequisites.  
    # Leaves one-time rules to last.
    # Does appropriate repeated makes to resolve dependency loops

    # Returns 0 on success, nonzero on failure.

    # General method: Find all accessible rules, then repeatedly make
    # them until all accessible rules are up-to-date and the source
    # files are unchanged between runs.  On termination, all
    # accessible rules have stable source files.
    #
    # One-time rules are view and print rules that should not be
    # repeated in an algorithm that repeats rules until the source
    # files are stable.  It is the calling routine's responsibility to
    # arrange to call them, or to use them here with caution.
    #
    # Note that an update-viewer rule need not be considered
    # one-time.  It can be legitimately applied everytime the viewed
    # file changes.
    #
    # Note also that the criterion of stability is to be applied to
    # source files, not to output files.  Repeated application of a
    # rule to IDENTICALLY CONSTANT source files may produce different
    # output files.  This may be for a trivial reason (e.g., the
    # output file contains a time stamp, as in the header comments for
    # a typical postscript file), or for a non-trivial reason (e.g., a
    # stochastic algorithm, as in abcm2ps).   
    #
    # This caused me some actual trouble.  In general, circular
    # dependencies produce non-termination, and the the following
    # situation is an example of a generic situation where certain
    # rules must be obeyed in order to obtain proper results:
    #    1.  A/the latex source file contains specifications for
    #        certain postprocessing operations.  Standard (pdf)latex 
    #        already has this, for indexing and bibliography.
    #    2.  In the case in point that caused me trouble, the
    #        specification was for musical tunes that were contained
    #        in external source files not directly input to
    #        (pdf)latex.  But in the original version, there was a
    #        style file (abc.sty) that caused latex itself to call
    #        abcm2ps to make .eps files for each tune that were to be
    #        read in on the next run of latex. 
    #    3.  Thus the specification can cause a non-terminating loop
    #        for latexmk, because the output files of abcm2ps changed
    #        even with identical input.  
    #    4.  The solution was to 
    #        a. Use a style file abc_get.sty that simply wrote the
    #           specification on the tunes to the .aux file in a
    #           completely deterministic fashion.
    #        b. Instead of latex, use a script abclatex.pl that runs
    #           latex and then extracts the abc contents for each tune
    #           from the source abc file.  This is also
    #           deterministic. 
    #        c. Use a cusdep rule in latexmk to convert the tune abc
    #           files to eps.  This is non-deterministic, but only
    #           gets called when the (deterministic) source file
    #           changes.
    #        This solves the problem.  Latexmk works.  Also, it is no
    #        longer necessary to enable write18 in latex, and multiple
    #        unnecessary runs of abcm2ps are no longer used. 
    #
    # The order of testing and applying rules is chosen by the
    # following heuristics: 
    #    1.  Both latex and pdflatex may be used, but the resulting
    #        aux files etc may not be completely identical.  Define
    #        latex and pdflatex as primary rules.  Apply the general
    #        method of repeated circulating through all rules until
    #        the source files are stable for each primary rule
    #        separately.  Naturally the rules are all accessible
    #        rules, but excluding primary rules except for the current
    #        primary.
    #    2.  Assume that the primary rules are relatively
    #        time-consuming, so that unnecessary passes through them
    #        to check stability of the source files should be avoided.
    #    3.  Assume that although circular dependencies exist, the
    #        rules can nevertheless be thought of as basically
    #        non-circular, and that many rules are strictly or
    #        normally non-circular.  In particular cusdep rules are
    #        typically non-circular (e.g., fig2eps), as are normal
    #        output processing rules like dvi2ps.  
    #    4.  The order for the non-circular approximation is
    #        determined by applying the assumption that an output file
    #        from one rule that is read in for an earlier stage is
    #        unchanged. 
    #    HOWEVER, at a first attempt, the ordering is not needed.  It
    #    only gives an optimization
    #    5.  (Note that these assumptions could be violated, e.g., if
    #        $dvips is arranged not only to do the basic dvips
    #        command, but also to extract information from the ps file
    #        and feed it back to an input file for (pdf)latex.)
    #    6.  Nevertheless, the overall algorithm should allow
    #        circularities.  Then the general criterion of stability
    #        of source files covers the general case, and also
    #        robustly handles the case that the USER changes source
    #        files during a run.  This is particularly important in
    #        -pvc mode, given that a full make on a large document can
    #        be quite lengthy in time, and moreover that a user
    #        naturally wishes to make corrections in response to
    #        errors, particularly latex errors, and have them apply
    #        right away.
    # This leads to the following approach:
    #    1.  Classify accessible rules as: primary, pre-primary
    #        (typically cusdep, bibtex, makeindex, etc), post-primary
    #        (typically dvips, etc), and one-time
    #    2.  Then stratify the rules into an order of application that
    #        corresponds to the basic feedforward structure, with the
    #        exclusion of one-time rules.
    #    3.  Always require that one-time rules are among the
    #        explicitly requested rules, i.e., the last to be applied,
    #        were we to apply them.  Anything else would not match the
    #        idea of a one-time rule.  
    #    4.  Then work as follows:
    #        a. Loop over primaries
    #        b. For each primary, examine each pre-primary rule and
    #           apply if needed, then the primary rule and then each
    #           post-primary rule.  The ordering of the pre-primary
    #           and post-primary rules was found in step 2.
    #      BUT applying the ordering is not essential
    #        c. Any time that a pre-primary or primary rule is
    #           applied, loop back to the beginning of step b.  This
    #           ensures that bibtex etc are applied before rerunning
    #           (pdf)latex, and also covers changing source files, and
    #           gives priority to quick pre-primary rules for changing
    #           source files against slow reruns of latex.
    #        d. Then apply post-primary rules in order, but not
    #           looping back after each rule.  This non-looping back
    #           is because the rules are normally feed-forward only.
    #      BUT applying the ordering is not essential
    #        e. But after completing post-primary rules do loop back
    #           to b if any rules were applied.  This covers exotic
    #           circular dependence (and as a byproduct, changing
    #           source files).
    #        f. On each case of looping back to b, re-evaluate the
    #           dependence setup to allow for the effect of changing
    #           source files.  
    #    

    local @requested_targets = @_;
    local %current_primaries = ();   # Hash whose keys are primary rules 
                # needed, i.e., known latex-like rules which trigger
                # circular dependencies
    local @pre_primary = ();   # Array of rules
    local @post_primary = ();  # Array of rules
    local @one_time = ();      # Array of rules


    # For diagnostics on changed files, etc:
    local @changed = ();
    local @disappeared = ();
    local @no_dest = ();       # Non-existent destination files
    local @rules_to_apply = ();

    &rdb_classify_rules( \%possible_primaries, @requested_targets );

    local %pass = ();
    local $failure = 0;        # General accumulated error flag
    local $runs = 0;
    local $too_many_runs = 0;
    local %rules_applied = ();
    my $retry_msg = 0;         # Did I earlier say I was going to attempt 
                               # another pass after a failure?
  PRIMARY:
    foreach my $primary (keys %current_primaries ) {
        foreach my $rule (keys %rule_db) { 
            $pass{$rule} = 0; 
        }
      PASS:
        while (1==1) {
            $runs = 0;
            my $previous_failure = $failure;
            $failure = 0;
            local $newrule_nofile = 0;  # Flags whether rule created for
                           # making currently non-existent file, which
                           # could become a needed source file for a run
                           # and therefore undo an error condition
	    if ($diagnostics) {
                print "MakeB: doing pre_primary and primary...\n";
            }
            rdb_for_some( [@pre_primary, $primary], \&rdb_makeB1 );
            if ( ($runs > 0) && ! $too_many_runs ) {
                $retry_msg = 0;
                if ( $failure && $newrule_nofile ) { 
                    $retry_msg = 1;
                    print "$My_name: Error on run, but found possibility to ",
                          "make new source files\n";
                    next PASS;
		}
                elsif ( ! $failure ) {
                    next PASS;
		}
            }
            elsif ($runs == 0) {
                # $failure not set on this pass, so use value from previous pass:
                $failure = $previous_failure;
                if ($retry_msg) {
                    print "But in fact no new files made\n";
		}
	    }
            if ($failure && !$force_mode ) { last PASS; }
	    if ($diagnostics) {
  	        print "MakeB: doing post_primary...\n";
	    }
            rdb_for_some( [@post_primary], \&rdb_makeB1 );
            if ($failure) { last PASS; }
            if ($runs > 0) { next PASS; }
            # Get here if nothing was run.
            last PASS;
	}
	continue {
            # Re-evaluate rule classification and accessibility,
            # but do not change primaries.
            &rdb_classify_rules( \%current_primaries, @requested_targets );
            &rdb_make_links;
	}
    }
    rdb_for_some( [@one_time], \&rdb_makeB1 );
    rdb_write( $fdb_file );

    if (! $silent) { 
        # Diagnose of the runs
        if ( $#{keys %rules_applied }  > -1 ) {
            print "$My_name: $runs runs.  Rules applied:\n";
            foreach (sort keys %rules_applied) {
		print "    '$_'\n";
	    }
	}
	elsif ($failure && $force_mode) {
            print "$My_name: Errors, in force_mode: so I tried finishing targets\n";
	}
	elsif ($failure) {
            print "$My_name: Errors, so I did not complete making targets\n";
	}
	else {
            local @dests = ();
            rdb_for_some( [@_], sub{ push @dests, $$Pdest if ($$Pdest); } );
            print "$My_name: All targets (@dests) are up-to-date\n";
	}
    }
    return $failure;
} #END rdb_makeB

#-------------------

sub rdb_makeB1 {
    # Call: rdb_makeB1
    # Helper routine for rdb_makeB.
    # Carries out make at level of given rule (all data available).
    # Assumes contexts for recursion, make, and rule, and
    # assumes that source files for the rule are to be considered
    # up-to-date. 
    if ($diagnostics) { print "  MakeB1 $rule\n"; }
    if ($failure & ! $force_mode) {return;}
    &rdb_clear_change_record;
    &rdb_flag_changes_here;
#    if ($diagnostics>-1) { print "     MakeB1.1 $rule $$Pout_of_date\n"; }

    my $return = 0;   # Return code from called routine
#??    print "makeB1: Trying '$rule' for '$$Pdest': ";
    if (!$$Pout_of_date) {
#??	if ( ($$Pcmd_type eq 'primary') && (! $silent) ) {
#            print "Rule '$rule' up to date\n";
#        }
	return;
    }
    if ($diagnostics) { print "     remake\n"; }
    if (!$silent) { 
        print "$My_name: applying rule '$rule'...\n"; 
        &rdb_diagnose_changes( "$rule: ");
    }
##????????????????????????????????????: variable rules_applied not used
    $rules_applied{$rule} = 1;
    $runs++;
#??    print "$rule: $$Pcmd_type\n";

    # We are applying the rule, so its source file state for when it
    # was last made is as of now:
    # ??IS IT CORRECT TO DO NOTHING IN CURRENT VERSION?

    # The actual run
    $return = 0;
    # Rule may have been created since last run:
    if ( ! defined $pass{$rule} ) {$pass{$rule} = 0; }
    if ( $pass{$rule} ge $max_repeat ) {
        # Avoid infinite loop by having a maximum repeat count
        # Getting here represents some kind of weird error.
        warn "$My_name: Maximum runs of $rule reached ",
             "without getting stable files\n";
        $too_many_runs = 1;
        $failure = 1;
	$failure_msg = "'$rule' needed too many passes";
        return;
    }
    $pass{$rule}++; 
    warn_running( "Run number $pass{$rule} of rule '$rule'" );
    if ($$Pcmd_type eq 'primary' ) { 
        $return = &rdb_primary_run; 
    }
    else { $return = &rdb_run1; }
    if ($$Pchanged) {
        $newrule_nofile = 1;
        $return = 0;
    }
    elsif ( $$Pdest && ( !-e $$Pdest ) && (! $failure) ){
        # If there is a destination to make, but for some reason
        #    it did not get made, then make sure a failure gets reported.
        # But if the failure has already been reported, there's no need
        #    to report here, since that would give a generic error
        #    message instead of a specific one.
        $failure = 1;
	$failure_msg = "'$rule' did not make '$$Pdest'";
    }
    if ($return != 0) {$failure = 1;}
}  #END rdb_makeB1

#************************************************************

sub rdb_submakeB {
    # Call: rdb_submakeB
    # Makes all the source files for a given rule.
    # Assumes contexts for recursion, for make, and rule.
    %visited = %visited_at_rule_start;
    local $failure = 0;  # Error flag
    my @v = keys %visited;
#??    print "---submakeB $rule.  @v \n";
    rdb_do_files( sub{ rdb_recurse_rule( $$Pfrom_rule, 0,0,0, \&rdb_makeB1 ) } );
    return $failure;
}  #END rdb_submakeB

#************************************************************


sub rdb_classify_rules {
    # Usage: rdb_classify_rules( \%allowed_primaries, requested targets )
    # Assume the following variables are available (global or local):
    # Input:
    #    @requested_targets    # Set to target rules
    
    # Output:
    #    %current_primaries    # Keys are actual primaries
    #    @pre_primary          # Array of rules
    #    @post_primary         # Array of rules
    #    @one_time             # Array of rules
    # @pre_primary and @post_primary are in natural order of application.

    local $P_allowed_primaries = shift;
    local @requested_targets = @_;
    local $state = 0;       # Post-primary
    local @classify_stack = ();

    %current_primaries = ();
    @pre_primary = ();
    @post_primary = ();
    @one_time = ();

    rdb_recurseA( \@requested_targets, \&rdb_classify1, 0,0, \&rdb_classify2 );

    # Reverse, as tendency is to find last rules first.
    @pre_primary = reverse @pre_primary;
    @post_primary = reverse @post_primary;

    if ($diagnostics) {
	print "Rule classification: \n";
	if ($#requested_targets < 0) {
	    print "  No requested rules\n";
	}
	else {
	    print "  Requested rules:\n";
	    foreach ( @requested_targets ) { print "    $_\n"; }
	}
	if ($#pre_primary < 0) {
	    print "  No pre-primaries\n";
	}
	else {
	    print "  Pre-primaries:\n";
	    foreach (@pre_primary) { print "    $_\n"; }
	}
	print "  Primaries:\n";
	foreach (keys %current_primaries) { print "    $_\n"; }
	if ($#post_primary < 0) {
	    print "  No post-primaries\n";
	}
	else {
	    print "  Post-primaries:\n";
	    foreach (@post_primary) { print "    $_\n"; }
	}
	if ($#one_time < 0) {
	    print "  No one_time rules\n";
	}
	else {
	    print "  One_time rules:\n";
	    foreach ( @one_time ) { print "    $_\n"; }
	}
    } #end diagnostics
} #END rdb_classify_rules

#-------------------

sub rdb_classify1 {
    # Helper routine for rdb_classify_rules
    # Applied as rule_act1 in recursion over rules
    # Assumes rule context, and local variables from rdb_classify_rules
#    print "=========== '$rule' $depth ========== \n";
    push @classify_stack, [$state];
    if ( exists $possible_one_time{$rule} ) {
        # Normally, we will have already extracted the one_time rules,
        # and they will never be accessed here.  But just in case of
        # problems or generalizations, we will cover all possibilities:
        if ($depth > 1) {
           warn "ONE TIME rule not at outer level '$rule'\n";
        }
        push @one_time, $rule;
    }
    elsif ($state == 0) {
       if ( exists ${$P_allowed_primaries}{$rule} ) {
           $state = 1;   # In primary rule
           $current_primaries{ $rule } = 1;
       }
       else {
	   push @post_primary, $rule;
       }
    }
    else {
        $state = 2;     # in post-primary rule
	push @pre_primary, $rule;
    }
} #END rdb_classify1

#-------------------

sub rdb_classify2 {
    # Helper routine for rdb_classify_rules
    # Applied as rule_act2 in recursion over rules
    # Assumes rule context
    ($state) = @{ pop @classify_stack };
} #END rdb_classify2

#************************************************************


sub rdb_run1 {
    # Assumes contexts for: rule.
    # Unconditionally apply the rule
    # Returns return code from applying the rule.
    # Otherwise: 0 on other kind of success, -1 on error.

    # Source file data, by definition, correspond to the file state just before 
    # the latest run, and the run_time to the time just before the run:
    &rdb_update_filesA;
    $$Prun_time = time;
    $$Pchanged = 0;       # No special changes in files

    # Return values for external command:
    my $return = 0;

    # Find any internal command
    my @int_args = @$PAint_cmd;
    my $int_cmd = shift @int_args;

    if ($int_cmd) {
	print "For rule '$rule', running '\&$int_cmd( @int_args )' ...\n";
        $return = &$int_cmd( @int_args ); 
    }
    elsif ($$Pext_cmd) {
	$return = &rdb_ext_cmd;
    }
    else {
        warn "$My_name: Either a bug OR a configuration error:\n",
             "    Need to implement the command for '$rule'\n";
        &traceback();
        $return = -1;
    }
    if ( $rule =~ /^bibtex/ ) {
        my $retcode = &check_bibtex_log($$Pbase);
        if ($retcode == 3) {
            push @warnings, 
                 "Could not open bibtex log file for '$$Pbase'";
        }
        elsif ($retcode == 2) {
            push @warnings, "Bibtex errors for '$$Pbase'";
        }
        elsif ($retcode == 1) {
            push @warnings, "Bibtex warnings for '$$Pbase'";
        }
    }

    $updated = 1;
    if ($$Ptest_kind == 3) { 
        # We are time-criterion first time only.  Now switch to
	# file-change criterion
        $$Ptest_kind = 1; 
    }
    $$Pout_of_date = $$Pout_of_date_user = 0;
    return $return;
}  # END rdb_run1

#-----------------

sub rdb_ext_cmd {
    # Call: rdb_ext_cmd
    # Assumes rule context.  Runs external command with substitutions.
    # Uses defaults for the substitutions.  See rdb_ext_cmd1.
    return rdb_ext_cmd1();
} #END rdb_ext_cmd

#-----------------

sub rdb_ext_cmd1 {
    # Call: rdb_ext_cmd1( options, source, dest, base ) or rdb_ext_cmd1() or ...
    # Assumes rule context.  Returns command with substitutions.
    # Null arguments or unprovided arguments => use defaults.
    # for %S=source, %D=dest, %B=base, %R=root=base for latex, %O='', %T=texfile
    my ($options, $source, $dest, $base ) = @_;
    # Apply defaults
    $options ||= '';
    $source  ||= $$Psource;
    $dest    ||= $$Pdest;
    $base    ||= $$Pbase;
    
    my $ext_cmd = $$Pext_cmd;
    
    #Set character to surround filenames:
    my $q = $quote_filenames ? '"' : '';
    foreach ($ext_cmd) {
        s/%O/$options/g;
        s/%R/$q$root_filename$q/g;
	s/%B/$q$base$q/g;
	s/%T/$q$texfile_name$q/g;
	s/%S/$q$source$q/g;
	s/%D/$q$dest$q/g;
    }
    # print "quote is '$q'; ext_cmd = '$ext_cmd'\n";
    my ($pid, $return) = &Run_msg($ext_cmd);
    return $return;
} #END rdb_ext_cmd1

#-----------------

sub rdb_primary_run {
#?? See multipass_run in previous version Aug 2007 for issues
    # Call: rdb_primary_run
    # Assumes contexts for: recursion, make, & rule.
    # Assumes (a) the rule is a primary, 
    #         (b) a run has to be made,
    #         (c) source files have been made.
    # This routine carries out the run of the rule unconditionally,
    # and then parses log file etc.
    my $return = 0;

    my $return_latex = &rdb_run1;

    ######### Analyze results of run:
    if ( ! -e "$root_filename.log" ) {
        $failure = 1;
        $failure_msg = "(Pdf)LaTeX failed to generate a log file";
        return -1;
    }
    ####### NOT ANY MORE! Capture any changes in source file status before we
    #         check for errors in the latex run

    # Find current set of source files:
    &rdb_set_from_logB;

    # For each file of the kind made by epstopdf.sty during a run, 
    #   if the file has changed during a run, then the new version of
    #   the file will have been read during the run.  Unlike the usual
    #   case, we will need to redo the primary run because of the
    #   change of this file during the run.  Therefore set the file as
    #   up-to-date:
    rdb_do_files( sub { if ($$Pcorrect_after_primary) {&rdb_update1;} } );

    # There may be new source files, and the run may have caused
    # circular-dependency files to be changed.  And the regular
    # source files may have been updated during a lengthy run of
    # latex.  So redo the makes for sources of the current rule:
    my $submake_return = &rdb_submakeB;
    &rdb_clear_change_record;
    &rdb_flag_changes_here;
    $updated = 1;    # Flag that some dependent file has been remade
    # Fix the state of the files as of now: this will solve the
    # problem of latex and pdflatex interfering with each other,
    # at the expense of some non-optimality
    #??  Check this is correct:
    &rdb_update_filesA;
    if ( $diagnostics ) {
	print "$My_name: Rules after run: \n";
	rdb_show();
    }

    $return = $return_latex;
    if ($return_latex && $$Pout_of_date_user) {
       print "Error in (pdf)LaTeX, but change of user file(s), ",
             "so ignore error & provoke rerun\n"
          if (! $silent);
       $return = 0;
    }

    # Summarize issues that may have escaped notice:
    my @warnings = ();
    if ($bad_reference) {
        push @warnings, "Latex could not resolve all references";
    }
    if ($bad_citation) {
        push @warnings, "Latex could not resolve all citations";
    }
    if ($#warnings > 0) {
	show_array( "$My_name: Summary of warnings:", @warnings );
    }
    return $return;
} #END rdb_primary_run

#************************************************************

sub rdb_clear_change_record {
    @changed = ();
    @disappeared = ();
    @no_dest = ();
    @rules_to_apply = ();
#???????????????    $failure = 0;
##????????????????????????????????????: variable rules_applied not used
    $rules_applied = 0;
} #END rdb_clear_change_record 

#************************************************************

sub rdb_flag_changes_here {
    # Flag changes in current rule.  
    # Assumes rule context.
    local $dest_mtime = 0;
    $dest_mtime = get_mtime($$Pdest) if ($$Pdest);
    rdb_do_files( \&rdb_file_change1);
    if ( $$Pdest && (! -e $$Pdest) ) {
         $$Pout_of_date = 1;
         push @no_dest, $$Pdest;
     }
    if ($$Pout_of_date) {
	push @rules_to_apply, $rule;
    }
#??	print "======== flag: $rule $$Pout_of_date ==========\n";
} #END rdb_flag_changes_here

#************************************************************

sub rdb_file_change1 {
    # Call: &rdb_file_change1
    # Assumes rule and file context.  Assumes $dest_mtime set.
    # Flag whether $file in $rule has changed or disappeared.
    # Set rule's make flag if there's a change.
    my ($new_time, $new_size, $new_md5) = fdb_get($file);
#??    print "FC1 '$rule':$file $$Pout_of_date TK=$$Ptest_kind\n"; 
#??    print "    OLD $$Ptime, $$Psize, $$Pmd5\n",
#??          "    New $new_time, $new_size, $new_md5\n";
    my $ext = ext( $file );
    if ( ($new_size < 0) && ($$Psize >= 0) ) {
        push @disappeared, $file;
        # No reaction is good.
        #$$Pout_of_date = 1;
        return;
    }
    if ( ($new_size < 0) && ($$Psize < 0) ) {
	return;
    }
    if ( ($new_size != $$Psize) || ($new_md5 ne $$Pmd5) ) {
#??        print "FC1: changed $file: ($new_size != $$Psize) $new_md5 ne $$Pmd5)\n";
	push @changed, $file;
	$$Pout_of_date = 1;
        if ( ! exists $generated_exts_all{$ext} ) {
            $$Pout_of_date_user = 1;
	}
    }
    if ( ( ($$Ptest_kind == 2) || ($$Ptest_kind == 3) )
         && (! exists $generated_exts_all{$ext} )
         && ( $new_time > $dest_mtime )
        ) {
#??        print "FC1: changed $file: ($new_time > $dest_mtime)\n";
	    push @changed, $file;
	    $$Pout_of_date = $$Pout_of_date_user = 1;
    }
} #END rdb_file_change1

#************************************************************

sub rdb_count_changes {
    return $#changed + $#disappeared  + $#no_dest + $#rules_to_apply + 4;
} #END rdb_count_changes

#************************************************************

sub rdb_diagnose_changes {
    # Call: rdb_diagnose_changes or rdb_diagnose_changes( heading )
    # List changes on STDERR
    # Precede the message by the optional heading, else by "$My_name: " 
    my $heading = defined($_[0]) ?   $_[0]  :  "$My_name: "; 

    if ( &rdb_count_changes == 0 ) {
	warn "${heading}No changes\n";
	return; 
    }
    warn "${heading}Changes:\n";
    if ( $#changed >= 0 ) {
	warn "   Changed files, or newly in use since previous run(s):\n";
	foreach (uniqs(@changed)) { warn "      '$_'\n"; }
    }
    if ( $#disappeared >= 0 ) {
	warn "   No-longer-existing files:\n";
	foreach (uniqs(@disappeared)) { warn "      '$_'\n"; }
    }
    if ( $#no_dest >= 0 ) {
	warn "   Non-existent destination files:\n";
	foreach (uniqs(@no_dest)) { warn "      '$_'\n"; }
    }
    if ( $#rules_to_apply >= 0 ) {
	warn "   Rules to apply:\n";
	foreach (uniqs(@rules_to_apply)) { warn "      '$_'\n"; }
    }
}     #END rdb_diagnose_changes


#************************************************************
#************************************************************
#************************************************************
#************************************************************

#************************************************************
#************************************************************
#************************************************************
#************************************************************

# Routines for convenient looping and recursion through rule database
# ================= NEW VERSION ================

# There are several places where we need to loop through or recurse
# through rules and files.  This tends to involve repeated, tedious
# and error-prone coding of much book-keeping detail.  In particular,
# working on files and rules needs access to the variables involved,
# which either involves direct access to the elements of the database,
# and consequent fragility against changes and upgrades in the
# database structure, or involves lots of routines for reading and
# writing data in the database, then with lots of repetitious
# house-keeping code.
#
# The routines below provide a solution.  Looping and recursion
# through the database are provided by a set of basic routines where
# each necessary kind of looping and iteration is coded once.  The
# actual actions are provided as references to action subroutines.
# (These can be either actual references, as in \&routine, or
# anonymous subroutines, as in sub{...}, or aas a zero value 0 or an
# omitted argument, to indicate that no action is to be performed.)
#
# When the action subroutine(s) are actually called, a context for the
# rule and/or file (as appropriate) is given by setting named
## NEW ??
# variables to REFERENCES to the relevant data values.  These can be
# used to retrieve and set the data values.  As a convention,
# references to scalars are given by variables named start with "$P",
# as in "$Pdest", while references to arrays start with "$PA", as in 
# "$PAint_cmd", and references to hashes with "$PH", as in "$PHsource".
# After the action subroutine has finished, checks for data
# consistency may be made. 
## ??? OLD
# variables to the relevant data values.  After the action subroutine
# has finished, the database is updated with the values of these named
# variables, with any necessary consistency checks.  Thus the action
# subroutines can act on sensibly named variables without needed to
# know the database structure.  
#
# The only routines that actually use the database structure and need
# to be changed if that is changed are:  (a) the routines rdb_one_rule
# and rdb_one_file that implement the calling of the action subroutines,
# (b) routines for creation of single rules and file items, and (c) to
# a lesser extent, the routine for destroying a file item.  
#
# Note that no routine is provided for destroying a rule.  During a
# run, a rule, with its source files, may become inaccessible or
# unused.  This happens dynamically, depending on the dependencies
# caused by changes in the source file or by error conditions that
# cause the computation of dependencies, particular of latex files, to
# become wrong.  In that situation the files certainly come and go in
# the database, but subsidiary rules, with their content information
# on their source files, need to be retained so that their use can be
# reinstated later depending on dynamic changes in other files.
#
# However, there is a potential memory leak unless some pruning is
# done in what is written to the fdb file.  (Probably only accessible
# rules and those for which source files exist.  Other cases have no
# relevant information that needs to be preserved between runs.)

#
#


#************************************************************

# First the top level routines for recursion and iteration

#************************************************************

sub rdb_recurseA {
    # Call: rdb_recurseA( rule | [ rules],
    #                    \&rule_act1, \&file_act1, \&file_act2, 
    #                    \&rule_act2 )
    # The actions are pointers to subroutines, and may be null (0, or
    # undefined) to indicate no action to be applied.
    # Recursively acts on the given rules and all ancestors:
    #   foreach rule found:
    #       apply rule_act1
    #       loop through its files:
    #          apply file_act1
    #          act on its ancestor rule, if any
    #          apply file_act2
    #       apply rule_act2
    # Guards against loops.  
    # Access to the rule and file data by local variables, only
    #   for getting and setting.

    # This routine sets a context for anything recursive, with @heads,
    # %visited  and $depth being set as local variables.
    local @heads = ();
    my $rules = shift;

    # Distinguish between single rule (a string) and a reference to an
    # array of rules:
    if ( ref $rules eq 'ARRAY' ) { @heads = @$rules; }
    else { @heads = ( $rules ); }

    # Keep a list of visited rules, used to block loops in recursion:
    local %visited = (); 
    local $depth = 0;

    foreach $rule ( @heads ) { rdb_recurse_rule( $rule, @_ ); }

} #END rdb_recurseA

#************************************************************

sub rdb_for_all {
    # Call: rdb_for_all( \&rule_act1, \&file_act, \&rule_act2 )
    # Loops through all rules and their source files, using the 
    #   specified set of actions, which are pointers to subroutines.
    # Sorts rules alphabetically.
    # See rdb_for_some for details.
    rdb_for_some( [ sort keys %rule_db ], @_);
} #END rdb_for_all

#************************************************************

sub rdb_for_some {
    # Call: rdb_for_some( rule | [ rules],
    #                    \&rule_act1, \&file_act, \&rule_act2)
    # Actions can be zero, and rules at tail of argument list can be
    # omitted.  E.g. rdb_for_some( rule, 0, \&file_act ).  
    # Anonymous subroutines can be used, e.g., rdb_for_some( rule, sub{...} ).  
    #
    # Loops through rules and their source files, using the 
    # specified set of rules:
    #   foreach rule:
    #       apply rule_act1
    #       loop through its files:
    #          apply file_act
    #       apply rule_act2
    #
    # Rule data and file data are made available in local variables 
    # for access by the subroutines.

    local @heads = ();
    my $rules = shift;
    # Distinguish between single rule (a string) and a reference to an
    # array of rules:
    if ( ref $rules eq 'ARRAY' ) { @heads = @$rules; }
    else { @heads = ( $rules ); }

    foreach $rule ( @heads ) {
        # $rule is implicitly local
	&rdb_one_rule( $rule, @_ );
    }
}  #END rdb_for_some

#************************************************************

sub rdb_for_one_file {
    my $rule = shift;
    # Avoid name collisions with general recursion and iteraction routines:
    local $file1 = shift;
    local $action1 = shift;
    rdb_for_some( $rule, sub{rdb_one_file($file1,$action1)} );
} #END rdb_for_one_file


#************************************************************

#   Routines for inner part of recursion and iterations

#************************************************************

sub rdb_recurse_rule {
    # Call: rdb_recurse_rule($rule, \&rule_act1, \&file_act1, \&file_act2, 
    #                    \&rule_act2 )
    # to do the work for one rule, recurisvely called from_rules for
    # the sources of the rules.
    # Assumes recursion context, i.e. that %visited, @heads, $depth.
    # We are overriding actions:
    my ($rule, $rule_act1, $new_file_act1, $new_file_act2, $rule_act2)
	= @_;
    # and must propagate the file actions:
    local $file_act1 = $new_file_act1;
    local $file_act2 = $new_file_act2;
    # Prevent loops:
    if ( (! $rule) || exists $visited{$rule} ) { return; }
    $visited{$rule} = 1;
    # Recursion depth
    $depth++;
    # We may need to repeat actions on dependent rules, without being
    # blocked by the test on visited files.  So save %visited:
    local %visited_at_rule_start = %visited;
    # At end, the last value set for %visited wins.
    rdb_one_rule( $rule, $rule_act1, \&rdb_recurse_file, $rule_act2 );
    $depth--;
 } #END rdb_recurse_rule 

#************************************************************

sub rdb_recurse_file {
    # Call: rdb_recurse_file to do the work for one file.
    # This has no arguments, since it is used as an action subroutine,
    # passed as a reference in calls in higher-level subroutine.
    # Assumes contexts set for: Recursion, rule, and file
    &$file_act1 if $file_act1;
    rdb_recurse_rule( $$Pfrom_rule, $rule_act1, $file_act1, $file_act2,
		      $rule_act2 )
        if $$Pfrom_rule;
    &$file_act2 if $file_act2;
} #END rdb_recurse_file

#************************************************************

sub rdb_do_files {
    # Assumes rule context, including $PHsource.
    # Applies an action to all the source files of the rule.
    local $file_act = shift;
    my @file_list = sort keys %$PHsource;
    foreach my $file ( @file_list ){
        rdb_one_file( $file, $file_act );
    }
} #END rdb_do_files

#************************************************************

# Routines for action on one rule and one file.  These are the main
# places (in addition to creation and destruction routines for rules
# and files) where the database structure is accessed.

#************************************************************

sub rdb_one_rule {
    # Call: rdb_one_rule( $rule, $rule_act1, $file_act, $rule_act2 )
    # Sets context for rule and carries out the actions.
#===== Accesses rule part of database structure =======

    local ( $rule, $rule_act1, $file_act, $rule_act2 ) = @_;
#??    &R1;
    if ( (! $rule) || ! rdb_rule_exists($rule) ) { return; }

    local ( $PArule_data, $PHsource ) = @{$rule_db{$rule}};
    local ($Pcmd_type, $Pext_cmd, $PAint_cmd, $Ptest_kind, 
           $Psource, $Pdest, $Pbase,
           $Pout_of_date, $Pout_of_date_user, $Prun_time, $Pchanged )
        = Parray( $PArule_data );
    # Correct array ref:
    $PAint_cmd = $$PArule_data[2];

    &$rule_act1 if $rule_act1;
    &rdb_do_files( $file_act ) if $file_act;
    &$rule_act2 if $rule_act2;

#??    &R2;
} #END rdb_one_rule

#************************************************************

sub rdb_one_file {
    # Call: rdb_one_file($file, $file_act)
    # Sets context for file and carries out the action.
    # Assumes $rule context set.
#===== Accesses file part of database structure =======
    local ($file, $file_act) = @_;
#??    &F1;
    if ( (!$file) ||(!exists ${$PHsource}{$file}) ) { return; }
    local $PAfile_data = ${$PHsource}{$file};
    local ($Ptime, $Psize, $Pmd5, $Pfrom_rule, $Pcorrect_after_primary ) 
          = Parray( $PAfile_data );
    &$file_act if $file_act;
    if ( ! rdb_rule_exists( $$Pfrom_rule ) ) {
        $$Pfrom_rule = '';
    }
#??    &F2;
} #END rdb_one_file

#************************************************************

# Routines for creation of rules and file items, and for removing file
# items. 

#************************************************************

sub rdb_create_rule {
    # rdb_create_rule( rule, command_type, ext_cmd, int_cmd, test_kind,
    #                  source, dest, base, 
    #                  needs_making, run_time )
    # int_cmd is either a string naming a perl subroutine or it is a
    # reference to an array containing the subroutine name and its
    # arguments. 
    # Makes rule.  Error if it already exists.
    # Omitted arguments: replaced by 0 or '' as needed.    
# ==== Sets rule data ====
    my ( $rule, $cmd_type, $int_cmd, $PAext_cmd, $test_kind, 
         $source, $dest, $base, 
         $needs_making, $run_time ) = @_;
    my $changed = 0;
    # Set defaults, and normalize parameters:
    foreach ( $cmd_type, $int_cmd, $PAext_cmd, $source, $dest, $base ) {
        if (! defined $_) { $_ = ''; }
    }
    foreach ( $needs_making, $run_time, $test_kind ) {
        if (! defined $_) { $_ = 0; }
    }
    if (!defined $test_kind) {
        # Default to test on file change
        $test_kind = 1; 
    }
    if ( ref( $PAext_cmd ) eq '' ) {
        #  It is a single command.  Convert to array reference:
        $PAext_cmd = [ $PAext_cmd ];
    }
    else {
        # COPY the referenced array:
        $PAext_cmd = [ @$PAext_cmd ];
    }

    $rule_db{$rule} = 
        [  [$cmd_type, $int_cmd, $PAext_cmd, $test_kind, 
            $source, $dest, $base, $needs_making, 0, $run_time,
            $changed ],
           {}
	];
    if ($source) { rdb_ensure_file( $rule, $source );  }
} #END rdb_create_rule

#************************************************************

sub rdb_ensure_file {
    # rdb_ensure_file( rule, file[, fromrule] )
    # Ensures the source file item exists in the given rule.
    # Initialize to current file state if the item is created.
    # Then if the fromrule is specified, set it for the file item.
#============ rule and file data set here ======================================
    my $rule = shift;
    local ( $new_file, $new_from_rule ) = @_;
    if ( ! rdb_rule_exists( $rule ) ) {
	die_trace( "$My_name: BUG in rdb_ensure_file: non-existent rule '$rule'" );
    }
    if ( ! defined $new_file ) {
	die_trace( "$My_name: BUG in rdb_ensure_file: undefined file for '$rule'" );
    }
    rdb_one_rule( $rule, 
                  sub{
                      if (! exists ${$PHsource}{$new_file} ) {
                          ${$PHsource}{$new_file} = [fdb_get($new_file), '', 0];
		      }
		  }
    );
    if (defined $new_from_rule ) {
	rdb_for_one_file( $rule, $new_file, sub{ $$Pfrom_rule = $new_from_rule; });
    }
} #END rdb_ensure_file 

#************************************************************

sub rdb_remove_files {
    # rdb_remove_file( rule, file,... )
    # Removes file(s) for the rule.  
    my $rule = shift;
    if (!$rule) { return; }
    local @files = @_;
    rdb_one_rule( $rule, 
                  sub{ foreach (@files) { delete ${$PHsource}{$_}; }  }
    );
} #END rdb_remove_files

#************************************************************

sub rdb_rule_exists { 
    # Call rdb_rule_exists($rule): Returns whether rule exists.
    my $rule = shift;
    if (! $rule ) { return 0; }
    return exists $rule_db{$rule}; 
} #END rdb_rule_exists

#************************************************************

sub rdb_file_exists { 
    # Call rdb_file_exists($rule, $file): 
    # Returns whether source file item in rule exists.
    local ( $rule, $file ) = @_;
    local $exists = 0;
    rdb_one_rule( $rule, 
                  sub{ $exists =  exists( ${$PHsource}{$file} ) ? 1:0; } 
		);
    return $exists; 
} #END rdb_file_exists

#************************************************************

sub rdb_update_gen_files {
    # Call: fdb_updateA
    # Assumes rule context.  Update source files of rule to current state.
    rdb_do_files( 
        sub{
	    if ( exists $generated_exts_all{ ext($file) } ) {&rdb_update1;} 
        }
    );
} #END rdb_update_gen_files

#************************************************************

sub rdb_update_filesA {
    # Call: fdb_updateA
    # Assumes rule context.  Update source files of rule to current state.
    rdb_do_files( \&rdb_update1 );
}

#************************************************************

sub rdb_update1 {
    # Call: fdb_update1.  
    # Assumes file context.  Updates file data to correspond to
    # current file state on disk
    ($$Ptime, $$Psize, $$Pmd5) = fdb_get($file);
}

#************************************************************

sub rdb_set_file1 {
    # Call: fdb_file1(rule, file, new_time, new_size, new_md5)
    # Sets file time, size and md5.
    my $rule = shift;
    my $file = shift;
    local @new_file_data = @_;
    rdb_for_one_file( $rule, $file, sub{ ($$Ptime,$$Psize,$$Pmd5)=@new_file_data; } );
}

#************************************************************

sub rdb_dummy_file {
    # Returns file data for non-existent file
# ==== Uses rule_db structure ====
    return (0, -1, 0, '');
}

#************************************************************
#************************************************************

# Predefined subroutines for custom dependency

sub cus_dep_delete_dest {
    # This subroutine is used for situations like epstopdf.sty, when
    #   the destination (target) of the custom dependency invoking
    #   this subroutine will be made by the primary run provided the
    #   file (destination of the custom dependency, source of the
    #   primary run) doesn't exist.
    # It is assumed that the resulting file will be read by the
    #   primary run.

    # Remove the destination file, to indicate it needs to be remade:
    unlink $$Pdest;
    # Arrange that the non-existent destination file is not treated as
    #   an error.  The variable changed here is a bit misnamed.
    $$Pchanged = 1;
    # Ensure a primary run is done
    &cus_dep_require_primary_run;
    # Return success:
    return 0;
}

#************************************************************

sub cus_dep_require_primary_run {
    # This subroutine is used for situations like epstopdf.sty, when
    #   the destination (target) of the custom dependency invoking
    #   this subroutine will be made by the primary run provided the
    #   file (destination of the custom dependency, source of the
    #   primary run) doesn't exist.
    # It is assumed that the resulting file will be read by the
    #   primary run.

    local $cus_dep_target = $$Pdest;
    # Loop over all rules and source files:
    rdb_for_all( 0, 
                 sub { if ($file eq $cus_dep_target) {
                            $$Pout_of_date = 1;
                            $$Pcorrect_after_primary = 1;
                       }
                     }
               );
    # Return success:
    return 0;
}


#************************************************************
#************************************************************
#************************************************************
#
#      UTILITIES:
#

#************************************************************
# Miscellaneous

sub show_array {
# For use in diagnostics and debugging. 
#  On stderr, print line with $_[0] = label.  
#  Then print rest of @_, one item per line preceeded by some space
    warn "$_[0]\n";
    shift;
    foreach (@_){ warn "  $_\n";}
}

#************************************************************

sub Parray {
    # Call: Parray( \@A )
    # Returns array of references to the elements of @A
    my $PA = shift;
    my @P = (undef) x (1+$#$PA);
    foreach my $i (0..$#$PA) { $P[$i] = \$$PA[$i]; }
    return @P;
}

#************************************************************

sub glob_list {
    # Glob a collection of filenames.  Sort and eliminate duplicates
    # Usage: e.g., @globbed = glob_list(string, ...);
    my @globbed = ();
    foreach (@_) {
        push @globbed, glob;
    }
    return uniqs( @globbed );
}

#==================================================

sub glob_list1 {
    # Glob a collection of filenames.  
    # But no sorting or elimination of duplicates
    # Usage: e.g., @globbed = glob_list1(string, ...);
    # Since perl's glob appears to use space as separator, I'll do a special check
    # for existence of non-globbed file (assumed to be tex like)

    my @globbed = ();
    foreach my $file_spec (@_) {
        # Problem, when the PATTERN contains spaces, the space(s) are
        # treated as pattern separaters (in MSWin at least).
        # MSWin: I can quote the pattern (is that MSWin native, or also 
        #        cygwin?)
        # Linux: Quotes in a pattern are treated as part of the filename!
        #        So quoting a pattern is definitively wrong.
        # The following hack solves this partly, for the cases that there is no wildcarding 
        #    and the specified file exists possibly space-containing, and that there is wildcarding,
        #    but spaces are prohibited.
        if ( -e $file_spec || -e "$file_spec.tex" ) { 
           # Non-globbed file exists, return the file_spec.
           # Return $file_spec only because this is not a file-finding subroutine, but
           #   only a globber
           push @globbed, $file_spec; 
        }
        else { 
            # This glob fails to work as desired, if the pattern contains spaces.
            push @globbed, glob( "$file_spec" );
        }
    }
    return @globbed;
}

#************************************************************
# Miscellaneous

sub prefix {
   #Usage: prefix( string, prefix );
   #Return string with prefix inserted at the front of each line
   my @line = split( /\n/, $_[0] );
   my $prefix = $_[1];
   for (my $i = 0; $i <= $#line; $i++ ) {
       $line[$i] = $prefix.$line[$i]."\n";
   }
   return join( "", @line );
}


#************************************************************
#************************************************************
#      File handling utilities:


#************************************************************

sub get_latest_mtime
# - arguments: each is a filename.
# - returns most recent modify time.
{
  my $return_mtime = 0;
  foreach my $include (@_)
  {
    my $include_mtime = &get_mtime($include);
    # The file $include may not exist.  If so ignore it, otherwise
    # we'll get an undefined variable warning.
    if ( ($include_mtime) && ($include_mtime >  $return_mtime) )
    {
      $return_mtime = $include_mtime;
    }
  }
  return $return_mtime;
}

#************************************************************

sub get_mtime_raw
{ 
  my $mtime = (stat($_[0]))[9];
  return $mtime;
}

#************************************************************

sub get_mtime { 
    return get_mtime0($_[0]);
}

#************************************************************

sub get_mtime0 {
   # Return time of file named in argument
   # If file does not exist, return 0;
   if ( -e $_[0] ) {
       return get_mtime_raw($_[0]);
   }
   else {
       return 0;
   }
}

#************************************************************

sub get_size {
   # Return time of file named in argument
   # If file does not exist, return 0;
   if ( -e $_[0] ) {
       return get_size_raw($_[0]);
   }
   else {
       return 0;
   }
}

#************************************************************

sub get_size_raw
{ 
  my $size = (stat($_[0]))[7];
  return $size;
}

#************************************************************

sub get_time_size {
   # Return time and size of file named in argument
   # If file does not exist, return (0,-1);
   if ( -e $_[0] ) {
       return get_time_size_raw($_[0]);
   }
   else {
       return (0,-1);
   }
}

#************************************************************

sub get_time_size_raw
{ 
  my $mtime = (stat($_[0]))[9];
  my $size = (stat($_[0]))[7];
  return ($mtime, $size);
}

#************************************************************

sub get_checksum_md5 {
    my $source = shift;
    my $input = new FileHandle;
    my $md5 = Digest->MD5;
    my $ignore_pattern = '';

    if ( $source eq "" ) { 
       # STDIN:
       open( $input, '-' );
    }
    else {
        open( $input, '<', $source )
        or return 0;
        my ($base, $path, $ext) = fileparseA( $source );
        $ext =~ s/^\.//;
        if ( exists $hash_calc_ignore_pattern{$ext} ) {
            $ignore_pattern = $hash_calc_ignore_pattern{$ext};
        }
    }

    if ( $ignore_pattern ) {
        while (<$input>) {
            if ( /$ignore_pattern/ ){
		$_= '';
	    }
            $md5->add($_);
        }
    }
    else {
        $md5->addfile($input);
    }
    close $input;
    return $md5->hexdigest();
}

#************************************************************

#?? OBSOLETE
# Find file with default extension
# Usage: find_file_ext( name, default_ext, ref_to_array_search_path)
sub find_file_ext
#?? Need to use kpsewhich, if possible.  Leave to find_file?
{
    my $full_filename = shift;
    my $ext = shift;
    my $ref_search_path = shift;
    my $full_filename1 = &find_file($full_filename, $ref_search_path, '1');
#print "Finding \"$full_filename\" with ext \"$ext\" ... ";
    if (( $full_filename1 eq '' ) || ( ! -e $full_filename1 ))
    {
      my $full_filename2 = 
          &find_file("$full_filename.$ext",$ref_search_path,'1');
      if (( $full_filename2 ne '' ) && ( -e $full_filename2 ))
      {
        $full_filename = $full_filename2;
      }
      else
      {
        $full_filename = $full_filename1;
      }
    }
    else
    {
      $full_filename = $full_filename1;
    }
#print "Found \"$full_filename\".\n";
    return $full_filename;
}

#************************************************************
#?? OBSOLETE
# given filename and path, return full name of file, or die if none found.
# when force_include_mode=1, only warn if an include file was not
# found, and return 0 (PvdS).
# Usage: find_file(name, ref_to_array_search_path, warn_on_continue)
sub find_file
#?? Need to use kpsewhich, if possible
{
  my $name = $_[0];
  my $ref_path = $_[1];
  my $dir;
  if ( $name =~ /^\// )
  {
    #Aboslute pathname (by UNIX standards)
    if ( (!-e $name) && ( $_[2] eq '' ) ) {
        if ($force_include_mode) {
           warn "$My_name: Could not find file [$name]\n";
        }
        else {
           die "$My_name: Could not find file [$name]\n";
        }
    }
    return $name;
  }
  # Relative pathname
  foreach $dir ( @{$ref_path} )
  {
#warn "\"$dir\", \"$name\"\n";
    if (-e "$dir/$name")
    {
      return("$dir/$name");
    }
  }
  if ($force_include_mode)
  {
	if ( $_[2] eq '' )
	{
	  warn "$My_name: Could not find file [$name] in path [@{$ref_path}]\n";
	  warn "         assuming in current directory (./$name)\n";
	}
	return("./$name");
  }
  else
  {
	if ( $_[2] ne '' )
	{
	  return('');
	}
# warn "\"$name\", \"$ref_path\", \"$dir\"\n";
  	die "$My_name: Could not find file [$name] in path [@{$ref_path}]\n";
  }
}

#************************************************************

sub find_file1 {
#?? Need to use kpsewhich, if possible

    # Usage: find_file1(name, ref_to_array_search_path)
    # Modified find_file, which doesn't die.
    # Given filename and path, return array of:
    #             full name 
    #             retcode
    # On success: full_name = full name with path, retcode = 0
    # On failure: full_name = given name, retcode = 1

  my $name = $_[0];
  # Make local copy of path, since we may rewrite it!
  my @path = @{$_[1]};
  if ( $name =~ /^\// ) {
     # Absolute path (if under UNIX)
     # This needs fixing, in general
     if (-e $name) { return( $name, 0 );}
     else { return( $name, 1 );}
  }
  foreach my $dir ( @path ) {
      #??print "-------------dir='$dir',  ";
      # Make $dir concatenatable, and empty for current dir:
      if ( $dir eq '.' ) { 
          $dir = ''; 
      }
      elsif ( $dir =~ /[\/\\:]$/ ) { 
          #OK if dir ends in / or \ or :
      }
      elsif ( $dir ne '' ) { 
          #Append directory separator only to non-empty dir
          $dir = "$dir/"; 
      }
      #?? print " newdir='$dir'\n";
      if (-e "$dir$name") {
          return("$dir$name", 0);
      }
  }
  my @kpse_result = kpsewhich( $name );
  if ($#kpse_result > -1) {
      return( $kpse_result[0], 0);
  }
  return("$name" , 1);
} #END find_file1

#************************************************************

sub find_file_list1 {
    # Modified version of find_file_list that doesn't die.
    # Given output and input arrays of filenames, a file suffix, and a path, 
    # fill the output array with full filenames
    # Return a status code:
    # Retcode = 0 on success
    # Retocde = 1 if at least one file was not found
    # Usage: find_file_list1( ref_to_output_file_array, 
    #                         ref_to_input_file_array, 
    #                         suffix,
    #                         ref_to_array_search_path
    #                       )

  my $ref_output = $_[0];
  my $ref_input  = $_[1];
  my $suffix     = $_[2];
  my $ref_search = $_[3];

#??  show_array( "=====find_file_list1.  Suffix: '$suffix'\n Source:",  @$ref_input );
#??  show_array( " Bibinputs:",  @$ref_search );

  my @return_list = ();    # Generate list in local array, since input 
                           # and output arrays may be same
  my $retcode = 0;
  foreach my $file (@$ref_input) {
    my ($tmp_file, $find_retcode) = &find_file1( "$file$suffix", $ref_search );
    if ($tmp_file)  {
    	push @return_list, $tmp_file;
    }
    if ( $find_retcode != 0 ) {
        $retcode = 1;
    }
  }
  @$ref_output = @return_list;
#??  show_array( " Output", @$ref_output );
#??  foreach (@$ref_output) { if ( /\/\// ) {  print " ====== double slash in  '$_'\n"; }  }
  return $retcode;
} #END find_file_list1

#************************************************************

sub kpsewhich {
# Usage: kpsewhich( filespec, ...)
# Returns array of files with paths as found by kpsewhich
#    kpsewhich( 'try.sty', 'jcc.bib' );
# Can also do, e.g.,
#    kpsewhich( '-format=bib', 'trial.bib', 'file with spaces');
    my $cmd = $kpsewhich;
    my @args = @_;
    foreach (@args) {
        if ( ! /^-/ ) {
            $_ = "\"$_\"";
	}
    }
    foreach ($cmd) {
        s/%[RBTDO]//g;
    }
    $cmd =~ s/%S/@args/g;
    my @found = ();
    local $fh;
    open $fh, "$cmd|"
        or die "Cannot open pipe for \"$cmd\"\n";
    while ( <$fh> ) {
	s/^\s*//;
        s/\s*$//;
        push @found, $_;
    }
    close $fh;
#    show_array( "Kpsewhich: '$cmd', '$file_list' ==>", @found );
    return @found;
}

####################################################

sub add_cus_dep {
    # Usage: add_cus_dep( from_ext, to_ext, flag, sub_name )
    # Add cus_dep after removing old versions
    my ($from_ext, $to_ext, $must, $sub_name) = @_;
    remove_cus_dep( $from_ext, $to_ext );
    push @cus_dep_list, "$from_ext $to_ext $must $sub_name";
}

####################################################

sub remove_cus_dep {
    # Usage: remove_cus_dep( from_ext, to_ext )
    my ($from_ext, $to_ext) = @_;
    my $i = 0;
    while ($i <= $#cus_dep_list) {
	if ( $cus_dep_list[$i] =~ /^$from_ext $to_ext / ) {
	    splice @cus_dep_list, $i, 1;
	}
	else {
	    $i++;
	}
    }
}

####################################################

sub show_cus_dep {
    show_array( "Custom dependency list:", @cus_dep_list );
}

####################################################

sub find_dirs1 {
   # Same as find_dirs, but argument is single string with directories
   # separated by $search_path_separator
   find_dirs( &split_search_path( $search_path_separator, ".", $_[0] ) );
}


#************************************************************

sub find_dirs {
# @_ is list of directories
# return: same list of directories, except that for each directory 
#         name ending in //, a list of all subdirectories (recursive)
#         is added to the list.
#   Non-existent directories and non-directories are removed from the list
#   Trailing "/"s and "\"s are removed
    local @result = ();
    my $find_action 
        = sub 
          { ## Subroutine for use in File::find
            ## Check to see if we have a directory
	       if (-d) { push @result, $File::Find::name; }
	  };
    foreach my $directory (@_) {
        my $recurse = ( $directory =~ m[//$] );
        # Remove all trailing /s, since directory name with trailing /
        #   is not always allowed:
        $directory =~ s[/+$][];
        # Similarly for MSWin reverse slash
        $directory =~ s[\\+$][];
	if ( ! -e $directory ){
            next;
	}
	elsif ( $recurse ){
            # Recursively search directory
            find( $find_action, $directory );
	}
        else {
            push @result, $directory;
	}
    }
    return @result;
}

#************************************************************

sub uniq 
# Read arguments, delete neighboring items that are identical,
# return array of results
{
    my @sort = ();
    my ($current, $prev);
    my $first = 1;
    while (@_)
    {
	$current = shift;
        if ($first || ($current ne $prev) )
	{
            push @sort, $current; 
            $prev = $current;
            $first = 0;
        }
    }
    return @sort;
}

#==================================================

sub uniq1 {
   # Usage: uniq1( strings )
   # Returns array of strings with duplicates later in list than
   # first occurence deleted.  Otherwise preserves order.

    my @strings = ();
    my %string_hash = ();

    foreach my $string (@_) {
        if (!exists( $string_hash{$string} )) { 
            $string_hash{$string} = 1;
            push @strings, $string; 
        }
    }
    return @strings;
}

#************************************************************

sub uniqs {
    # Usage: uniq2( strings )
    # Returns array of strings sorted and with duplicates deleted
    return uniq( sort @_ );
}

#************************************************************

sub ext {
    # Return extension of filename.  Extension includes the period
    my $file_name = $_[0];
    my ($base_name, $path, $ext) = fileparseA( $file_name );
    return $ext;
 }

#************************************************************

sub fileparseA {
    # Like fileparse but replace $path for current dir ('./' or '.\') by ''
    # Also default second argument to get normal extension.
    my $given = $_[0];
    my $pattern = '\.[^\.]*';
    if  ($#_ > 0 ) { $pattern = $_[1]; }
    my ($base_name, $path, $ext) = fileparse( $given, $pattern );
    if ( ($path eq './') || ($path eq '.\\') ) { 
        $path = ''; 
    }
    return ($base_name, $path, $ext);
 }

#************************************************************

sub fileparseB {
    # Like fileparse but with default second argument for normal extension
    my $given = $_[0];
    my $pattern = '\.[^\.]*';
    if  ($#_ > 0 ) { $pattern = $_[1]; }
    my ($base_name, $path, $ext) = fileparse( $given, $pattern );
    return ($base_name, $path, $ext);
 }

#************************************************************

sub split_search_path 
{
# Usage: &split_search_path( separator, default, string )
# Splits string by separator and returns array of the elements
# Allow empty last component.
# Replace empty terms by the default.
    my $separator = $_[0]; 
    my $default = $_[1]; 
    my $search_path = $_[2]; 
    my @list = split( /$separator/, $search_path);
    if ( $search_path =~ /$separator$/ ) {
        # If search path ends in a blank item, the split subroutine
	#    won't have picked it up.
        # So add it to the list by hand:
        push @list, "";
    }
    # Replace each blank argument (default) by current directory:
    for ($i = 0; $i <= $#list ; $i++ ) {
        if ($list[$i] eq "") {$list[$i] = $default;}
    }
    return @list;
}

#################################


sub tempfile1 {
    # Makes a temporary file of a unique name.  I could use file::temp,
    # but it is not present in all versions of perl
    # Filename is of form $tmpdir/$_[0]nnn$suffix, where nnn is an integer
    my $tmp_file_count = 0;
    my $prefix = $_[0];
    my $suffix = $_[1];
    while (1==1) {
        # Find a new temporary file, and make it.
        $tmp_file_count++;
        my $tmp_file = "${tmpdir}/${prefix}${tmp_file_count}${suffix}";
        if ( ! -e $tmp_file ) {
            open( TMP, ">$tmp_file" ) 
               or next;
            close(TMP);
            return $tmp_file;
	 }
     }
     die "$My_name.tempfile1: BUG TO ARRIVE HERE\n";
}

#################################

#************************************************************
#************************************************************
#      Process/subprocess routines

sub Run_msg {
    # Same as Run, but give message about my running
    warn_running( "Running '$_[0]'" );
    Run($_[0]);
}

sub Run {
# Usage: Run ("program arguments ");
#    or  Run ("start program arguments");
#    or  Run ("NONE program arguments");
# First form is just a call to system, and the routine returns after the 
#    program has finished executing.  
# Second form (with 'start') runs the program detached, as appropriate for
#    the operating system: It runs "program arguments &" on UNIX, and 
#    "start program arguments" on WIN95 and WINNT.  If multiple start
#    words are at the beginning of the command, the extra ones are removed.
# Third form (with 'NONE') does not run anything, but prints an error
#    message.  This is provided to allow program names defined in the
#    configuration to flag themselves as unimplemented.
# Return value is a list (pid, exitcode):
#   If process is spawned sucessfully, and I know the PID,
#       return (pid, 0),
#   else if process is spawned sucessfully, but I do not know the PID,
#       return (0, 0),
#   else if process is run, 
#       return (0, exitcode of process)
#   else (I fail to run the requested process)
#       return (0, suitable return code)
#   where return code is 1 if cmdline is null or begins with "NONE" (for
#                      an unimplemented command)
#                     or the return value of the system subroutine.


# Split command line into one word per element, separating words by 
#    one (OR MORE) spaces:
# The purpose of this is to identify latexmk-defined pseudocommands
#  'start' and 'NONE'.
# After dealing with them, the command line is reassembled
    my $cmd_line = $_[0];
    if ( $cmd_line eq '' ) {
	traceback( "$My_name: Bug OR configuration error\n".
                   "   In run of'$rule', attempt to run a null program" );
        return (0, 1);
    }
    if ( $cmd_line =~ /^start +/ ) {
        #warn "Before: '$cmd_line'\n";
        # Run detached.  How to do this depends on the OS
        # But first remove extra starts (which may have been inserted
        # to force a command to be run detached, when the command
	# already contained a "start").
        while ( $cmd_line =~ s/^start +// ) {}
        #warn "After: '$cmd_line'\n";
        return &Run_Detached( $cmd_line );
    }
    elsif ( $cmd_line =~ /^NONE/ ) {
        warn "$My_name: ",
             "Program not implemented for this version.  Command line:\n";
	warn "   '$cmd_line'\n";
        return (0, 1);
    }
    else { 
       # The command is given to system as a single argument, to force shell
       # metacharacters to be interpreted:
       return( 0, system( $cmd_line ) );
   }
}

#************************************************************

sub Run_Detached {
# Usage: Run_Detached ("program arguments ");
# Runs program detached.  Returns 0 on success, 1 on failure.
# Under UNIX use a trick to avoid the program being killed when the 
#    parent process, i.e., me, gets a ctrl/C, which is undesirable for pvc 
#    mode.  (The simplest method, system ("program arguments &"), makes the 
#    child process respond to the ctrl/C.)
# Return value is a list (pid, exitcode):
#   If process is spawned sucessfully, and I know the PID,
#       return (pid, 0),
#   else if process is spawned sucessfully, but I do not know the PID,
#       return (0, 0),
#   else if I fail to spawn a process
#       return (0, 1)

    my $cmd_line = $_[0];

##    warn "Running '$cmd_line' detached...\n";
    if ( $cmd_line =~ /^NONE / ) {
        warn "$My_name: ",
             "Program not implemented for this version.  Command line:\n";
	warn "   '$cmd_line'\n";
        return (0, 1);
    }

    if ( "$^O" eq "MSWin32" ){
        # Win95, WinNT, etc: Use MS's start command:
        return( 0, system( "start $cmd_line" ) );
    } else {
        # Assume anything else is UNIX or clone
        # For this purpose cygwin behaves like UNIX.
        ## warn "Run_Detached.UNIX: A\n";
        my $pid = fork();
        ## warn "Run_Detached.UNIX: B pid=$pid\n";
        if ( ! defined $pid ) {
            ## warn "Run_Detached.UNIX: C\n";
	    warn "$My_name: Could not fork to run the following command:\n";
            warn "   '$cmd_line'\n";
            return (0, 1);
	}
        elsif( $pid == 0 ){
           ## warn "Run_Detached.UNIX: D\n";
           # Forked child process arrives here
           # Insulate child process from interruption by ctrl/C to kill parent:
           #     setpgrp(0,0);
           # Perhaps this works if setpgrp doesn't exist 
           #    (and therefore gives fatal error):
           eval{ setpgrp(0,0);};
           exec( $cmd_line );
           # Exec never returns; it replaces current process by new process
           die "$My_name forked process: could not run the command\n",
               "  '$cmd_line'\n";
        }
        ##warn "Run_Detached.UNIX: E\n";
        # Original process arrives here
        return ($pid, 0);
    }
    # NEVER GET HERE.
    ##warn "Run_Detached.UNIX: F\n";
}

#************************************************************

sub find_process_id {
# find_process_id(string) finds id of process containing string and
# being run by the present user.  Typically the string will be the
# name of the process or part of its command line.
# On success, this subroutine returns the process ID.
# On failure, it returns 0.
# This subroutine only works on UNIX systems at the moment.

    if ( $pid_position < 0 ) {
        # I cannot do a ps on this system
        return (0);
    }

    my $looking_for = $_[0];
    my @ps_output = `$pscmd`;

# There may be multiple processes.  Find only latest, 
#   almost surely the one with the highest process number
# This will deal with cases like xdvi where a script is used to 
#   run the viewer and both the script and the actual viewer binary
#   have running processes.
    my @found = ();

    shift(@ps_output);  # Discard the header line from ps
    foreach (@ps_output)   {
	next unless ( /$looking_for/ ) ;
        my @ps_line = split (' ');
# OLD       return($ps_line[$pid_position]);
        push @found, $ps_line[$pid_position];
    }

    if ($#found < 0) {
       # No luck in finding the specified process.
       return(0);
    }
    @found = reverse sort @found;
    if ($diagnostics) {
       print "Found the following processes concerning '$looking_for'\n",
             "   @found\n",
             "   I will use $found[0]\n";
    }
    return $found[0];
}

#************************************************************
#************************************************************
#************************************************************

#   Directory stack routines

sub pushd {
    push @dir_stack, cwd();
    if ( $#_ > -1) { chdir $_[0]; }
}

#************************************************************

sub popd {
    if ($#dir_stack > -1 ) { chdir pop @dir_stack; }
}

#************************************************************

sub ifcd_popd {
    if ( $do_cd ) {
        warn "$My_name: Undoing directory change\n";
        &popd;
    }
}

#************************************************************

sub finish_dir_stack {
    while ($#dir_stack > -1 ) { &popd; }
}

#************************************************************
#************************************************************
#************************************************************
#************************************************************
#************************************************************
#************************************************************
#************************************************************
#************************************************************
