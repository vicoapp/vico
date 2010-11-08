# tm/htmloutput.rb

# Provides an API function in the TextMate namespace TextMate::HTMLOutput.show
# This function expects a block, and basically just calls web_preview's html_header
# before the block is executed, and html_footer after the block is executed.

# The block itself is given an io object (stdout) to which it can write whatever html it
# would like to have appear between the header and footer.

# Call it like this:

# TextMate::HTMLOutput.show(:title => "My Title", :sub_title => "Your subtitle") do |io|
#   io << «something something»
# end

require 'erb'
require 'cgi'

HTMLOUTPUT_TEMPLATE = <<-HTML
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
  "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
  <meta http-equiv="Content-type" content="text/html; charset=utf-8">
  <title><%= window_title %></title>
  <% common_styles.each { |style| %>
    <link rel="stylesheet" href="file://<%= support_path %>/themes/<%= style %>/style.css"   type="text/css" charset="utf-8" media="screen">
  <% } %>
  <% bundle_styles.each { |style| %>
    <link rel="stylesheet" href="file://<%= bundle_support %>/css/<%= style %>/style.css"   type="text/css" charset="utf-8" media="screen">
    <link rel="stylesheet" href="file://<%= bundle_support %>/css/<%= style %>/print.css"   type="text/css" charset="utf-8" media="print">
  <% } %>
  <link rel="stylesheet" href="file://<%= support_path %>/themes/default/print.css"   type="text/css" charset="utf-8" media="print">
  <link rel="stylesheet" href="file://<%= user_path %>print.css"   type="text/css" charset="utf-8" media="print">
  <% user_styles.each { |style| %>
    <link rel="stylesheet" href="file://<%= user_path %><%= style %>/style.css"   type="text/css" charset="utf-8" media="screen">
    <link rel="stylesheet" href="file://<%= user_path %><%= style %>/print.css"   type="text/css" charset="utf-8" media="print">
  <% } %>
  <script src="file://<%= support_path %>/script/default.js"    type="text/javascript" charset="utf-8"></script>
  <script src="file://<%= support_path %>/script/webpreview.js" type="text/javascript" charset="utf-8"></script>
  <script src="file://<%= support_path %>/script/sortable.js" type="text/javascript" charset="utf-8"></script>
  <script type="text/javascript" charset="utf-8">
    var image_path = "file://<%= support_path %>/images/";
  </script>
  <%= html_head %>
</head>
<body id="tm_webpreview_body" class="<%= html_theme %>">
  <div id="tm_webpreview_header">
    <img id="gradient" src="file://<%= theme_path %>/images/header.png" alt="header">
    <p class="headline"><%= page_title %></p>
    <p class="type"><%= sub_title %></p>
    <img id="teaser" src="file://<%= theme_path %>/images/teaser.png" alt="teaser">
    <div id="theme_switcher">
      <form action="#" onsubmit="return false;">
        <div>
          Theme:        
          <select onchange="selectTheme(event);" id="theme_selector">
            <optgroup label="TextMate">
            <% common_styles.each { |style| %>
              <option value="<%= style %>" title="<%= support_path %>/themes/"><%= style %></option>
            <% } %>
            </optgroup>
            <optgroup label="User">
            <% user_styles.each { |style| %>
              <option value="<%= style %>" title="<%= user_path %>"><%= style %></option>
            <% } %>
            </optgroup>
          </select>
        </div>
        <script type="text/javascript" charset="utf-8">
          document.getElementById('theme_selector').value = '<%= html_theme %>';
        </script>
      </form>
    </div>
  </div>
  <div id="tm_webpreview_content" class="<%= html_theme %>">
HTML

module TextMate
  module HTMLOutput
    class << self
      
      def show(options = { }, &block)
        window_title = options[:window_title] || options[:title]    || 'Window Title'
        page_title   = options[:page_title]   || options[:title]    || 'Page Title'
        sub_title    = options[:sub_title]    || ENV['TM_FILENAME'] || 'untitled'

        support_path   = ENV['TM_SUPPORT_PATH']
        bundle_support = ENV['TM_BUNDLE_SUPPORT']
        user_path      = ENV['HOME'] + '/Library/Application Support/TextMate/Themes/Webpreview/'
  
        common_styles  = ['default'];
        user_styles    = [];
        bundle_styles  = bundle_support.nil? ? [] : ['default'];

        Dir.foreach(user_path) { |file|
          user_styles << file if File.exist?(user_path + file + '/style.css')
        } if File.exist? user_path
  
        Dir.foreach(support_path + '/themes/') { |file|
          next if file == 'default'
          common_styles << file if File.exists?(support_path + "/themes/" + file + '/style.css')
        }
  
        common_styles.each { |style|
          next if style == 'default'
          bundle_styles << style if File.directory?(bundle_support + '/css/' + style)
        } unless bundle_support.nil?

        html_head    = options[:html_head]    || ''

        if options[:fix_href] && File.exist?(ENV['TM_FILEPATH'].to_s)
          require "cgi"
          html_head << "<base href='tm-file://#{CGI.escape(ENV['TM_FILEPATH'])}'>"
        end

        support_path   = support_path.sub(/ /, '%20')
        bundle_support = bundle_support.sub(/ /, '%20') unless bundle_support.nil?
        user_path      = user_path.sub(/ /, '%20')

        html_theme     = selected_theme
  
        theme_path     = support_path + '/themes/'
        if(user_styles.include?(html_theme))
          theme_path = user_path + html_theme
        elsif(common_styles.include?(html_theme))
          theme_path += html_theme
        else
          theme_path += "default"
        end

        $stdout.sync = true
        $stdout << ERB.new(HTMLOUTPUT_TEMPLATE).result(binding)
  
        block.call($stdout)

        $stdout << "</div>\n</body>\n</html>"
      end
      
      private
      
      def selected_theme
        res = %x{ defaults 2>/dev/null read com.macromates.textmate.webpreview SelectedTheme }.chomp
        $? == 0 ? res : 'bright'
      end
    end
  end
end