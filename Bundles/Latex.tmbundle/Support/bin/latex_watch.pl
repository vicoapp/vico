#! /usr/bin/perl

# LaTeX Watch,
	our $VERSION = "2.9";
#	- by Robin Houston, 2007, 2008.

# Usage: latex_watch.pl [ options ] file.tex
#
# Options:
#	--debug, -d				Pop up dialog boxes containing debugging info
#	--debug-to-console		Print debugging messages to stdout
#	--textmate-pid <pid>	Exit if the process <pid> disappears
#	--progressbar-pid <pid>	Kill <pid> after the document has been compiled for the 1st time
#	--ps					Use PostScript mode
#	--pdf					Use PDF mode (default)
#	--viewer				What previewer to use. Currently only used in PDF mode.

# Changelog now at end of file.

use strict;
use warnings;
use POSIX ();
use File::Copy 'copy';
use Getopt::Long qw(GetOptions :config no_auto_abbrev bundling);


#############
# Configure #
#############

print "Latex Watch $VERSION: ", (join$", map {/\s/ ? qq('$_') : $_} @ARGV), "\n";
init_environment();

my ($DEBUG, $textmate_pid, $progressbar_pid)
	= parse_command_line_options();
my ($filepath, $wd, $name, $dotname, $absolute_wd)
	= parse_file_path();

my %prefs = get_prefs();
my ($mode, $viewer_option, $viewer, $base_format, @tex);
	if ($prefs{engine} eq 'latex') {
		$mode = "PS";
		
		# Set $DISPLAY to a sensible default, it it's unset
		$ENV{DISPLAY} = ":0"
			if !defined $ENV{DISPLAY};
		
		applescript('tell application "X11" to launch');

		# Add Fink path
		$ENV{PATH} .= ":/sw/bin";

		@tex = qw(etex);
		$base_format = "latex";

		select_postscript_viewer();
	}
	elsif ($prefs{engine} eq "pdflatex") {
		$mode = "PDF";
		
		$base_format="pdflatex";
		@tex = qw(pdfetex -output-format pdf);

		if ($prefs{viewer} eq 'TextMate') {
			print "Latex Watch: Cannot use TextMate to preview. Using default viewer instead.\n";
			$viewer = select_pdf_viewer();
		}
		else {
			$viewer = select_pdf_viewer($prefs{viewer});
		}
	}


# Remove the 'hide extension' attribute, or else ping_pdf_viewer_texshop will fail
fail_unless_system("SetFile", "-a", "e", "$name.tex")
    if $viewer eq "TeXShop";

init_cleanup();
main_loop();

##################
# TextMate prefs #
##################

{
	my ($prefs_file, $prefs);
	
	sub init_prefs {
		eval { require Foundation };
		if ($@ ne "") {
			fail("Couldn't load Foundation.pm",
				"The Perl module Foundation.pm could not be loaded. If you have been foolish enough to remove the default Perl interpreter (/usr/bin/perl), you must install PerlObjCBridge manually.\n\n$@\0");
		}
	
	    $prefs_file = "$ENV{HOME}/Library/Preferences/com.macromates.textmate.plist";
	    $prefs = NSDictionary->dictionaryWithContentsOfFile_($prefs_file);
	}

    sub getPreference {
        my ($prefName, $default) = @_;
		init_prefs() unless defined $prefs;
		
        my $pref = $prefs->objectForKey_($prefName);
        return ( ref($pref) eq 'NSCFString'
            ? $pref->UTF8String()
            : $default)
    }
}

sub get_prefs {
	return (
		engine  => getPreference(latexEngine => "pdflatex"),
		options => getPreference(latexEngineOptions => ""),
		viewer  => getPreference(latexViewer => "TextMate"),
	);
}

##################
# Setup routines #
##################

sub init_environment {
	# Add MacTeX and teTeX paths (in that order)
	$ENV{PATH} .= ":/usr/texbin";
	$ENV{PATH} .= ":/usr/local/teTeX/bin/".`/usr/local/teTeX/bin/highesttexbin.pl`
		if -x "/usr/local/teTeX/bin/highesttexbin.pl";

	# If TM_SUPPORT_PATH is undefined, make a plausible guess.
	# (Useful for running this script from outside TextMate.)
	$ENV{TM_SUPPORT_PATH} = "/Applications/TextMate.app/Contents/SharedSupport/Support"
		if !defined $ENV{TM_SUPPORT_PATH};

	# Add TextMate support paths
	$ENV{PATH} .= ":$ENV{TM_SUPPORT_PATH}/bin";
	$ENV{PATH} .= ":$ENV{TM_BUNDLE_SUPPORT}/bin"
		if defined $ENV{TM_BUNDLE_SUPPORT};

	# Location of CocoaDialog binary
	init_CocoaDialog("$ENV{TM_SUPPORT_PATH}/bin/CocoaDialog.app/Contents/MacOS/CocoaDialog");

	# Include the bundle's tex tree in the search path: we have a local copy of pdfsync.sty.
	$ENV{TEXINPUTS} = `kpsewhich -progname latex --expand-var '\$TEXINPUTS'`;
	chomp $ENV{TEXINPUTS};

	$ENV{TEXINPUTS} .= ":$ENV{TM_BUNDLE_SUPPORT}/tex//"
		if defined $ENV{TM_BUNDLE_SUPPORT};
}

sub parse_command_line_options {
	my ($DEBUG, $textmate_pid, $progressbar_pid);

	GetOptions(
		'debug|d|debug-to-console' => \$DEBUG,
		'textmate-pid=i' => \$textmate_pid,
		'progressbar-pid=i' => \$progressbar_pid,
	)
		or fail("Failed to process command-line options", "Check the console for details");
	
	return ($DEBUG, $textmate_pid, $progressbar_pid);
}

sub parse_file_path {
	my $filepath = shift(@ARGV);
	fail("File not saved", "You must save the file before it can be watched")
		if !defined($filepath) or $filepath eq "";

	# Parse and verify file path
	my ($wd, $name, $dotname, $absolute_wd);
	if ($filepath =~ m!(.*)/!) {
		$wd = $1;
		my $fullname = $';
		if ($fullname =~ /\.tex\z/) {
			$name = $`;
			$dotname = ".$name";
			$dotname =~ y/\01-\040"\\$%&/_/;    # Any other chars that cause problems?
		}
		else {
			fail("Filename doesn't end in .tex",
				"The filename ($fullname) does not end with the .tex extension");
		}
	}
	else {
		fail("Path does not contain /", "The file path ($filepath) does not contain a '/'");
	}
	if (! -W $wd) {
		fail("Directory not writeable", "I can't write to the directory $wd");
	}

	# Use a relative path, because TeX has problems with special characters in the pathname
	chdir($absolute_wd = $wd);
	$wd = ".";
	
	return ($filepath, $wd, $name, $dotname, $absolute_wd);
}


# Persistent state
my ($preamble, $bogus_preamble, %preamble_mtimes, %body_mtimes, $cleanup_viewer, $ping_viewer);


#############
# Main loop #
#############

sub main_loop {
	my $ping_counter = 10;
	while(1) {
		if (document_has_changed()) {
			debug_msg("Reloading file");
			reload();
			compile() and view();
			if (defined ($progressbar_pid)) {
				debug_msg("Closing progress bar window ($progressbar_pid)");
				kill(15, $progressbar_pid) or fail("Failed to close progress bar window: $!");
				undef $progressbar_pid;
			}
		}

		# Every 5 times through the loop, check if viewer and/or TextMate are still open
		if (defined($ping_viewer) and 0 == $ping_counter--) {
			$ping_counter = 5;
			if (not $ping_viewer->()) {
				debug_msg("Viewer appears to have been closed. Exiting.");
				exit;
			}

			process_is_running($textmate_pid)
				or do {
					debug_msg("Textmate appears to have been closed. Exiting.");
					exit
				};
		}

		select(undef, undef, undef, 0.5); # Sleep for 0.5 seconds
	}
}

####################
# Cleanup routines #
####################

# Clean up if we're interrupted or die
sub clean_up {
	debug_msg("Cleaning up");
	unlink(map("$wd/$dotname.$_", qw(ini fmt fls tex dvi ps pdf pdfsync bbl log)))
		if defined($wd) and defined($dotname);
	$cleanup_viewer->() if defined $cleanup_viewer;
	if (defined ($progressbar_pid)) {
		debug_msg("Closing progress bar window as part of cleanup");
		kill(9, $progressbar_pid);
	}
	if (defined $name) {
		unlink "$wd/.$name.watcher_pid"	# Do this last
			or debug_msg("Failed to unlink $wd/.$name.watcher_pid: $!");
	}
}
END { clean_up() }
sub init_cleanup {
	$SIG{INT} = $SIG{TERM} = sub { exit(0) };
}

######################
# Main loop routines #
######################

sub process_is_running {
	my ($pid) = @_;
	my $procinfo = `ps -xp $pid`;
	return ($procinfo =~ y/\n// > 1)
}

# Check whether the document, or any of its dependencies, has changed
sub document_has_changed {
	return 1 if keys(%preamble_mtimes) == 0;

	my $change = 0;
	foreach_modified_file(\%preamble_mtimes, sub {
		my ($file) = @_;
		debug_msg("The preamble file '$file' has changed. Forcing format regeneration.");
		undef $preamble;	# Force format regeneration
		$change = 1;
	});
	return 1 if $change;
	
	foreach_modified_file(\%body_mtimes, sub {
		my ($file) = @_;
		debug_msg("The file '$file' has changed.");
		$change = 1;
	});

	return $change;
}

sub foreach_modified_file {
	my ($hash, $callback) = @_;
	
	while (my ($file, $mtime) = each %$hash) {
		my $current_mtime = -M $file;
		if (!defined($current_mtime)	# Error: probably input file moved or deleted
		  || $current_mtime < $mtime)
		{
			if (defined $current_mtime) {
				$hash->{$file} = $current_mtime;
			}
			else {
				delete $hash->{$file};
			}
			$callback->($file);
		}
	}
}

sub reload {
	open (my $f, "<", $filepath)
		or fail ("Failed to open file",
			"I couldn't open the file '$filepath' for reading: $!");

	my ($new_preamble, $body);
	while (<$f>) {
		if (/(.*)(\\begin\s*\{(?:document)\}.*)/) {
			$new_preamble .= $1;
			$body = $2;
		}
		elsif (defined $body) {
			$body .= $_
		}
		else {
			$new_preamble .= $_
		}
	}
	chomp ($new_preamble)
		or fail ("No \\begin{document} found",
			"I couldn't find the command \\begin{document} in your file");

	if (!defined($preamble) or $new_preamble ne $preamble) {
		debug_msg("Preamble has changed. Regenerating format.");
		regenerate_format($new_preamble);
	}

	save_body($body);

	close $f
		or fail ("Failed to close file",
			"I got an error closing the file '$filepath': $!");
}

sub regenerate_format {
	($preamble) = @_;
	
	# Create bogus preamble, so the line numbers match for PDFSync
	$bogus_preamble = "%\n" x ($preamble =~ y/\n//);
	
	open (my $ini, ">", "$wd/$dotname.ini")
		or fail("Failed to create file",
			"The file '$wd/$dotname.ini' could not be opened for writing: $!");
	print $ini ($preamble, "\n\\dump\n");
	close $ini
		or fail("Failed to close file",
			"The file '$wd/$dotname.ini' gave an error on closing: $!");

	copy("$wd/$name.bbl", "$wd/$dotname.bbl"); # Ignore errors
	unlink("$wd/$dotname.fmt"); # Ignore errors

	fail_unless_system(@tex, "-ini",
		-interaction => "batchmode",
		"-recorder", "&".$base_format,
		qq("$wd/$dotname.ini"),
	sub {
		my $button = cocoa_dialog("msgbox",
			"--button3" => "Stop Watching",
			"--button1" => "Show Log",
			"--button2" => "Ignore Error",
			"--title"   => "LaTeX Watch Error: Failed to process preamble",
			"--informative-text" => "Errors were encountered while processing the preamble "
				. "of your document. What would you like to do?"
		);
		debug_msg("Button $button pressed");
		if ($button == 1) {
			show_log();
		}
		elsif ($button == 3) {
			exit;
		}
	});
	parse_file_list(\%preamble_mtimes);
}

sub parse_file_list {
	my ($hash) = @_;
	
	open(my $f, "<", "$wd/$dotname.fls")
		or fail("Failed to open file list", "I couldn't open the file '$wd/$dotname.fls': $!");
	local $/ = "\n";
	
	my %updated_files;
	while (<$f>) {
		if (/^(INPUT|OUTPUT) (.*)/) {
			my ($t, $f) = ($1, $2);
			
			next if $f =~ m!\.(?:fd|tfm|aux|ini)$!; # Skip font files, .aux and .ini files
			$f =~ s/(^|\Q$wd\E\/)\Q$dotname.\E(tex|bbl|aux)/$1$name.$2/;
			$f = "$wd/$f" if $f !~ m(/);
			
			my $mtime = -M($f);
			if ($t eq 'INPUT') {
				if (defined $mtime) {
					if (!exists $hash->{$f}) {
						debug_msg("[x] $f");
						$hash->{$f} = $mtime
					}
				}
				else {
					# Probably the file no longer exists. Warn but continue.
					print("[LaTeX Watch] ",
						"Failed to find the modification time of the file '$f'".
						" while parsing the file list: $!\n");
				}
			}
			else {	# $t eq 'OUTPUT'
				$updated_files{$f} = $mtime;
			}
		}
		elsif (!/^PWD /) {
			debug_msg("Unrecognised line in file list: $_")
		}
	}
	
	while (my ($f, $mtime) = each %updated_files) {
		$preamble_mtimes{$f} = $mtime if exists $preamble_mtimes{$f} and defined $mtime;
		$hash->{$f} = $mtime if exists $hash->{$f} and defined $mtime;
	}
	debug_msg("Parsed file list: found ".keys(%$hash)." files");
}

sub save_body {
	open (my $f, ">", "$wd/$dotname.tex")
		or fail("Failed to create file",
			"I couldn't create the file '$wd/$dotname.tex': $!");

	print $f ($bogus_preamble, @_);

	close($f)
		or fail("Failed to close file",
			"I got an error on closing the file '$wd/$dotname.tex': $!");
}

my ($compiled_document, $compiled_document_name);
sub compile {
	copy("$wd/$name.bbl", "$wd/$dotname.bbl"); # Ignore errors
	copy("$wd/$name.aux", "$wd/$dotname.aux"); # Ignore errors
	
	unlink "$wd/$dotname.dvi";
	my $error = 0;
	fail_unless_system(@tex,
		-interaction => "batchmode",
		"-recorder",
		"&$dotname", qq("$wd/$dotname.tex"),
	sub {
		if ($? ==1 || $? == 2) {
			# An error in the document
			offer_to_show_log();
			$error = 1;
		}
		else {
			fail("Failed to compile document",
				"The command '@_' exited with unexpected error code $?");
		}
	});
	
	parse_file_list(\%body_mtimes);
	
	# Do this even in PDF mode, so that bibtex picks it up
	rename("$wd/$dotname.aux", "$wd/$name.aux") unless $error;

	if ($mode eq 'PS') {
		# The DVI file might not have been generated, if there was a serious error
		if (-e "$wd/$dotname.dvi") {
			fail_unless_system("dvips", "$wd/$dotname.dvi", "-o");
			$compiled_document      = "$wd/$dotname.ps";
			$compiled_document_name = "$dotname.ps";
			return 1; # Success!
		}
		else {
			return;   # Failure
		}
	}
	else { # PDF mode
		if (-e "$wd/$dotname.pdf") {
			munge_pdfsync_file() if -e "$wd/$dotname.pdfsync";
			rename("$wd/$dotname.pdf", "$wd/$name.pdf");
			$compiled_document      = "$wd/$name.pdf";
			$compiled_document_name = "$name.pdf";
			return 1; # Success!
		}
		else {
			return;   # Failure
		}
	}
}

sub munge_pdfsync_file {
	my $contents;
	open(my $f, "<", "$wd/$dotname.pdfsync")
		or fail("Failed to open pdfsync file",
			"I failed to read the file $dotname.pdfsync: $!");
	for (my $n=0; my $c = read($f, $contents, 4096, $n); $n += $c) { }
	close $f;
	
	$contents =~ s/^(\(?)\Q$dotname\E((\.tex)?)$/$1$name$2/mg;
	
	open ($f, ">", "$wd/$name.pdfsync")
		or fail("Failed to open pdfsync file",
			"I failed to write to the file $name.pdfsync: $!");
	print $f $contents;
	close $f;
}

sub offer_to_show_log {
	my $button = cocoa_dialog("msgbox",
			"--title" => "LaTeX Watch: compilation error",
			"--text" => "Error compiling $name.tex",
			"--informative-text" => "TeX gave an error compiling the file. Shall I show the log?",
			"--button1" => "Show Log",
			"--button2" => "Don’t Show");
	show_log() if $button == 1;
}

sub show_log {
	# OK button pressed
	fail_unless_system("mate", "$wd/$dotname.log");
}

#####################
# Viewer invocation #
#####################

my ($start_viewer, $refresh_viewer, $viewer_id);

sub view {
	if (defined($viewer_id)) {
		$refresh_viewer->($viewer_id)
			if defined($refresh_viewer);
	}
	else {
		$viewer_id = $start_viewer->()
	}
}

####################
# Viewer selection #
####################

# # # # # # # # # # #
# PostScript viewer #
# # # # # # # # # # #

my (@ps_viewer, $hup_viewer);
sub select_postscript_viewer {
	# PostScript viewer: try to discover the right options to use with
	#   whichever version of gv we find.
	$hup_viewer = 1;
	{
		my $gv_version = `gv --version 2>/dev/null`;
		if ($? == -1 or $? & 127) {
			fail("Failed to execute gv ($?): $!")
		}
		elsif ($?) {
			# Assume that gv did not understand the --version option,
			# and that it is therefore a pre-3.6.0 version
			@ps_viewer = qw(gv -spartan -scale 1 -nocenter -antialias -nowatch);
		}
		elsif ($gv_version =~ /^gv 3.6.0$/) {
			# This version is hopelessly broken. Give up.
			fail("Broken GV detected",
				"You appear to have gv version 3.6.0. "
				."This version is hopelessly broken. I recommend you "
				."upgrade to 3.6.2, or (even better) downgrade to 3.5.8, "
				."which is currently the most stable version")
		}
		elsif ($gv_version =~ /^gv 3.6.1$/) {
			# Version 3.6.1 of GV has a bug that means it
			# dies if it receives a HUP signal. Therefore we execute it
			# in watch mode, and don't send a HUP.
			#
			# It also has a bug that means the --scale option causes it
			# not to open the specified document, and show a blank screen.
			@ps_viewer = qw(gv --spartan --nocenter --antialias --watch);
			$hup_viewer = 0;
		}
		elsif ($gv_version =~ /^gv 3.6.2$/) {
			# The --scale bug has still not been fixed in 3.6.2,
			# but the HUP one has.
			@ps_viewer = qw(gv --spartan --nocenter --antialias --nowatch);
		}
		else {
			# Hope for the best, with future versions!
			# (I have reported the bug, so with any luck it'll be fixed?)
			@ps_viewer = qw(gv --spartan --scale 1 --nocenter --antialias --nowatch);
		}
	}

	$start_viewer   = \&start_postscript_viewer;
	$refresh_viewer = \&refresh_postscript_viewer;
	$cleanup_viewer = \&cleanup_postscript_viewer;
	$ping_viewer    = \&ping_postscript_viewer;
	debug_msg("PostScript viewer selected", @ps_viewer);
}

sub start_postscript_viewer {
	my $pid = fork();
	if ($pid) {
		# In parent
		return $pid;
	}
	else {
		# In child
		POSIX::setsid(); # detach from terminal
		close STDOUT; open(STDOUT, ">", "/dev/null");
		close STDERR; open(STDERR, ">", "/dev/console");
		
		debug_msg("Starting PostScript viewer ($$)");
		
		exec(@ps_viewer, $compiled_document)
			or fail("Failed to start PostScript viewer",
				"I failed to run the PostScript viewer (@ps_viewer): $!");
	}
}

sub refresh_postscript_viewer {
	if ($hup_viewer) {
		kill(1, $viewer_id)
			or fail("Failed to signal viewer",
				"I failed to signal the PostScript viewer (PID $viewer_id) to reload: $!");
	}
}

sub cleanup_postscript_viewer {
	kill(2, $viewer_id) if defined $viewer_id
}

sub ping_postscript_viewer {
	if ( defined $viewer_id and waitpid($viewer_id, POSIX::WNOHANG()) ) {
		my $r = $?;
		if ($r & 127) {
			fail("Viewer failed",
				"The PostScript viewer died with signal ".($r & 127));
		}
		elsif ($r >>= 8) {
			fail("Viewer failed",
				"The PostScript viewer exited with an error (error code $r)");
		}
		return;   # Failed to ping
	}
	else {
		return 1; # Pinged successfully
	}
}

# # # # # # # #
# PDF Viewer  #
# # # # # # # #

my $pdf_viewer_app;

sub select_pdf_viewer {
	my ($viewer) = @_;
	$viewer ||= "TeXShop"; 		# TeXShop is the default

	debug_msg("PDF Viewer selected ($viewer)");

	# These are the default, generic routines
	$start_viewer   = \&start_pdf_viewer;
	$ping_viewer    = \&ping_pdf_viewer;
	$cleanup_viewer = \&cleanup_pdf_viewer;
	$pdf_viewer_app = $viewer;
	
	if ($viewer eq "TeXShop") {
		$start_viewer   = \&start_pdf_viewer_texshop;
		$refresh_viewer = \&refresh_pdf_viewer_texshop;
		$ping_viewer    = \&ping_pdf_viewer_texshop;
		$cleanup_viewer = \&cleanup_pdf_viewer_texshop;
	}
    elsif ($viewer eq "TeXniscope") {
		$start_viewer   = \&start_pdf_viewer_texniscope;
		$refresh_viewer = \&refresh_pdf_viewer_texniscope;
	}
	elsif ($viewer eq "Skim") {
		$refresh_viewer = \&refresh_pdf_viewer_skim;
	}

	return $viewer;
}

# TexShop

# We use open_for_externaleditor on the .tex file, rather than just opening the .pdf.
# In principle, either ought to work (hence the generic routines could be used for
# everything other than refresh) but at the time of writing the current version of
# TeXShop has a bug with the effect that, if certain encodings (e.g. UTF-8)
# are specified in the TeXShop preferences, opening a PDF file directly will trigger
# a spurious encoding warning. So this is a workaround.

sub start_pdf_viewer_texshop {
	debug_msg("Starting PDF viewer (TeXShop) for file", "Opening file: $compiled_document");
	applescript (
		qq(tell application "TeXShop" ).
		qq(to open_for_externaleditor at ).
		quote_applescript("$absolute_wd/$name.tex"));
	$viewer_id = "TeXShop";
}

sub refresh_pdf_viewer_texshop {
	debug_msg("Refreshing PDF viewer (TeXShop)");
	applescript(
		qq(tell document ).quote_applescript("$name.tex").
		qq( of application "TeXShop" to refreshpdf));
}

my $ping_failed;
sub ping_pdf_viewer_texshop {
	my $r = check_open($pdf_viewer_app, "$name.tex");
	$ping_failed = 1 if !$r;
	return $r;
}

sub cleanup_pdf_viewer_texshop {
	return if $ping_failed;
	debug_msg("Closing document in PDF viewer ($pdf_viewer_app)");
	applescript_ignoring_errors(
		qq(tell application ).quote_applescript($pdf_viewer_app).
		qq( to close document ).quote_applescript("$name.tex"));
}

# TeXniscope

sub start_pdf_viewer_texniscope {
	my $doc = $compiled_document;
	$doc =~ s!^\./!POSIX::getcwd() . "/"!e;
	debug_msg("Starting PDF viewer (TeXniscope)", "Opening file: $doc");
	applescript (
		qq(tell application "TeXniscope").
		qq{ to open file ((POSIX file }.quote_applescript($doc).
			qq{) as string)});
	$viewer_id = "TeXniscope";
}

sub refresh_pdf_viewer_texniscope {
	debug_msg("Refreshing PDF viewer (TeXniscope)");
	applescript(
		qq(tell document ).quote_applescript("$name.pdf").
		qq( of application "TeXniscope" to refresh))
}

# Skim

sub refresh_pdf_viewer_skim {
	debug_msg("Refreshing PDF viewer (Skim)");
	# We ignore errors, because this is only supported in Skim 0.5 and later
	applescript_ignoring_errors(
		qq(tell application "Skim").
		qq( to revert document ).quote_applescript("$name.pdf"))
}

# Generic routines that should work for any viewer

sub start_pdf_viewer {
	fail_unless_system("open", "-a", $pdf_viewer_app, $compiled_document);
}

sub ping_pdf_viewer {
	my $r = check_open($pdf_viewer_app, $compiled_document_name);
	$ping_failed = 1 if !$r;
	return $r;
}

sub cleanup_pdf_viewer {
	return if $ping_failed;
	debug_msg("Closing document in PDF viewer ($pdf_viewer_app)");
	applescript_ignoring_errors(
		qq(tell application ).quote_applescript($pdf_viewer_app).
		qq( to close document ).quote_applescript($compiled_document_name))
	if defined $compiled_document_name;
}


####################
# Utility routines #
####################

# Explain what's happening (if we're debugging)
sub debug_msg {
	print "Latex Watch INFO: @_\n" if $DEBUG;
}

my $CocoaDialog;
sub init_CocoaDialog {
	($CocoaDialog) = @_;
}

# Display an error dialog and exit with exit-code 1
sub fail {
	my ($message, $explanation) = @_;
	system($CocoaDialog, "msgbox",
		"--button1" => "Cancel",
		"--title" => "LaTeX Watch error",
		"--text" => "Error: $message",
		"--informative-text" => "$explanation.");
	exit(1)
}

sub fail_unless_system {
	my $error_callback;
	if (ref($_[-1]) eq 'CODE') {
		$error_callback = pop;
	}
	debug_msg("Executing ", @_);
	system(@_);
	if ($? == -1) {
		fail("Failed to execute $_[0]",
			"The command '@_' failed to execute: $!");
	}
	elsif ($? & 127) {
		fail("Command failed",
			"The command '@_' caused $_[0] to die with signal ".($? & 127));
	}
	elsif ($? >>= 8) {
		if (defined $error_callback) {
			$error_callback->(@_)
		}
		else {
			fail("Command failed",
				"The command '@_' failed (error code $?)");
		}
	}
}

# Put up a dialog box, and return the result
sub cocoa_dialog {
	pipe (my $rh, my $wh);
	if (my $pid = fork()) {
		# Parent
		local $/ = "\n";
		my $button = <$rh>;
		waitpid($pid, 0);
 		if ($?) {
			# If we failed to show the dialog, there's not much sense
			# in trying to put up another dialog to explain what happened!
			# Print a message to the console.
			print "LaTeX Watch: Failed to display dialog box ($?): @_\n";
			debug_msg("Failed to display dialog box");
		}
		else {
			debug_msg("cocoa_dialog: Button $button");
			return $button;
		}
	}
	else {
		close(STDOUT);
		open(STDOUT, ">&", $wh);	# Talk to the pipe!

		# Enclose the exec command in a block, to avoid the warning about code following exec.
		{exec($CocoaDialog, @_)}

		# If there's an error, just exit with a non-zero code.
		debug_msg("Child process failed to offer to show log.");
		POSIX::_exit(2); # Use _exit so we don't trigger cleanup code.
	}
}

sub applescript {
	# We could do this much more efficiently using Mac::OSA
	# but that's only preinstalled on 10.4 and later.

	fail_unless_system("osascript", "-e", @_)
}

sub applescript_ignoring_errors {
	debug_msg("Applescript: ", @_);
	system("osascript", "-e", @_)
}

sub quote_applescript {
	my ($str) = @_;
	$str =~ s/([\\\"])/\\$1/g;
	return qq("$str");
}

sub check_open {
	my $still_open = 1;
	fail_unless_system("check_open", ($DEBUG ? "-q" : "-s"), @_, sub {
		fail("check_open failed. See console for details") if $? == 255;
		
		 # If check_open can't tell, then we err on the side of caution.
		$still_open = 0 unless $? == 3;
	});
	return $still_open;
}

__END__

BUGS?
	- Spews too much information to the console

LIMITATIONS:
	- Does not work if \begin{document} is in an included file
	- Cannot specify different modes per file.
	- Only works with latex, not xelatex, ConTeXt, etc.

FUTURE:
	- (2.x) Support DVI route without GV, warning where appropriate.
	  [If GV not installed, fall back to something else.]
	- (2.x) Parse %!TEX TS-program lines.
	- (2.x) Support xetex (and xelatex).
	- (2.x) If TM_LATEX_VIEWER unset, sniff available viewers and pick one.
			(If it's set to "Preview", warn that Preview sucks and look for another.)
	- (3.0) Incorporate some latexmk-style logic,
	  so that if refs or cites are out-dated: the display is
	  updated after the first compile, but then subsequent
	  operations are automatically initiated, and the display
	  updated when they're finished.

Changes
1.1:
	- Include $! in error message if ps_viewer fails to start
	- run etex in batchmode
	- deal sensibly with compilation errors (don't just quit, offer to show log)
	- use 'gv -scale 1' (x 1.414) instead of '-scale 2' (x 2)

1.2:
	- Add Fink path (/sw/bin) to $PATH
	- Improved error handling in the command
	- don't assume this script is executable
	- work if perl is in PATH, even if it's not in /usr/bin

1.3:
	- Send errors to /dev/console rather than /tmp/out. (Thanks, Allan!)
	- Add default MacTeX location to PATH
	- support GV 3.6.[0-1], which has a different command-line syntax (!)
		(this is fixed in 3.6.2, but some users have 3.6.[01])
	- Move changelog to end of file
	- Handle preamble errors better
	- Take file path and switches on the command-line

1.4:
	- Set $/ in cocoa_dialog, or it won't work when called from reload().

1.5:
	- Add --debug-to-console option
	- Add --textmate-pid option
	- Throw an error if command-line options can't be parsed
	- Detect changes in files referenced by preamble
	- Detect changes in files referenced by body
	- Set $DISPLAY to ":0" if it isn't already set

2.0:
	- Add PDF support, using TeXShop as the viewer
	- Add TeXniscope support

2.1:
	- Add PDFView support: in fact, add rudimentary support for arbitrary
	  viewer applications.
	- Don't attempt to close doc on cleanup, if we know it's already been closed.
	- Add -s switch to check_open, and pass it when not debugging.
	- Remove TM_LATEX_WATCH_VIEWER. Always use TM_LATEX_VIEWER instead.
	- Use TM_LATEX_PROGRAM to decide how to behave, instead of TM_LATEX_WATCH_MODE.

2.2:
	- Change button names on error dialog to 'Show Log' and 'Don't Show'.
	- Progress bar on initial compilation.
	- Add .pdf and .pdfsync to the list of files to clean up.
	- Don't skip dotfiles, so e.g. display will update if citation details change.
	- If in PDF mode, use pdfetex even for the format generation. This allows
	  the graphics package (and other packages, potentially) to assume the correct
	  mode.
	- Help file.
	- Support for the Skim previewer.
	- pdfsync synchronisation now works.
	- Include a copy of pdfsync in the bundle, because the LaTeX bundle
	  has its own pdfsync, so users might be confused if it works with ⌘R
	  but not with Watch. For the same reason, I have included the same
	  version that the LaTeX bundle uses, rather than the latest version,
	  since pdfsync 1.0 seems to conflict with more packages (e.g. diagrams).

2.3:
	- Rename the PDF file after generation, to prevent viewers from attempting
	  to reload it when it's partially generated.
	- As a side-effect of the above, two-way syncing now works with Skim!
	- Improve change detection logic, so that changes made during compilation
	  are not ignored.
	- Fix recently-introduced bug that caused incorrect watcher_pid to be recorded.

2.4:
	- Warn if PostScript mode is used with a non-default previewer.
	- Expand the help file a little.
	- With TeXShop, use open_for_externaleditor on the .tex file, to work
	  around an encoding-related bug in TeXShop.
	- Add a refresh command for Skim, which works in Skim 0.5 and later.
	  This is just as well, since the automatic file-change checking is broken
	  in Skim 0.5!

2.5:
	- Delete .watcher_pid file on exit. (I think this was broken by 2.3.)
	- Fix bug introduced in 2.4 that broke TeXShop updating.
	- Use a sanitised name for the .foo.* files, because format names containing
	  spaces don't seem to work (so we would fail for filenames with spaces in).
	- Change into the working directory, rather than using the full path, to
	  avoid problems caused by special characters in the name of some ancestor
	  directory.
	- Quote Applescript strings, so that filenames containing special characters
	  (backslash and double quote) will not cause Applescript errors. (They do
	  still cause problems with PDFSync in Skim: see
   https://sourceforge.net/tracker/?func=detail&atid=941981&aid=1753415&group_id=192583)
	- Catch the obscure case where the filename ends in ".tex\n", which
	  would previously cause mysterious-looking problems.
	- Remove the 'hide extension' attribute on the .tex file, if TeXShop is
	  used as the viewer, otherwise updating will fail for interesting reasons
	  that I won't go into here.

2.6:
    - Suppress warnings when no viewer is explicitly selected; make sure the
      'hide extension' attribute is removed in that case too.
	- Integrate with Brad's new version of the LaTeX bundle: use the new prefs
	  system.

2.7:
	- Fix TeXniscope support.
	- Deal more robustly with files that are written as well as read during processing
	  (previously this could cause an infinite update loop)

2.8:
	- Locate '\begin{document}' in a more flexible way.
	- If an input file disappears, remove it from the watch list (otherwise it will
	  recompiling the document in an endless loop).

2.9:
	- The loop-prevention code added in 2.7 did not work correctly in the case where
	  a file is read from the preamble and written from the document body. This arises
	  when the svn-multi package is used, for example. It should now work correctly.
