/* 
   some js stuff like showing and hiding files, and opening
   files / diffs with textmate, used by svn log.
   
   copyright 2005 torsten becker <torsten.becker@gmail.com>
   no warranty, that it doesn't crash your system.
   you are of course free to modify this.
*/

function didFinishCommand ()
{
   TextMate.isBusy = false;
}

// filename is already shell-escaped, URL is %-escaped
function export_file ( svn, url, rev, filename )
{
   TextMate.isBusy = true;
   TextMate.system("\""+svn+"\" cat '" + url + "'@"+rev+" &>/tmp/" + filename + "; \"$TM_SUPPORT_PATH/bin/mate\" /tmp/" + filename, didFinishCommand);
}

/* show: files + hide-button,  hide: show-button.. */
function show_files( base_id )
{
   document.getElementById( base_id ).style.display = 'block';
   document.getElementById( base_id+'_show' ).style.display = 'none';   
   document.getElementById( base_id+'_hide' ).style.display = 'inline';
}

/* hide: files + hide-button,  show: show-button.. */
function hide_files( base_id )
{
   document.getElementById( base_id ).style.display = 'none';
   document.getElementById( base_id+'_show' ).style.display = 'inline';   
   document.getElementById( base_id+'_hide' ).style.display = 'none';
}


function diff_and_open_tm( svn, url, rev, filename )
{
	TextMate.isBusy = true;
	TextMate.system('"'+svn+'" diff --diff-cmd diff -c'+rev+' "'+url+'" &>'+filename+'; \"$TM_SUPPORT_PATH/bin/mate\" '+filename, didFinishCommand );
}
