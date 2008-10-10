/* a _very_ basic implementation of flipping
   the visibility of the changed files list.
   
   copyright 2005 torsten becker <torsten.becker@gmail.com>
   no warranty, that it doesn't crash your system.
   you are of course free to modify this.
*/


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
