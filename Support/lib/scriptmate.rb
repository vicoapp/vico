# encoding: utf-8

SUPPORT_LIB = ENV['TM_SUPPORT_PATH'] + '/lib/'
require SUPPORT_LIB + 'escape'
require SUPPORT_LIB + 'web_preview'
require SUPPORT_LIB + 'io'
require SUPPORT_LIB + 'tm/tempfile'

require 'cgi'
require 'fcntl'

$KCODE = 'u'
require 'jcode'

$SCRIPTMATE_VERSION = "$Revision: 11069 $"

def my_popen3(*cmd) # returns [stdin, stdout, strerr, pid]
  pw = IO::pipe   # pipe[0] for read, pipe[1] for write
  pr = IO::pipe
  pe = IO::pipe
  
  # F_SETOWN = 6, ideally this would be under Fcntl::F_SETOWN
  pw[0].fcntl(6, ENV['TM_PID'].to_i) if ENV.has_key? 'TM_PID'
  
  pid = fork{
    pw[1].close
    STDIN.reopen(pw[0])
    pw[0].close

    pr[0].close
    STDOUT.reopen(pr[1])
    pr[1].close

    pe[0].close
    STDERR.reopen(pe[1])
    pe[1].close

    tm_interactive_input = SUPPORT_LIB + '/tm_interactive_input.dylib'
    if (File.exists? tm_interactive_input) 
      dil = ENV['DYLD_INSERT_LIBRARIES']
      ENV['DYLD_INSERT_LIBRARIES'] = (dil) ? "#{tm_interactive_input}:#{dil}" : tm_interactive_input unless (dil =~ /#{tm_interactive_input}/)
      ENV['DYLD_FORCE_FLAT_NAMESPACE'] = "1"
      ENV['TM_INTERACTIVE_INPUT'] = 'AUTO|ECHO'
    end
    
    exec(*cmd)
  }

  pw[0].close
  pr[1].close
  pe[1].close

  pw[1].sync = true

  [pw[1], pr[0], pe[0], pid]
end

def cmd_mate(cmd)
  # cmd can be either a string or a list of strings to be passed to Popen3
  # this command will write the output of the `cmd` on STDOUT, formatted in
  # HTML.
  c = UserCommand.new(cmd)
  m = CommandMate.new(c)
  m.emit_html
end

class UserCommand
  attr_reader :display_name, :path
  def initialize(cmd)
    @cmd = cmd
  end
  def run
    stdin, stdout, stderr, pid = my_popen3(@cmd)
    return stdout, stderr, nil, pid
  end
  def to_s
    @cmd.to_s
  end
end

class CommandMate
    def initialize (command)
      # the object `command` needs to implement a method `run`.  `run` should
      # return an array of three file descriptors [stdout, stderr, stack_dump].
      @error = ""
      @command = command
      STDOUT.sync = true
      @mate = self.class.name
    end
  protected
    def filter_stdout(str)
      # strings from stdout are passed through this method before being printed
      # txmt://open?line=3&url=file:///var/folders/Gx/Gxr7D8ILFba5bZaZC6rrCE%2B%2B%2BTQ/-Tmp-/untitled_m16p.py
      str = htmlize(str).gsub(/\<br\>/, "<br>\n")

    end
    def filter_stderr(str)
      # strings from stderr are passwed through this method before printing
      "<span style='color: red'>#{htmlize str}</span>".gsub(/\<br\>/, "<br>\n")
    end
    def emit_header
      puts html_head(:window_title => "#{@command}", :page_title => "#{@command}", :sub_title => "")
      puts "<pre>"
    end
    def emit_footer
      puts "</pre>"
      html_footer
    end
  public
    def emit_html
      @command.run do |stdout, stderr, stack_dump, pid|
        %w[INT TERM].each do |signal|
          trap(signal) do
            begin
              Process.kill("KILL", pid)
              sleep 0.5
              Process.kill("TERM", pid)
            rescue
              # process doesn't exist anymore
            end
          end
        end
        emit_header()
        TextMate::IO.exhaust(:out => stdout, :err => stderr, :stack => stack_dump) do |str, type|
          case type
            when :out   then print filter_stdout(str)
            when :err   then puts filter_stderr(str)
            when :stack then
              unless @command.temp_file.nil?
                str.gsub!(/(href=("|')(?:txmt:\/\/open\?(?:[a-z]+=[0-9]+)*?))(&url=.*)([a-z]+=[0-9]+)?(\2)/, '\1\2')
                ext = @command.default_extension
                str.gsub!(File.basename(@command.temp_file), "untitled")
              end
              @error << str
          end
        end
        emit_footer()
        Process.waitpid(pid)
      end
    end
end

class UserScript
  attr_reader :display_name, :path, :warning
  attr_reader :temp_file
  def initialize(content)
    
    @warning = ''
    @content = content
    @hashbang = $1 if @content =~ /\A#!(.*)$/
    
    @saved = true
    if ENV.has_key? 'TM_FILEPATH' then
      @path = ENV['TM_FILEPATH']
      @display_name = File.basename(@path)
      begin
        file = open(@path, 'w')
        file.write @content
      rescue Errno::EACCES
        @saved = false
        @warning = "Could not save #{@path} before running, using temp file..."
      ensure
        file.close unless file.nil?
      end
    else
      @saved = false
    end
  end
  
  public
    
    def executable
      # return the path to the executable that will run @content.
    end
    def args
      # return any arguments to be fed to the executable
      []
    end
    def filter_cmd(cmd)
      # this method is called with this list:
      #     [executable, args, e_sh(@path), ARGV.to_a ].flatten
      cmd
    end
    def version_string
      # return the version string of the executable.
    end
    def default_extension
      # return the extension to use if the script has not yet been saved
    end
    def run(&block)
      rd, wr = IO.pipe
      rd.fcntl(Fcntl::F_SETFD, 1)
      ENV['TM_ERROR_FD'] = wr.to_i.to_s
      if @saved
        cmd = filter_cmd([executable, args, e_sh(@path), ARGV.to_a ].flatten) 
        stdin, stdout, stderr, pid = my_popen3(cmd.join(" "))
        wr.close
        block.call(stdout, stderr, rd, pid)
      else
        TextMate::IO.tempfile(default_extension) do |f|
          f.write @content
          @display_name = "untitled"
          @temp_file = f.path
          cmd = filter_cmd([executable, args, e_sh(f.path), ARGV.to_a ].flatten)
          stdin, stdout, stderr, pid = my_popen3(cmd.join(" "))
          wr.close
          block.call(stdout, stderr, rd, pid)
        end
      end
    end
end

class ScriptMate < CommandMate

  protected
    def emit_header
      puts html_head(:window_title => "#{@command.display_name} — #{@mate}", :page_title => "#{@mate}", :sub_title => "#{@command.lang}")
      puts <<-HTML
<!-- scriptmate javascripts -->
<script type="text/javascript" charset="utf-8">
function press(evt) {
   if (evt.keyCode == 67 && evt.ctrlKey == true) {
      TextMate.system("kill -s INT #{@pid}; sleep 0.5; kill -s TERM #{@pid}", null);
   }
}
document.body.addEventListener('keydown', press, false);

function copyOutput(link) {
  output = document.getElementById('_scriptmate_output').innerText;
  cmd = TextMate.system('__CF_USER_TEXT_ENCODING=$UID:0x8000100:0x8000100 /usr/bin/pbcopy', function(){});
  cmd.write(output);
  cmd.close();
  link.innerText = 'output copied to clipboard';
}
</script>
<!-- end javascript -->
HTML
      puts <<-HTML
  <style type="text/css">
    /* =================== */
    /* = ScriptMate Styles = */
    /* =================== */

    div.scriptmate {
    }

    div.scriptmate > div {
    	/*border-bottom: 1px dotted #666;*/
    	/*padding: 1ex;*/
    }

    div.scriptmate pre em
    {
    	/* used for stderr */
    	font-style: normal;
    	color: #FF5600;
    }

    div.scriptmate div#exception_report
    {
    /*	background-color: rgb(210, 220, 255);*/
    }

    div.scriptmate p#exception strong
    {
    	color: #E4450B;
    }

    div.scriptmate p#traceback
    {
    	font-size: 8pt;
    }

    div.scriptmate blockquote {
    	font-style: normal;
    	border: none;
    }


    div.scriptmate table {
    	margin: 0;
    	padding: 0;
    }

    div.scriptmate td {
    	margin: 0;
    	padding: 2px 2px 2px 5px;
    	font-size: 10pt;
    }

    div.scriptmate a {
    	color: #FF5600;
    }
    
    div#exception_report pre.snippet {
      margin:4pt;
      padding:4pt;
    }
  </style>
  <strong class="warning" style="float:left; color:#B4AF00;">#{@command.warning}</strong>
  <div class="scriptmate #{@mate.downcase}">
  <div class="controls" style="text-align:right;">
    <a style="text-decoration: none;" href="#" onclick="copyOutput(document.getElementById('_script_output'))">copy output</a>
  </div>
  <!-- first box containing version info and script output -->
  <pre>
<strong>#{@mate} r#{$SCRIPTMATE_VERSION[/\d+/]} running #{@command.version_string}</strong>
<strong>>>> #{@command.display_name}</strong>

<div id="_scriptmate_output" style="white-space: normal; -khtml-nbsp-mode: space; -khtml-line-break: after-white-space;"> <!-- Script output -->
  HTML
    end

    def emit_footer
      puts '</div></pre></div>'
      puts @error unless @error == ""
      puts '<div id="exception_report" class="framed">Program exited.</div>'
      html_footer
    end
end
