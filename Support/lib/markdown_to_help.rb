#!/usr/bin/env ruby -wKU
# encoding: utf-8

require ENV['TM_SUPPORT_PATH'] + '/lib/escape.rb'

class TreeNode
  attr_accessor :heading, :attributes, :parent, :level, :count
  def initialize(parent = nil, count = 1)
    @parent = parent
    @level = parent ? parent.level + 1 : 0
    @count = count
    @child = @next = nil
    @heading = nil
  end
  def index
    @parent ? [@parent.index, @count].flatten : []
  end
  def to_s
    child = @child ? "\n<ul style='list-style: none'>\n#{@child}</ul>\n" : ''
    entry = @heading ? "<li>#{index.join '.'} <a href='javascript:goTo(&quot;sect_#{index.join '.'}&quot;)'>#{unanchored_heading}</a>#{child}</li>\n" : child
    @next ? entry.to_s + @next.to_s : entry.to_s
  end
  def new_child
    abort "Already has child" if @child
    @child = TreeNode.new(self)
  end
  def new_sibling
    @next = TreeNode.new(@parent, @count + 1)
  end
  def new_heading
    "<h#{@level}#{@attributes}><a id='sect_#{index.join '.'}' href='javascript:goTo(&quot;sect_0&quot;)' style='text-decoration:none' class='uplink'>#{index.join '.'} #{@heading}</a></h#{@level}>"
  end
  def unanchored_heading
    heading.gsub(/<(.*?)>/) {|innards| innards.gsub(/ id=("|').*?\1/, '') }
  end
end

IO.popen('"$TM_SUPPORT_PATH/bin/Markdown.pl"|"$TM_SUPPORT_PATH/bin/SmartyPants.pl"', "r+") do |io|

  Thread.new { ARGF.each_line { |line| 
    io << line.gsub(/\[(.+?)\]\(\?(.+?)\)/){ '[' + $1 + '][?' + $2 + ']' + "\n[?" + $2 + "]: help:anchor='" + e_url($2) + "'%20bookID='TextMate%20Help'\n" }
  }; io.close_write }

  root = tree_node = TreeNode.new
  contents = ''
  io.each_line do |line|
    if line =~ %r{^<h(\d)( .*?)?>(.*)</h\1>$} then
      level = $1.to_i
      tree_node = tree_node.parent while tree_node.level > level
      tree_node = tree_node.new_child while tree_node.level < level
      tree_node = tree_node.new_sibling if tree_node.heading
      tree_node.heading = $3
      tree_node.attributes = $2

      contents << "\n<hr />\n" if level == 1
      line = tree_node.new_heading
    end
    line.gsub!(/<a href="#(.*?)"/) { %Q{<a href='javascript:goTo(&quot;#{$1}&quot;)'} }
    contents << line
  end

  puts <<-HTML
<style type="text/css">
.uplink:hover:after {
  content: " ⇞";
}
</style>
<script type="text/javascript" charset="utf-8">
function goTo (id) {
  document.body.scrollTop = document.getElementById(id).offsetTop - document.images[0].height - 1;
}

function e_sh(string) {
  // Backslashes are doubled since we're inside Ruby code
  return string.replace(/(?=[^a-zA-Z0-9_.\\/\\-\\x7F-\\xFF\\n])/g, '\\\\').replace(/\\n/g, "'\\n'").replace(/^$/g, "''");
}

function insert_after(new_node, node) {
  var parent = node.parentNode;
  return node.nextSibling ? parent.insertBefore(new_node, node.nextSibling) : parent.appendChild(new_node);
}

function click_external_link(evt) {
  if (!evt.metaKey) return;
  evt.preventDefault();
  TextMate.system("open " + e_sh(evt.srcElement.href), null);
}

function setup_external_links() {
  var link, links = document.links;
  for (i = 0; i < links.length; i++) {
    link = links[i];
    if (link.href.match(/^https?:/)) {
      link.title = '⌘-click to open “' + link.href + '” in the default browser.';
      link.addEventListener('click', click_external_link, false);
      insert_after(document.createTextNode("  ➲"), link);
    } else if (link.href.match(/^help:/)) {
      link.title = 'Open TextMate help in Help Viewer.';
      insert_after(document.createTextNode(" ⓘ"), link);
    }
  }
}
</script>
<base href="file://#{ENV['TM_BUNDLE_SUPPORT']}/" />
HTML

  puts "<h2 id='sect_0'>Table of Contents</h2>"
  puts root
  puts contents

  puts <<-HTML
<script type="text/javascript" charset="utf-8">
setup_external_links();
</script>
HTML

end
