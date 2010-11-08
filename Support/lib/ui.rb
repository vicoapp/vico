# encoding: utf-8

require 'English'
# require File.dirname(__FILE__) + '/escape'
# require File.dirname(__FILE__) + '/osx/plist'
# Need to change this for testing the file in another folder
require ENV['TM_SUPPORT_PATH'] + '/lib/escape'
require ENV['TM_SUPPORT_PATH'] + '/lib/osx/plist'

TM_DIALOG = e_sh ENV['DIALOG'] unless defined?(TM_DIALOG)

module TextMate

  module UI

    class << self
      # safest way to use Dialog
      # see initialize for calling info
      def dialog(*args)
        d = Dialog.new(*args)
        begin
          yield d
        rescue StandardError => error
          puts 'Received exception: ' + error
          puts pretty_print_exception(error)
        ensure
          d.close
        end
      end

      def pretty_print_exception(e)
        str = "#{e.class.name}: #{e.message.sub(/`(\w+)'/, '‘\1’').sub(/ -- /, ' — ')}\n\n"

        e.backtrace.each do |b|
          if b =~ /(.*?):(\d+)(?::in\s*`(.*?)')?/ then
            file, line, method = $1, $2, $3
            display_name = File.basename(file)
            str << "At line #{line} in ‘#{display_name}’ "
            str << (method ? "(inside method ‘#{method}’)" : "(top level)")
            str << "\n"
          end
        end

        str
      end


      # present an alert
      def alert(style, title, message, *buttons)
        styles = [:warning, :informational, :critical]
        raise "style must be one of #{types.inspect}" unless styles.include?(style)

        params = {'alertStyle' => style.to_s, 'messageTitle' => title, 'informativeText' => message, 'buttonTitles' => buttons}
        button_index = %x{#{TM_DIALOG} -ep #{e_sh params.to_plist}}.chomp.to_i
        buttons[button_index]
      end

      # show the system color picker and return a hex-format color (#RRGGBB).
      # If the input string is a recognizable hex string, the default color will be set to it.
      def request_color(string = nil)
        string = '#999' unless string.to_s.match(/#?[0-9A-F]{3,6}/i)
        color  = string
        prefix, string = string.match(/(#?)([0-9A-F]{3,6})/i)[1,2]
        string = $1 * 2 + $2 * 2 + $3 * 2 if string =~ /^(.)(.)(.)$/
        def_col = ' default color {' + string.scan(/../).map { |i| i.hex * 257 }.join(",") + '}'
        col = `osascript 2>/dev/null -e 'tell app "TextMate" to choose color#{def_col}'`
        return nil if col == "" # user cancelled -- when it happens, an exception is written to stderr
        col = col.scan(/\d+/).map { |i| "%02X" % (i.to_i / 257) }.join("")
    
        color = prefix
        if /(.)\1(.)\2(.)\3/.match(col) then
          color << $1 + $2 + $3
        else
          color << col
        end
        return color
      end
  
      # options should contain :title, :summary, and :log
      def simple_notification(options)
        raise if options.empty?

        support = ENV['TM_SUPPORT_PATH']
        nib     = support + '/nibs/SimpleNotificationWindow.nib'
    
        plist = Hash.new
        plist['title']    = options[:title]   || ''
        plist['summary']  = options[:summary] || ''
        plist['log']      = options[:log]     || ''

        `#{TM_DIALOG} -cqp #{e_sh plist.to_plist} #{e_sh nib} &> /dev/null &`
      end
  
      # Show Tooltip
      def tool_tip(content, options={}) # Possible options = {:format => :html|:text, :transparent => true}
        command = %{"$DIALOG" tooltip < /dev/null}
        command << ' --transparent' if options[:transparent]
        format = options[:format] ? options[:format].to_s : 'text'
        command << ' --' << format << ' ' << e_sh(content)
        %x{ #{command} }
      end
      
      # Interactive Code Completion Selector
      # Displays the pop-up completion menu with the list of +choices+ provided.
      # 
      # +choices+ should be an array of dictionaries with the following keys:
      # 
      # * +display+ -- The title to display in the suggestions list
      # * +insert+  -- Snippet to insert after selection
      # * +image+   -- An image name, see the <tt>:images</tt> option
      # * +match+   -- Typed text to filter on (defaults to +display+)
      # 
      # All options except +display+ are optional.
      # 
      # +options+ is a hash which can accept the following keys:
      #
      # * <tt>:extra_chars</tt>       -- by default only alphanumeric characters will be accepted,
      #   you can add additional characters to the list with this option.
      # 	This string is escaped for regex. List each character in a simple string EG: '{<#^'
      # * <tt>:case_insensitive</tt>  -- ignore case when filtering
      # * <tt>:static_prefix</tt>     -- a prefix which is used when filtering suggestions.
      # * <tt>:initial_filter</tt>    -- defaults to the current word
      # * <tt>:images</tt>            -- a +Hash+ of image names to paths
      # 
      # If a block is given, the selected item from the +choices+ array will be yielded
      # (with a new key +index+ added, which is the index of the +choice+ into the +choices+ array)
      # and the result of the block inserted as a snippet
      def complete(choices, options = {}, &block) #  :yields: choice
        pid = fork do
          STDOUT.reopen(open('/dev/null'))
          STDERR.reopen(open('/dev/null'))

          unless options.has_key? :initial_filter
            require ENV['TM_SUPPORT_PATH'] + '/lib/current_word'
            characters = "a-zA-Z0-9" # Hard-coded into D2
            characters += Regexp.escape(options[:extra_chars]) if options[:extra_chars]
            options[:initial_filter] = Word.current_word characters, :left
          end

          command =  "#{TM_DIALOG} popup --returnChoice"
          command << " --alreadyTyped #{e_sh options[:initial_filter]}"
          command << " --staticPrefix #{e_sh options[:static_prefix]}"           if options[:static_prefix]
          command << " --additionalWordCharacters #{e_sh options[:extra_chars]}" if options[:extra_chars]
          command << " --caseInsensitive"                                        if options[:case_insensitive]

          choices = choices.map! {|c| {'display' => c.to_s} } unless choices[0].is_a? Hash
          plist   = {'suggestions' => choices}

          result = ::IO.popen(command, 'w+') do |io|
            io << plist.to_plist; io.close_write
            OSX::PropertyList.load io rescue nil
          end

          # Use a default block if none was provided
          block ||= lambda do |choice|
            choice ? choice['insert'] : nil
          end

          # The block should return the text to insert as a snippet
          to_insert = block.call(result).to_s

          # Insert the snippet if necessary
          `"$DIALOG" x-insert --snippet #{e_sh to_insert}` unless to_insert.empty?
        end
      end
      
      # pop up a menu on screen
      def menu(options)
        return nil if options.empty?

        return_hash = true
        if options[0].kind_of?(String)
          return_hash = false
          options = options.collect { |e| e == nil ? { 'separator' => 1 } : { 'title' => e } }
        end

        res = ::IO.popen("#{TM_DIALOG} -u", "r+") do |io|
          Thread.new do
            plist = { 'menuItems' => options }.to_plist
            io.write plist; io.close_write
          end
          OSX::PropertyList::load(io)
        end

        return nil unless res.has_key? 'selectedIndex'
        index = res['selectedIndex'].to_i

        return return_hash ? options[index] : index
      end

      # request a single, simple string
      def request_string(options = Hash.new,&block)
        request_string_core('Enter string:', 'RequestString', options, &block)
      end
      
      # request a password or other text which should be obscured from view
      def request_secure_string(options = Hash.new,&block)
        request_string_core('Enter password:', 'RequestSecureString', options, &block)
      end
      
      # show a standard open file dialog
      def request_file(options = Hash.new,&block)
        _options = default_options_for_cocoa_dialog(options)
        _options["title"] = options[:title] || "Select File"
        _options["informative-text"] = options[:prompt] || ""
        _options["text"] = options[:default] || ""
        _options["select-only-directories"] = "" if options[:only_directories]
        _options["with-directory"] = options[:directory] if options[:directory]
        cocoa_dialog("fileselect", _options,&block)
      end
      
      # show a standard open file dialog, allowing multiple selections 
      def request_files(options = Hash.new,&block)
        _options = default_options_for_cocoa_dialog(options)
        _options["title"] = options[:title] || "Select File(s)"
        _options["informative-text"] = options[:prompt] || ""
        _options["text"] = options[:default] || ""
        _options["select-only-directories"] = "" if options[:only_directories]
        _options["with-directory"] = options[:directory] if options[:directory]
        _options["select-multiple"] = ""
        cocoa_dialog("fileselect", _options,&block)
      end
            
      # Request an item from a list of items
      def request_item(options = Hash.new,&block)
        items = options[:items] || []
        case items.size
        when 0 then block_given? ? raise(SystemExit) : nil
        when 1 then block_given? ? yield(items[0]) : items[0]
        else
          params = default_buttons(options)
          params["title"] = options[:title] || "Select item:"
          params["prompt"] = options[:prompt] || ""
          params["string"] = options[:default] || ""
          params["items"] = items

          return_plist = %x{#{TM_DIALOG} -cmp #{e_sh params.to_plist} #{e_sh(ENV['TM_SUPPORT_PATH'] + "/nibs/RequestItem")}}
          return_hash = OSX::PropertyList::load(return_plist)

          # return string is in hash->result->returnArgument.
          # If cancel button was clicked, hash->result is nil.
          return_value = return_hash['result']
          return_value = return_value['returnArgument'] if not return_value.nil?
          return_value = return_value.first if return_value.is_a? Array

          if return_value == nil then
            block_given? ? raise(SystemExit) : nil
          else
            block_given? ? yield(return_value) : return_value
          end
        end
      end
      
      # Post a confirmation alert
      def request_confirmation(options = Hash.new,&block)
        button1 = options[:button1] || "Continue"
        button2 = options[:button2] || "Cancel"
        title   = options[:title]   || "Something Happened"
        prompt  = options[:prompt]  || "Should we continue or cancel?"

        res = alert(:informational, title, prompt, button1, button2)

        if res == button1 then
          block_given? ? yield : true
        else
          block_given? ? raise(SystemExit) : false
        end
      end

        # Wrapper for tm_dialog. See the unit test in progress.rb
        class WindowNotFound < Exception
        end

        class Dialog    
          # instantiate an asynchronous nib
          # two ways to call:
          # Dialog.new(nib_path, parameters, defaults=nil)
          # Dialog.new(:nib => path, :parameters => params, [:defaults => defaults], [:center => true/false])
          def initialize(*args)
            nib_path, start_parameters, defaults, center = if args.size > 1
              args
            else
              args = args[0]
              [args[:nib], args[:parameters], args[:defaults], args[:center]]
            end

            center_arg = center.nil? ? '' : '-c'
            defaults_args = defaults.nil? ? '' : %Q{-d #{e_sh defaults.to_plist}}

            command = %Q{#{TM_DIALOG} -a #{center_arg} #{defaults_args} #{e_sh nib_path}}
            @dialog_token = ::IO.popen(command, 'w+') do |io|
              io << start_parameters.to_plist
              io.close_write
              io.read.chomp
            end
            
            raise WindowNotFound, "No such dialog (#{@dialog_token})\n} for command: #{command}" if $CHILD_STATUS != 0
      #      raise "No such dialog (#{@dialog_token})\n} for command: #{command}" if $CHILD_STATUS != 0

            # this is a workaround for a presumed Leopard bug, see log entry for revision 8566 for more info
            if animate = start_parameters['progressAnimate']
              open("|#{TM_DIALOG} -t#{@dialog_token}", "w") { |io| io << { 'progressAnimate' => animate }.to_plist }
            end
          end

          # wait for the user to press a button (with performButtonClick: or returnArguments: action)
          # or the close box. Returns a dictionary containing the return argument values.
          # If a block is given, wait_for_input will pass the return arguments to the block
          # in a continuous loop. The block must return true to continue the loop, false to break out of it.
          def wait_for_input
            wait_for_input_core = lambda do
              text = %x{#{TM_DIALOG} -w #{@dialog_token} }
              raise WindowNotFound if $CHILD_STATUS == 54528  # -43
              raise "Error (#{text})" if $CHILD_STATUS != 0

              OSX::PropertyList::load(text)
            end

            if block_given? then
              loop do
                should_continue = yield(wait_for_input_core.call)
                break unless should_continue
              end
            else
              wait_for_input_core.call
            end
          end

          # update bindings with new value(s)
          def parameters=(parameters)
            text = ::IO.popen("#{TM_DIALOG} -t #{@dialog_token}", 'w+') do |io|
              io << parameters.to_plist
              io.close_write
              io.read
            end
            raise "Could not update (#{text})" if $CHILD_STATUS != 0
          end
          
          # close the window
          def close
            %x{#{TM_DIALOG} -x #{@dialog_token}}
          end

        end

      private
      
      # common to request_string, request_secure_string
      def request_string_core(default_prompt, nib_name, options, &block)
        params = default_buttons(options)
        params["title"] = options[:title] || default_prompt
        params["prompt"] = options[:prompt] || ""
        params["string"] = options[:default] || ""
        
        return_plist = %x{#{TM_DIALOG} -cmp #{e_sh params.to_plist} #{e_sh(ENV['TM_SUPPORT_PATH'] + "/nibs/#{nib_name}")}}
        return_hash = OSX::PropertyList::load(return_plist)
        
        # return string is in hash->result->returnArgument.
        # If cancel button was clicked, hash->result is nil.
        return_value = return_hash['result']
        return_value = return_value['returnArgument'] if not return_value.nil?
        
        if return_value == nil then
          block_given? ? raise(SystemExit) : nil
        else
          block_given? ? yield(return_value) : return_value
        end
      end

      def cocoa_dialog(type, options)
        str = ""
        options.each_pair do |key, value|
          unless value.nil?
            str << " --#{e_sh key} "
            str << Array(value).map { |s| e_sh s }.join(" ")
          end
        end
        cd = ENV['TM_SUPPORT_PATH'] + '/bin/CocoaDialog.app/Contents/MacOS/CocoaDialog'
        result = %x{#{e_sh cd} 2>/dev/console #{e_sh type} #{str} --float}
        result = result.to_a.map{|line| line.chomp}
        if (type == "fileselect")
          if result.length == 0
            return_value = options['button2'] # simulate cancel
          end
        else
          return_value, result = *result
        end
        if return_value == options["button2"] then
          block_given? ? raise(SystemExit) : nil
        else
          block_given? ? yield(result) : result
        end
      end
      
      def default_buttons(user_options = Hash.new)
        options = Hash.new
        options['button1'] = user_options[:button1] || "OK"
        options['button2'] = user_options[:button2] || "Cancel"
        options
      end
      
      def default_options_for_cocoa_dialog(user_options = Hash.new)
        options = default_buttons(user_options)
        options["string-output"] = ""
        options
      end
      
    end
  end
end

# interactive unit tests
if $0 == __FILE__
require "test/unit"
# =========================
# = request_secure_string =
# =========================
# puts TextMate::UI.request_secure_string(:title => "Hotness", :prompt => 'Please enter some hotness', :default => 'teh hotness')

# ================
# = request_item =
# ================
# puts TextMate::UI.request_item(:title => "Hotness", :prompt => 'Please enter some hotness', :items => ['hotness', 'coolness', 'iceness'])

# ========
# = Misc =
# ========
# params = {'title' => "Hotness", 'prompt' => 'Please enter some hotness', 'string' => 'teh hotness'}
# return_value = %x{#{TM_DIALOG} -cmp #{e_sh params.to_plist} #{e_sh(ENV['TM_SUPPORT_PATH'] + '/nibs/RequestString')}}
# return_hash = OSX::PropertyList::load(return_value)
# puts return_hash['result'].inspect

# ==========
# = dialog =
# ==========
#  puts TextMate::UI.dialog(:nib => , :parameters => , :center => true)

# ===============
# = alert usage =
# ===============
#	result = TextMate::UI.alert(:warning, 'The wallaby has escaped.', 'The hard disk may be full, or maybe you should try using a larger cage.', 'Dagnabit', 'I Am Relieved', 'Heavens')
# 
#	puts "Button pressed: #{result}"


# ==================
# = complete usage =
# ==================
# HOW TO TEST:
# 1) Place your caret on the blank line in one of the test methods
# 2) Use "Run Focused Unit Test" 

ENV['WEB_PREVIEW_RUBY']='NO-RUN'
class TestCompletes < Test::Unit::TestCase
  def test_basic_completion
    #Should complete the snippet, if there is one, without requiring a block
    TextMate::UI.complete(@choices)
    # 
  end
  
  def test_with_images
    @images = {
      "Macro"      => "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Macros.png",
      "Language"   => "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Languages.png",
      "Template"   => "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Template Files.png",
      "Templates"  => "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Templates.png",
      "Snippet"    => "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Snippets.png",
      "Preference" => "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Preferences.png",
      "Drag"       => "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Drag Commands.png",
      "Command"    => "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Commands.png"
    }
    
    TextMate::UI.complete @choices, :images => @images
    # 
  end
  
  def test_with_block
    #Use a block to create a custom snippet to be inserted, the block gets passed your choice as a hash
    # Cancelling the popup will pass nil to the block
    TextMate::UI.complete(@choices){|choice| e_sn choice.inspect }
    # 
  end
  
  def test_nested_or_stacked
    # Nested completes
    # Put a complete in the block of another complete 
    # to make it wait for you to choose the first before starting the next.
    TextMate::UI.complete(@choices) do |choice_a|
      TextMate::UI.complete(@choices) do |choice_b|
        TextMate::UI.complete(@choices) do |choice_c|
          choice_c['insert']
        end
        choice_b['insert']
      end
      choice_a['insert']
    end
    # 
  end
  
  def test_display_different_from_match
    @choices = [
      {'match' => 'moo', 'display' => 'Hairy Monkey'},
      {'match' => 'foo', 'display' => 'Purple Turtles'},
      {'match' => 'bar', 'display' => 'Angry Elephant'},
    ]
    TextMate::UI.complete(@choices)
    # 
  end
  
  def test_with_extra_chars
    @choices = [
      {'display' => '^moo'},
      {'display' => '$foo'},
      {'display' => '\bar'},
      {'display' => '.bar'},
    ]
    TextMate::UI.complete(@choices, :extra_chars => '^$\.')
    # ^
    # $
    # \
    # .
  end
  
  def test_with_tooltip_format
    # Should show a tooltip in the correct format
    @choices = [
      {'image' => 'Drag',    'display' => 'text', 'insert' => '(${1:one}, ${2:one}, ${3:three}${4:, ${5:five}, ${6:six}})',     'tool_tip_format' => "text", 'tool_tip' => "<div> not html <div>"},
      {'image' => 'Macro',   'display' => 'html', 'insert' => '(${1:one}, "${2:one}", ${3:three}${4:, ${5:five}, ${6:six}})',   'tool_tip_format' => "html", 'tool_tip' => "<div><strong> html </strong></div>"},
      {'image' => 'Command', 'display' => 'text', 'insert' => '(${1:one}, ${2:one}, "${3:three}"${4:, "${5:five}", ${6:six}})',                              'tool_tip' => "<div> not html <div>"},
    ]
    TextMate::UI.complete(@choices)
    # 
  end
  
  def test_with_tooltips
    # Should show a tooltip that includes the prefix
    TextMate::UI.complete(@choices, {:tool_tip_prefix => 'prefix'})
    # 
  end
  
  private
  def setup
    make_front!
    @choices = [
      {'image' => 'Drag',    'display' => 'moo', 'insert' => '(${1:one}, ${2:one}, ${3:three}${4:, ${5:five}, ${6:six}})',     'tool_tip_format' => "text", 'tool_tip' => "(one, two, four[, five])\n This method does something or other maybe.\n Insert longer description of it here."},
      {'image' => 'Macro',   'display' => 'foo', 'insert' => '(${1:one}, "${2:one}", ${3:three}${4:, ${5:five}, ${6:six}})',   'tool_tip_format' => "html", 'tool_tip' => "(one, two)\n This method does something or other maybe.\n Insert longer description of it here."},
      {'image' => 'Command', 'display' => 'bar', 'insert' => '(${1:one}, ${2:one}, "${3:three}"${4:, "${5:five}", ${6:six}})',                              'tool_tip' => "(one, two[, three])\n This method does something or other maybe.\n Insert longer description of it here."},
    ]
  end
  def make_front!
    `open "txmt://open?url=file://$TM_FILEPATH"` #For testing purposes, make this document the topmost so that the complete popup works
  end
end


# ==============
# = menu usage =
# ==============
class TestMenu < Test::Unit::TestCase
  def test_should_accept_array_of_strings
    @items = [
      'item1',
      'item2',
      'item3',
    ]
    t = TextMate::UI.menu(@items)
    assert_equal(0, t)
    # 
  end
  
  def test_should_accept_array_of_hashes
    @items = [
      { 'title' => 'item1' },
      { 'title' => 'item2' },
      { 'title' => 'item3' },
    ]
    t = TextMate::UI.menu(@items)
    assert_equal({"title"=>"item1"}, t)
    # 
  end
  
  def test_should_return_nil_on_empty_set
    @items = [
    ]
    t = TextMate::UI.menu(@items)
    assert_equal(nil, t)
    # 
  end
  
  def test_should_return_nil_on_abort
    @items = [
      'Tester: Hit Escape!'
    ]
    t = TextMate::UI.menu(@items)
    assert_equal(nil, t, 'You need to his escape when the menu comes up to get this test to pass')
    # 
  end
  
  def test_should_work_with_dialog1
  end
  
  def test_should_work_with_dialog2
  end
  
  private
  def setup
    @items = []
  end
end

# ==================
# = tool_tip usage =
# ==================

class TestToolTips < Test::Unit::TestCase
  def test_basic_tooltip
    # Insert normal text for a normal tool_tip:
    TextMate::UI.tool_tip('Normal Tooltip')
  end
  def test_transparent
    # Use the :transparent option to make custom shaped tool_tips:
    TextMate::UI.tool_tip('<h1 style="background:white; -webkit-border-radius: 15px; padding:1em; -webkit-transform: rotate(5deg); margin-top:100px">Transparent Tooltip!</h1>', {:transparent => true, :format => :html})
  end
  def test_html
    # Use the :format option to use html in your tool_tip:
    TextMate::UI.tool_tip <<-HTML, :format => :html
    <h1>
      Allow <strong>html</strong>
    </h1>
    <p>To be used</p>
    HTML
  end
  def test_text_formatting
    # Text is also the default format
    TextMate::UI.tool_tip <<-TEXT, :format => :text
This 
  should    keep 
    all the whitespace 
      that    is    given 
        in     this      here
          s    t    r    i    n    g
    TEXT
  end
end

end #Tests

