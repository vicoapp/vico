# just some small methods and some exceptions to help
# with converting some of the svn command outputs to html.
# 
# by torsten becker <torsten.becker@gmail.com>, 2005/06
# no warranty, that it doesn't crash your system.
# you are of course free to modify this.

require "#{ENV["TM_SUPPORT_PATH"]}/lib/escape"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/web_preview"

module SVNHelper   
   # (log) raised, if the maximum number of log messages is shown.
   class LogLimitReachedException < StandardError; end
   
   # (log) thrown when a parser ended in a state that wasn't expected
   class UnexpectedFinalStateException < StandardError; end
   
   # (all) raised if the 'parser' gets a line
   # which doesnt match a certain scheme or wasnt expected
   # in a special state.
   class NoMatchException < StandardError; end
   
   # (all) if we should go in error mode
   class SVNErrorException < StandardError; end
   
   
   # makes a txmt-link for the html output, the line arg is optional.
   def make_tm_link( filename, line=nil )
      encoded_file_url = ''
      ('file://'+filename).each_byte do |b|
         if b.chr =~ /\w/
            encoded_file_url << b.chr
         else
            encoded_file_url << sprintf( '%%%02x', b )
         end
      end
      
      'txmt://open?url=' + encoded_file_url + ((line.nil?) ? '' : '&amp;line='+line.to_s)
   end
   
   # formates you date (input should be a standart svn date)
   # if format is nil it just gives you back the current date
   def formated_date( input, format=$date_format )
      if not format.nil? and input =~ /^\s*(\d+)-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) .+$/
         #            year     month    day      hour     minutes  seconds
         Time.mktime( $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i ).strftime( format )
      else
         input
      end
   end
   
   
   # the same as the above 2 methods, just for errors.
   def make_error_head( title='', head_adds='' )
      puts '<div class="error"><h2>'+title+'</h2>'+head_adds
   end
   
   # .. see above.
   def make_error_foot( foot_adds='' )
      puts foot_adds+'</div>'
   end
   
   
   # used to handle the normal exceptions like
   # NoMatchException, SVNErrorException and unknown exceptions.
   def handle_default_exceptions( e, stdin=$stdin )
   	case e
   	when NoMatchException
         make_error_head( 'No Match' )
         
         puts 'mhh, something with with the regex or svn must be wrong.  this should never happen.<br />'
         puts "last line: <em>#{htmlize($!)}</em><br />please bug-report."
         
         make_error_foot()
         
      when SVNErrorException
         make_error_head( 'SVN Error', htmlize( $! )+'<br />' )
         stdin.each_line { |line| puts htmlize( line )+'<br />' }
         make_error_foot()
         
      when UnexpectedFinalStateException
         make_error_head('Unexpected Final State')
         puts 'the parser ended in the final state <em>'+ $! +'</em>, this shouldnt happen. <br /> please bug-report.'
         make_error_foot
         
      # handle unknown exceptions..
      else
         make_error_head( e.class.to_s )
         
         puts 'reason: <em>'+htmlize( $! )+'</em><br />'
         trace = ''; $@.each { |e| trace+=htmlize('  '+e)+'<br />' }
         puts 'trace: <br />'+trace
         
         make_error_foot()
         
      end #case
      
   end #def handle_default_exceptions
   
   
   # used when throwing a NoMatchException to also tell the state,
   # because you can only pass 1 string to raise you have to cat them together.
   def merge_line_and_state( line, state )
      "\"#{line}\" in state :#{state}"
   end
   
end #module SVNHelper
