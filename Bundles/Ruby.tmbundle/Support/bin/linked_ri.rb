#!/usr/bin/env ruby -w

# if we are not called directly from TM (e.g. JavaScript) the caller
# should ensure that RUBYLIB is set properly
$: << "#{ENV["TM_SUPPORT_PATH"]}/lib" if ENV.has_key? "TM_SUPPORT_PATH"
LINKED_RI = "#{ENV["TM_BUNDLE_SUPPORT"]}/bin/linked_ri.rb"

require "exit_codes"
require "ui"
require "web_preview"

require "erb"
include ERB::Util

tm_var_or_qri = 'RI=$(type -P ${TM_RUBY_RI:-qri})'
ri_default    = '[[ ! -x "$RI" ]] && RI=$(type -P ri)'
RI_EXE        = `#{tm_var_or_qri}; #{ri_default}; /bin/echo -n "$RI"`

term = ARGV.shift

# first escape for use in the shell, then escape for use in a JS string
def e_js_sh(str)
  (e_sh str).gsub("\\", "\\\\\\\\")
end

def link_methods(prefix, methods)
  methods.split(/(,\s*)/).map do |match|
    match[0] == ?, ?
      match : "<a href=\"javascript:ri('#{prefix}#{match}')\">#{match}</a>"
  end.join
end

def ri(term)
  documentation = `#{e_sh LINKED_RI} '#{term}' 'js' 2>&1` \
                  rescue "<h1>ri Command Error.</h1>"
  if documentation =~ /\ACouldn't open the index/
    TextMate.exit_show_tool_tip(
      "Index needed by #{RI_EXE} not found.\n" +
      "You may need to run:\n\n"               +
      "  fastri-server -b"
    )
  elsif documentation =~ /\ACouldn't initialize DRb and locate the Ring server./
    TextMate.exit_show_tool_tip("Your fastri-server is not running.")
  elsif documentation =~ /Nothing known about /
    TextMate.exit_show_tool_tip(documentation)
  elsif documentation.sub!(/\A>>\s*/, "")
    choices = documentation.split
    choice  = TextMate::UI.menu(choices)
    exit if choice.nil?
    ri(choices[choice])
  else
    [term, documentation]
  end
end

mode = ARGV.shift
if mode.nil? then

  term = STDIN.read.strip
  TextMate.exit_show_tool_tip("Please select a term to look up.") if term.empty?

  term, documentation = ri(term)

  html_header("Documentation for ‘#{term}’", "RDoc", <<-HTML)
<script type="text/javascript" charset="utf-8">
  function ri (arg, _history) {
    TextMate.isBusy = true;
    var res = TextMate.system("RUBYLIB=#{e_js_sh "#{ENV['TM_SUPPORT_PATH']}/lib"} #{e_js_sh LINKED_RI} 2>&1 '" + arg + "' 'js'", null).outputString;
    document.getElementById("actual_output").innerHTML = res;
    TextMate.isBusy = false;
    if(!_history)
    {
      var history = document.getElementById('search_history');
      var new_option = document.createElement('option');
      new_option.setAttribute('value', arg);
      new_option.appendChild(document.createTextNode(arg));
      history.appendChild(new_option);
      history.value = arg;
    }
  }
</script>
HTML
  puts <<-HTML
<select id="search_history" style="float: right;">
  <option value="#{term}" selected="selected">#{term}</option>
</select>
<script type="text/javascript" charset="utf-8">
  document.getElementById('search_history').addEventListener('change', function(e) {
    ri(document.getElementById('search_history').value, true);
  }, false);
</script>
<div id="actual_output" style="margin-top: 3em">#{documentation}</div>
HTML
  html_footer
  TextMate.exit_show_html
elsif mode == 'js' then
  documentation = h(`#{RI_EXE} -T -f plain #{e_sh term}`) \
    rescue "<h1>ri Command Error.</h1>"

  documentation.gsub!(/(\s|^)\+(\w+)\+(\s|$)/, "\\1<code>\\2</code>\\3")

  if documentation =~ /\A(?:More than one method matched|-+\s+Multiple choices)/
    methods       = documentation.split(/\n[ \t]*\n/).last.strip.split(/,\s*/)
    documentation = ">> #{methods.join(' ')}"
  elsif documentation =~ /\A(?:-+\s+)((?:[A-Z_]\w*::)*[A-Z_]\w*)(#|::|\.)/
    nesting   = $1
    constants = nesting.split("::")
    linked    = (0...constants.size).map do |i|
      "<a href=\"javascript:ri('#{constants[0..i].join('::')}')\">#{constants[i]}</a>"
    end
    documentation.sub!(nesting, linked.join("::"))
  else
    documentation.sub!( /\A(-+\s+Class: \w* < )([^\s<]+)/,
                              "\\1<a href=\"javascript:ri('\\2')\">\\2</a>" )
    documentation.sub!(/(Includes:\s+-+\s+)(.+?)([ \t]*\n[ \t]*\n|\s*\Z)/m) do
      head, meths, foot = $1, $2, $3
      head + meths.gsub(/([A-Z_]\w*)\(([^)]*)\)/) do |match|
        "<a href=\"javascript:ri('#{$1}')\">#{$1}</a>(" +
        link_methods("#{$1}#", $2) + ")"
      end + foot
    end
    documentation.sub!(/(Class methods:\s+-+\s+)(.+?)([ \t]*\n[ \t]*\n|\s*\Z)/m) do
      $1 + link_methods("#{term}::", $2) + $3
    end
    documentation.sub!(/(Instance methods:\s+-+\s+)(.+?)([ \t]*\n[ \t]*\n|\s*\Z)/m) do
      $1 + link_methods("#{term}#", $2) + $3
    end
  end

  puts documentation.gsub("\n", "<br />")
end
