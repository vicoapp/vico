# 'parses' the output of svn log and makes html out of
# it, which it then shows you.
# 
# by torsten becker <torsten.becker@gmail.com>, 2005/06
# no warranty, that it doesn't crash your system.
# you are of course free to modify this.


$bundle 		= ENV['TM_BUNDLE_SUPPORT']
$support	 	= ENV['TM_SUPPORT_PATH']
$window_title	= 'Log'

# we depend in this things
require $bundle+'/svn_helper.rb'
require $support+'/lib/escape.rb'
require $support+'/lib/shelltokenize.rb'
require $support+'/lib/textmate.rb'
require $support+'/lib/web_preview.rb' 
include SVNHelper

# check for alternative titles
ARGV.each do |arg|
	case arg
	when /--title=(.*)/
		$window_title = $1
	end
end

begin
   # get the directory which probably is our working copy
   working_copy = ENV['TM_SELECTED_FILES'].nil? ? ENV['TM_FILEPATH'] : TextMate.selected_files[0]
   working_copy = File.dirname working_copy  unless File.directory? working_copy
   
   # run svn to resolve a $repo_url for the directory we just found out, this
   # is the base url of all the files that pop up in the log.
   $repo_url = `"${TM_SVN:=svn}" info #{e_sh working_copy} 2>&1 | grep 'Repository Root:' | cut -b18- `.chop
   
   
   # external (not changing) vars
   $tab_size    = ENV['TM_TAB_SIZE'].to_i
   $limit       = ENV['TM_SVN_LOG_LIMIT'].nil?   ? 15 : ENV['TM_SVN_LOG_LIMIT'].to_i
   $date_format = ENV['TM_SVN_DATE_FORMAT'].nil? ? nil : ENV['TM_SVN_DATE_FORMAT']
   $svn_cmd     = ENV['TM_SVN'].nil? ? `which svn`.chomp : ENV['TM_SVN']
   $sort_order  = [ :added, :modified, :deleted, :replaced ]
   
   # will not print the bad lines in orange
   $ignore_bad_lines = ENV['TM_SVN_IGNORE_BAD_LINES'].nil? ? false : true
   
   # internal changing vars
   msg_count      = 0      # used to count messages and to show tables in alternate colors
   comment_count  = 0      # used to count the lines of comments
   rev            = ''     # the last fetched revision
   max_lines      = 0      # the maximum number of lines
   already_shown  = []     # to supress double messages (they could happen if you selected multiple files)
   skipped_files  = false  # to remember this
   changed_files  = []     # just a array to sort the files
   
   # used to remember when to show the show / hide switches the next time
   # this is necesarry because this information has to be passed over one state.
   show_switch_next_time = true
   
   # about the states of the 'parser':
   #  skipped_files  if we wait for some Skipped: messages at the beginning
   #  separator      initial state, assuming a ---..
   #  info           parsing the info line with rev, name, etc
   #  changed_paths  awaiting a changed paths thing or blank line
   #  path_list      parsing changed files
   #  comment        getting the comment
   #  skip_next      if doesnt show the next message because we already did
   state = :skipped_files
   
   
	 html_header($window_title, "Subversion", <<-HTML)
		<style type="text/css">
			@import 'file://#{$bundle}/Stylesheets/svn_style.css';
			@import 'file://#{$bundle}/Stylesheets/svn_log_style.css';
		</style>
		<script src='file://#{$bundle}/svn_log_helper.js' type='text/javascript' charset='utf-8'></script>
