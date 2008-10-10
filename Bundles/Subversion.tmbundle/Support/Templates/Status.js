//
//  JavaScript library for SVN status.
//	Thomas Aylott and Chris Thomas.
//
//	Requires global variables StatusMap and ENV.
//
//	ENV must be set up with:
//
//		PATH
//      TM_SUPPORT_PATH
//		TM_BUNDLE_SUPPORT
//      CommitWindow
//      TM_SVN
//		TM_RUBY
//

the_filename    = null;
the_id          = null;
the_displayname = null;
the_new_status  = null;

function escapeHTML(string) {
	return(string.replace(/&/g,'&amp;')
				.replace(/>/g,'&gt;')
				.replace(/</g,'&lt;')
				.replace(/"/g,'&quot;'));                                                                      
};

function adjustActionButtonsForStatusChange( firstLetterOfNewStatus, id )
{
	// FIXME: This does not seem to work
	add_button		= document.getElementById( 'button_add' + id)
	remove_button	= document.getElementById( 'button_remove' + id)
	revert_button	= document.getElementById( 'button_revert' + id)
	diff_button		= document.getElementById( 'button_diff' + id)
	
	switch(firstLetterOfNewStatus)
	{
		case 'A':
		case 'D':
			add_button.style.display	= 'none'
			remove_button.style.display	= 'none'
			revert_button.style.display	= 'inline'
			diff_button.style.display	= 'none'
			break
		case '?':
		case '!':
			add_button.style.display	= 'inline'
			remove_button.style.display	= 'inline'
			revert_button.style.display	= 'none'
			diff_button.style.display	= 'none'
			break
		default:
			add_button.style.display	= 'none'
			remove_button.style.display	= 'none'
			revert_button.style.display	= 'inline'
			diff_button.style.display	= 'inline'
			break
	}
}

function svnCommand(cmd, id, statusString, className){
	TextMate.isBusy = true;

	results			= TextMate.system('LC_CTYPE=en_US.UTF-8 ' + cmd, null)
	outputString	= results.outputString;
	errorString		= results.errorString;
	errorCode		= results.status;

	displayCommandOutput('error', 'error', errorString);
	displayCommandOutput('info', 'info', outputString);
	
	if(errorCode == 0 && id != null)
	{
		status_element = document.getElementById('status'+id)
		status_element.innerHTML = statusString;
		status_element.className = 'status_col ' + className;
		
		adjustActionButtonsForStatusChange(statusString.charAt(0), id)
	}

	TextMate.isBusy = false;
}

function displayCommandOutput(id, className, string){
	
	if(string != null && string != '')
	{
		console_div = document.getElementById('console')
		console_div.style.display = 'inline';
		
		document.getElementById('commandOutput').innerHTML += escapeHTML(string).replace(/\n/, '<br>');
	}
}

function svnCommit(){
		
	cmd  = 'cd "${TM_PROJECT_DIRECTORY:-$TM_DIRECTORY}"; '
	cmd += '"${TM_RUBY:-ruby}" -- "$TM_BUNDLE_SUPPORT/svn_commit.rb" --output=plaintext "' + WorkPaths.join('" "') + '"'

//	displayCommandOutput('info', 'info', cmd);
//	document.getElementById('commandOutput').innerHTML = TextMate.system(cmd, null).outputString + ' \\n'
	
	TextMate.isBusy = true
	myCommand = TextMate.system(cmd, function (task) { TextMate.isBusy = false; });
	myCommand.onreadoutput = svnReadOutput;
	myCommand.onreaderror = svnReadError;
};

function svnAddFile(filename,id){
	
	displayCommandOutput('info', 'info', 'Adding ' + filename + "\n")
	
	cmd = ENV['TM_SVN'] + ' add ' + filename + ' 2>&1'

	svnCommand(cmd, id, 'A', StatusMap['A'])
};

function svnRevertFile(filename, id, displayname){
	
	statusElement = document.getElementById('status'+id)
	statusText = statusElement.firstChild.nodeValue
	
	svnRevertFileConfirm(filename,id, displayname)
};

function completedTask(task){
	
	if (task.status == 0)
	{
		if(the_new_status == '-'){document.getElementById('status'+the_id).className = 'status_col ' + StatusMap['-']};
		if(the_new_status == 'D'){document.getElementById('status'+the_id).className = 'status_col ' + StatusMap['D']};
		document.getElementById('status'+the_id).innerHTML = the_new_status;

		adjustActionButtonsForStatusChange(the_new_status.charAt(0), id)
	}

	the_filename    = null;
	the_id          = null;
	the_displayname = null;
	the_new_status  = null;	

	TextMate.isBusy = false;
}

function svnRevertFileConfirm(filename,id,displayname){
	the_filename    = filename;
	the_id          = id;
	the_displayname = displayname;
	the_new_status  = '?';
	cmd = 'LC_CTYPE=en_US.UTF-8 ' + ENV['TM_BUNDLE_SUPPORT'] + '/revert_file.rb -svn=' + ENV['TM_SVN'] + ' -path=' + filename + ' -displayname=' + displayname;

	TextMate.isBusy = true;
	myCommand = TextMate.system(cmd, completedTask);
	myCommand.onreadoutput = svnReadOutput;
	myCommand.onreaderror = svnReadError;
};

function svnRemoveFile(filename,id,displayname){
	the_filename    = filename;
	the_id          = id;
	the_displayname = displayname;
	the_new_status  = 'D';
	TextMate.isBusy = true;
	cmd = 'LC_CTYPE=en_US.UTF-8 ' + ENV['TM_BUNDLE_SUPPORT'] + '/remove_file.rb -svn=' + ENV['TM_SVN'] + ' -path=' + filename + ' -displayname=' + displayname;
	
	myCommand = TextMate.system(cmd, completedTask);
	myCommand.onreadoutput = svnReadOutput;
	myCommand.onreaderror = svnReadError;
};

function svnReadOutput(str){
	displayCommandOutput('info', 'info', str);
};

function svnReadError(str){
	displayCommandOutput('error', 'error', str);
};

function openWithFinder(filename,id){
	TextMate.isBusy = true;
	cmd = "open 2>&1 " + filename;
	output = TextMate.system(cmd, null).outputString;
	displayCommandOutput('info', 'info', output);
	TextMate.isBusy = false;
};

function sendDiffToTextMate(filename,id){
	TextMate.isBusy = true;
	cmd = ENV['TM_SVN'] + ' diff --non-recursive --diff-cmd diff ' + filename + '|"$TM_SUPPORT_PATH/bin/mate" &>/dev/console &';
	document.getElementById('commandOutput').innerHTML += TextMate.system(cmd, null).outputString + ' \n'
	TextMate.isBusy = false;
};
