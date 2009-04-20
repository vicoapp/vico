# encoding: utf-8

# just a small to-html formater for what svn blame gives you.
# made to be compatible with the ruby version included
# in 10.3.7 (1.6.8) but runs also with 1.8
# 
# copyright 2005 torsten becker <torsten.becker@gmail.com>
# no warranty, that it doesn't crash your system.
# you are of course free to modify this.

# so that we can use html_escape()
require "erb"
include ERB::Util

# fetch some tm things..
$full_file     = ENV['TM_FILEPATH']
$current       = ENV['TM_LINE_NUMBER'].to_i
$tab_size      = ENV['TM_TAB_SIZE'].to_i
$bundle        = ENV['TM_BUNDLE_SUPPORT']
$date_format   = ENV['TM_SVN_DATE_FORMAT'].nil? ? nil : ENV['TM_SVN_DATE_FORMAT']

# find out if the window should get closed on a click
$close = ENV['TM_SVN_CLOSE'].nil? ? '' : ENV['TM_SVN_CLOSE']
unless $close.empty?
   $close.strip!
   if $close == 'true' or $close == '1'
      $close = ' onClick="window.close();"'
   else
      $close = ''
    end
end


# require the helper, it does some formating, etc:
require $bundle+'/svn_helper.rb'
include SVNHelper

# to show line numbers in output:
linecount = 1


begin
    revision_comment = []
    revision_number = 0
   `"${TM_SVN:=svn}" log "$TM_FILEPATH" 2>&1`.each_line {|line|
      if line =~ /^r(\d*)/ then
        revision_number = $1.to_i
        revision_comment[revision_number] = ''
      else
        if line !~ /^-----/ && revision_number > 0 then
          revision_comment[revision_number] += line
        end
      end
   }
   
   puts html_head(:window_title => "Blame for “"+$full_file.sub( /^.*\//, '')+"”", :page_title => $full_file.sub( /^.*\//, ''), :sub_title => 'Subversion')
   
   STDOUT.flush

   puts '<div class="subversion"><table class="blame"> <tr>' +
            '<th>line</th>' +
            '<th class="revhead">rev</th>' +
            '<th>user</th>' +
            '<th class="codehead">code</th></tr>'
   
   prev_rev = 0
   color = ''
   
   $stdin.each_line do |line|
      raise SVNErrorException, line  if line =~ /^svn:/
      
      # not a perfect pattern, but it works and is short:
      # catched groups: revision, user, date, text/code
      if line =~ /^\s*(\d+)\s+([^\s]+) (\d+-\d+-\d+ \d+:\d+:\d+ [-+]\d+ \(\w+, \d+ \w+ \d+\)) (.*)$/u
         curr_add = ($current == linecount) ? ' current_line ' : ' '
         line_id = ($current == linecount + 10) ? ' id="current_line"' : ''
         
         revision = $1.to_i
         
         if $1.to_i != prev_rev
            if color == ''
               color = 'alternate'
            else
               color = ''
            end
         end
         
         puts '<tr>'
         puts  '<td class="linecol"><span'+ line_id.to_s + '><a href="' +
            make_tm_link( $full_file, linecount) +'"'+$close+'>'+ linecount.to_s + "</a></span></td>\n" +
               '<td class="revcol' +curr_add+'" title="'+ formated_date( $3 ) + (revision_comment[revision].nil? ? '' : "\n" + html_escape(revision_comment[revision])) + '">' + $1 + "</td>\n" +
               '<td class="namecol'+curr_add+'" >' + $2 + "</td>\n" +
               '<td class="codecol'+curr_add+color+'" >'+ htmlize( $4 ) +
               "</td></tr>\n\n"

         linecount += 1
         
      else
         raise NoMatchException, line
      end
      
      prev_rev = $1.to_i
      
   end #each_line

rescue => e
   handle_default_exceptions( e )
ensure
   puts '<script>window.location.hash = "current_line";</script></table></div>'
   html_footer()
end
