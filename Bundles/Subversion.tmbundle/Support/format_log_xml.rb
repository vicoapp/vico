# uses rexml to format 'svn log --xml' with a erb template (log.rhtml)
# by torsten becker <torsten.becker@gmail.com> in 2006


module SVNLogHelpers
  # used to enable alternate colors for each log entry
  def odd_or_even
    if $odd == 0
      $odd = 1
      'alternate'
    else
      $odd = 0
      ''
    end
  end
  
  def each_entry( &b )
    self.each_element( 'log/logentry', &b )
  end
  
  def author
    self.elements['author'] ? self.elements['author'].text : "(anonymous)"
  end
  
  def date
    input  = self.elements['date'].text
    format = $date_format
    
    if not format.nil? and input =~ /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)\.\d+Z$/
      #            year     month    day      hour     minutes  seconds
      Time.gm( $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i ).getlocal.strftime( format )
    else
      input
    end
  end
  
  def rev
    self.attributes['revision']
  end
  
  def each_path( &b )
    self.get_elements( 'paths/path' ).sort { |a, b|
      $sort_order.index( a.action ) <=> $sort_order.index( b.action )
    }.each &b
  end
  
  # TODO: überarbeiten
  def message
    if node = self.elements['msg']
      htmlize( node.text ).split("\n").join('<br>')
    else
      '(no message for this commit)'
    end
  end
  
  def num_paths
    self.get_elements( 'paths/path' ).size
  end
  
  def action
    case self.attributes['action']
      when 'A'; :added
      when 'M'; :modified
      when 'D'; :deleted
      when 'R'; :replaced
      else; raise "unknown action #{self.attributes['action']}"
    end
  end
  
  def link_for( path, rev )
    result = ''
    
    file = path.text.gsub(/(.*) \(from .*:\d+\)/, '\1')
    
    full_url_escaped = $repo_url + file.gsub(/[^a-zA-Z0-9_:.\/@+]/) { |m| sprintf("%%%02X", m[0] ) }
    
    filename = file.gsub(%r(.*/(.*?)$), '\1')
    filename_escaped = filename.quote_filename_for_shell.gsub('\\','\\\\\\\\').gsub('"', '\\\&#34;').gsub("'", '&#39;')
    
    result << '<a href="#" onClick="javascript:export_file('+"'#{$svn_cmd}', '#{full_url_escaped}', "
    
    # if a file was deleted, then show the previous (existing) revision
    result << ( (path.action == :deleted)?(rev - 1): rev).to_s
    
    result << ", '#{filename_escaped}'); return false;\">#{htmlize(path.text)}</a>"
    
    # if the document was modified show a diff
    if path.action == :modified
      result << '  &nbsp;(<a href="#" onClick="javascript:diff_and_open_tm(' +
        "'#{$svn_cmd}', '#{full_url_escaped}', #{rev}, '/tmp/#{filename_escaped}.diff' ); return false;\">Show Changes</a>)"
    end
    
    result
  end
  
end

$bundle  = ENV['TM_BUNDLE_SUPPORT']
$support = ENV['TM_SUPPORT_PATH']

# we depend in this things
require 'rexml/document'
require 'erb'
require $support+'/lib/shelltokenize.rb'
require $support+'/lib/textmate.rb'
require $bundle+'/svn_helper.rb'
include SVNHelper


begin
  # check for alternative titles
  $window_title	= 'Log'
  ARGV.each do |arg|
  	case arg
  	when /--title=(.*)/
  		$window_title = $1
  	end
  end
  
  # get the directory which probably is our working copy
  working_copy = ENV['TM_SELECTED_FILES'].nil? ? ENV['TM_FILEPATH'] : TextMate.selected_files[0]
  working_copy = File.dirname working_copy  unless File.directory? working_copy
  
  # run svn to resolve a $repo_url for the directory we just found out, this
  # is the base url of all the files that pop up in the log.
  $repo_url = `"${TM_SVN:=svn}" info #{working_copy.quote_filename_for_shell} 2>&1 | grep 'Repository Root:' | cut -b18- `.chop
  
  # external (not changing) vars
  $tab_size    = ENV['TM_TAB_SIZE'].to_i
  $date_format = ENV['TM_SVN_DATE_FORMAT'] || '%F %T %z'
  $svn_cmd     = ENV['TM_SVN'].nil? ? `which svn`.chomp : ENV['TM_SVN']
  $sort_order  = [ :added, :modified, :deleted, :replaced ]
  
  # will not print the bad lines in orange
  $ignore_bad_lines = ENV['TM_SVN_IGNORE_BAD_LINES'].nil? ? false : true
  
  # this should not happen but could :>
  if $repo_url.nil? or $repo_url.empty?
    make_error_head( 'Warning' )
    puts "format_log_xml.rb was not able to reconstruct the repository url so you won't<br />"+
         "be able to click on the links. The reason for this is likely that you have last checked out from this repository with a version of svn older than 1.3.0. Please update your version of svn AND run 'svn up'."
    make_error_foot()
    $repo_url = ''
  end
  
  $stdout.flush
  
  # collect all lines before the xml header
  no_xml = ''
  $stdin.each_line do |line|
    if line =~ /^(.*)<\?xml version="1\.0"( encoding="utf-8")?\?>$/
      no_xml << $1
      break
    else
      no_xml << line
    end
  end
  no_xml = '' if ($ignore_bad_lines and (not $stdin.eof?))
  
  # read everything into a (maybe very huge) buffer
  # buffer = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" + $stdin.readlines.join
  # buffer = $stdin.readlines.join
  # puts buffer.size
  # 
  # exit

  log = REXML::Document.new $stdin unless $stdin.eof?
  ERB.new( File.read( $bundle+'/log.rhtml' ) ).run binding
  
rescue => e
  handle_default_exceptions( e )
end