HTML
   
   # this should not happen but could :>
   if $repo_url.nil? or $repo_url.empty?
      make_error_head( 'Warning' )
      puts "format_log.rb was not able to reconstruct the repository url so you won't<br />"+
           "be able to click on the links. (if you get this everytime it could be a bug)"
      make_error_foot()
      $repo_url = ''
   end
   
   $stdout.flush
   
   $stdin.each_line do |line|
      raise SVNErrorException, line  if line =~ /^svn:/
      
      case state
         when :skipped_files
            if line =~ /^-{72}$/
               state = :info
               make_error_foot  if skipped_files
               
            elsif line =~ /^Skipped '(.+)'$/
               unless skipped_files
                  make_error_head('Skipped:')
                  skipped_files = true
               end
               puts '<a href="'+make_tm_link( $1 )+'">'+htmlize($1)+'</a><br />'
               
            else
               puts %{<div class="bad_line">#{line}&nbsp;</div>}  unless $ignore_bad_lines
            end
            
         when :separator
            raise LogLimitReachedException  if $limit != 0 and msg_count == $limit
            
			case line
            when /^-{72}$/
               state = :info
			when /(\s|\n|\r)*/
				# ignore an empty line
            else
               raise NoMatchException, merge_line_and_state( line, state )
            end
            
         when :info
            if line =~ /^r(\d+) \| (.+?) \| (.+) \| (\d+) lines?$/
               state      = :changed_paths
               rev        = $1
               max_lines  = $4.to_i
               
               if already_shown.include? rev.to_i
                  state = :skip_next
                  next
               else
                  already_shown << rev.to_i
               end
               
               
               puts( ((msg_count % 2) == 0) ? '<table class="log">' :
                                              '<table class="log alternate">' )
               msg_count += 1
               
               puts '<tr>  <th>Revision:</th>  <td>'+ $1 + '</td> </tr>'
               puts '<tr>  <th>Author:</th>    <td>'+ htmlize( $2 ) + '</td> </tr>'
               puts '<tr>  <th>Date:</th>      <td>'+ htmlize( formated_date( $3 ) ) + '</td></tr>'
               puts '<tr>  <th>Changed Files:</th><td>'
               show_switch_next_time = true
               
            else
               raise NoMatchException, merge_line_and_state( line, state )
            end
            
         when :changed_paths
            # should match "Changed paths:" and all possible
            # localisations (Geänderte Pfade, etc) as long as they consist
            # of 2 words with 3+ chars.
            if line =~ /^\w{3,} \w{3,}:$/u
               state = :path_list
            elsif line =~ /^\s*$/
               state = :comment
            else
               raise NoMatchException, merge_line_and_state( line, state )
            end
            
         when :path_list
            if line =~ /^\s+([A-Z]) (.+)$/
               op = case $1
                       when 'A'; :added
                       when 'M'; :modified
                       when 'D'; :deleted
                       when 'R'; :replaced
                       else;     raise NoMatchException, merge_line_and_state( line, state )
                    end
               
               changed_files << [ op, $2 ]
               
            elsif line =~ /^\s*$/
               state = :comment
            else
               raise NoMatchException, merge_line_and_state( line, state )
            end
            
         when :comment
            if show_switch_next_time
               puts '<a id="r'+rev+'_show" href="javascript:show_files(\'r'+rev+'\');">show ('+changed_files.size.to_s+')</a>'
               puts '<a id="r'+rev+'_hide" href="javascript:hide_files(\'r'+rev+'\');" class="hidden">hide</a>'
               puts '<ul id="r'+rev+'" class="hidden">'
               
               show_switch_next_time = false
            end
            
            unless changed_files.empty?
               changed_files.sort! do |a, b|
                  $sort_order.index( a[0] ) <=> $sort_order.index( b[0] )
               end
               
               # path[0] is a symbol from [:deleted, :added, :modified, :replaced]
               # path[1] is the filename description (not always a valid path)
               changed_files.each do |path|
                  
                  file = path[1].gsub(/(.*) \(from .*:\d+\)/, '\1')
                  
                  full_url = $repo_url + file
                  full_url_escaped = full_url.gsub(/[^a-zA-Z0-9_:.\/@+]/) { |m| sprintf("%%%02X", m[0] ) }
                  
                  filename = file.gsub(%r(.*/(.*?)$), '\1')
                  filename_escaped = e_sh(filename).gsub('\\','\\\\\\\\').gsub('"', '\\\&#34;').gsub("'", '&#39;')
                  
                  
                  print '  <li class="'+path[0].to_s+'"><a href="#" onClick="javascript:export_file(' + "'#{$svn_cmd}', '#{full_url_escaped}', "
                  
                  # if a file was deleted, then show the previous (existing) revision
                  print ( (path[0] == :deleted) ? (rev.to_i - 1).to_s : rev )
                  
                  print ", '#{filename_escaped}'); return false;\">#{htmlize(path[1])}</a>"
                  
                  # if the document was modified show a diff
                  if path[0] == :modified
                     print '  &nbsp;(<a href="#" onClick="javascript:diff_and_open_tm(' +
                           "'#{$svn_cmd}', '#{full_url_escaped}', #{rev}, '/tmp/#{filename_escaped}.diff' ); return false;\">Diff With Previous</a>)"
                  end
                  
                  puts '</li>'
                  
               end
               
               changed_files = []
            end
            
            
            if comment_count == 0
               puts '</ul></td></tr>'
               puts '<tr> <th>Message:</th> <td class="msg_field">'
               
            end
            
            puts htmlize(line)+'<br />'  if comment_count < max_lines
            
            comment_count += 1
            
            if comment_count == max_lines
               state          = :separator
               comment_count  = 0
               
               puts "</td></tr></table>\n\n"
               
               $stdout.flush
            end
            
         when :skip_next
            state = :info  if line =~ /^-{72}$/
            
         else
            raise 'unknown state: '+state.to_s
            
      end #case state
      
   end #each_line
   
   raise UnexpectedFinalStateException, state.to_s  unless ((state == :info) || (state == :separator))
   
rescue LogLimitReachedException
rescue => e
   handle_default_exceptions( e )
ensure
   # FIXME call make_footer
end
