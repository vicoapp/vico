# encoding: utf-8
 
# TextMate Code Completion
# Version: 9
# By: Thomas Aylott / subtleGradient, oblivious@
# 

require "#{ENV['TM_SUPPORT_PATH']}/lib/ui"
USE_DIALOG2 = ENV['DIALOG'] =~ /2$/ # DIALOG 2

class TextmateCodeCompletion
  $debug_codecompletion = {}
  
  EMPTY_ROW = /(^\s*$)/
  
  class << self
    def parse_options(options={})
      options[:split      ] = ENV['TM_COMPLETION_split'      ] if ENV['TM_COMPLETION_split'      ]
      options[:characters ] = ENV['TM_COMPLETION_characters' ] if ENV['TM_COMPLETION_characters' ]
      options[:filter     ] = ENV['TM_COMPLETION_filter'     ] if ENV['TM_COMPLETION_filter'     ]
      options[:nil_context] = ENV['TM_COMPLETION_nil_context'] if ENV['TM_COMPLETION_nil_context']
      options[:padding    ] = ENV['TM_COMPLETION_padding'    ] if ENV['TM_COMPLETION_padding'    ]
      options[:select     ] = ENV['TM_COMPLETION_select'     ] if ENV['TM_COMPLETION_select'     ]
      options[:sort       ] = ENV['TM_COMPLETION_sort'       ] if ENV['TM_COMPLETION_sort'       ]
      options[:unique     ] = ENV['TM_COMPLETION_unique'     ] if ENV['TM_COMPLETION_unique'     ]
      options[:scope      ] = ENV['TM_COMPLETION_scope'      ].to_sym if ENV['TM_COMPLETION_scope'      ]
      
      options[:sort       ] = true  if options[:sort       ] == 'true'
      options[:sort       ] = false if options[:sort       ] == 'false'
      options[:unique     ] = true  if options[:unique     ] == 'true'
      options[:unique     ] = false if options[:unique     ] == 'false'
      return options
    end
    def go!(options={})
      options = TextmateCodeCompletion.parse_options(options)
      
      if USE_DIALOG2
        
        if options[:split] == 'plist'
          choices = TextmateCompletionsPlist.new(ENV['TM_COMPLETIONS']).to_ary
        else
          choices = TextmateCompletionsText.new(ENV['TM_COMPLETIONS'],{:split=>','}.merge(options)).to_ary
        end
        return print(TextmateCodeCompletion.new( choices, STDIN.read, options ).to_snippet)
      end
      
      if options[:split] == 'plist'
        choices = TextmateCompletionsPlist.new(ENV['TM_COMPLETIONS']).to_ary
      else
        choices = TextmateCompletionsText.new(ENV['TM_COMPLETIONS'],{:split=>','}.merge(options)).to_ary
      end
      
      
      print TextmateCodeCompletion.new( choices, STDIN.read, options ).to_snippet
    end
    
    # DEPRECATED
    def plist(preference='Completions')
      choices = TextmateCompletionsPlist.new( "#{ENV['TM_BUNDLE_PATH']}/Preferences/#{preference}#{'.tmPreferences' if preference !~ /\./}" )
      print TextmateCodeCompletion.new(choices,STDIN.read).to_snippet
    end
    
    def txt(file='Completions.txt')
      choices = TextmateCompletionsText.new( "#{ENV['TM_BUNDLE_PATH']}/Support/#{file}" )
      print TextmateCodeCompletion.new(choices,STDIN.read).to_snippet
    end
    
    alias :simple :plist
  end
  
  def initialize(choices=nil,line=nil,options={})
    options = TextmateCodeCompletion.parse_options(options)
    
    @options = {}
    @options[:characters] = /\w+$/
    
    @options.merge!(options)
    @options.merge!(TextmateCompletionsParser::PARSERS[options[:scope]] || {}) if options[:scope]
    
    @debug = true
    
    @has_selection = ENV['TM_SELECTED_TEXT'] == line
    
    @line = line
    set_line!
    
    cancel() and return if choices.is_a? String
    cancel() and return unless choices and choices.to_ary and !choices.to_ary.empty?
    
    @choices = choices.to_ary
    @choice = false
    
    filter_choices!
    choose() unless @choice
  # rescue
    # cancel()
  end
  
  def choice
    @choice
  end
  
  def index
    @choice_i
  end
  
  def to_snippet
    completion()
  end
  
  private
  def cancel
    @choice = ''
    @cancel = true
  end
  
  def set_line!
    @raw_line = ENV['TM_CURRENT_LINE']
    
    caret_placement()
    
    @line_before = @raw_line[0..caret_placement]
    @line_before = '' if caret_placement == -1
    get_choice_partial!
    @selection   = @line if @has_selection
    @line_after  = @raw_line[caret_placement+1..@raw_line.length+1]
    
    @line_before.gsub!(/#{Regexp.escape @choice_partial}$/,'')
    @line_after.gsub!(/^#{Regexp.escape @selection}/,'') if @selection
    
    cancel() if @options[:nil_context]==false and (!@line_before or @line_before == '')
    
    if @debug
      $debug_codecompletion["caret_placement"] = caret_placement+2
      $debug_codecompletion["line_before"    ] = @line_before
      $debug_codecompletion["choice_partial" ] = @choice_partial
      $debug_codecompletion["selection"      ] = @selection
      $debug_codecompletion["line_after"     ] = @line_after
    end
  end
  
  def caret_placement
    return @caret_placement if @caret_placement
    
    caret_placement = 0
    caret_placement = ENV['TM_COLUMN_NUMBER'].to_i - 2
    caret_placement = ENV['TM_INPUT_START_COLUMN'].to_i - 2 if @has_selection
    # caret_placement = 0 if caret_placement < 0
    
    # Fix those dang tabs being longer than 1 character
    if @raw_line =~ /\t/
      tabs_to_spaces = ''; ENV['TM_TAB_SIZE'].to_i.times {tabs_to_spaces<<' '}
      
      number_of_tabs_before_cursor = 0
      unless caret_placement <= 0
        number_of_tabs_before_cursor = @raw_line.gsub(' ','X').gsub("\t",tabs_to_spaces)[0..caret_placement].gsub(/[^ ]/,'').length / ENV['TM_TAB_SIZE'].to_i
      end
      
      add_to_caret_placement  = 0
      add_to_caret_placement -= number_of_tabs_before_cursor * ENV['TM_TAB_SIZE'].to_i
      add_to_caret_placement += number_of_tabs_before_cursor
      
      caret_placement += add_to_caret_placement
    end
    
    @caret_placement = caret_placement
  end
  
  def get_choice_partial!
    return nil unless @line_before
    
    @choice_partial = @line_before.scan(@options[:characters]).to_s || ''
    if @options[:context]
      match = @line_before.match(@options[:context])
      @strip_partial = match[1].to_s if match
      cancel() unless @strip_partial
      
      $debug_codecompletion["match"] = match
    end
    
    $debug_codecompletion["strip"] = @options[:context]
    $debug_codecompletion["strip_partial"] = @strip_partial
  end
  
  def filter_choices!
    cancel() and return if @choices.length == @choices.grep(EMPTY_ROW).length
    
    # Convert the empties to seperators
    # Unless they're the first or last choice
    while @choices.first =~ EMPTY_ROW
      @choices.delete_at(0)
    end
    while @choices.last =~ EMPTY_ROW
      @choices.delete_at(@choices.length-1)
    end
    @choices.each_with_index do |e, i|
      @choices[i] = '--' if e =~ EMPTY_ROW
    end
    
    @choices.each {|e| e.gsub!(@strip_partial,'\1') } if @options[:context] and @strip_partial
    @choices = @choices - @choices.grep(@options[:context]).uniq if @strip_partial
    
    @choices = @choices.grep(/^#{Regexp.escape @choice_partial}/).uniq if @choice_partial #and @choice_partial != ''
    @choices.sort! if @options[:sort] 
  end
  
  def choose
    cancel() and return if @cancel
    cancel() and return unless @choices and @choices!=[]
    
    if @choices.length == 1
      val = 0
    else
      val = TextMate::UI.menu(@choices)
    end
    cancel() and return unless val
    @choice_i = val
    @choice = @choices[val]
  end
  
  def completion
    $debug_codecompletion["choice"]  = @choice
    $debug_codecompletion["cancel"]  = @cancel
    $debug_codecompletion["choices"] = @choices
    
    completion = ''
    completion << snip(@line_before) unless @has_selection
    if @cancel
      completion << snip(@choice_partial)
      completion << "${0:#{snip(@selection)}}"
    else
      if @choice
        completion << @options[:padding] unless @line_before.match(/#{Regexp.escape @options[:padding]}$/) or @choice.match(/^#{Regexp.escape @options[:padding]}/) if @options[:padding]
        completion << snippetize(@choice) unless @cancel
      else
        completion << snip(@selection) if @selection
      end
    end
    completion << snip(@line_after) unless @has_selection if @line_after
    completion
  end
  
  def snippetize(text)
    text.gsub!(/^#{Regexp.escape @choice_partial}/,'') if @has_selection # Trimoff the choice_partial if we have a selection
    
    snippet = ''
    # snippet << '${101:'
    snippet << snippetize_quotes(snippetize_methods(text))
    # snippet << '}$100'
    snippet << '$0'
    snippet
  end
  
  def snippetize_methods(text)
    text = text.to_s
    @place = 0
    text.gsub!(/(\$)/) { |g| snip($1) }
    text.gsub!(/([\(,])([^\),]*)/) do |g|
      thing = $2
      "#{$1}${#{@place += 1}:#{snippetize_quotes(thing,true)}}"
    end
    text
  end
  def snippetize_quotes(text,escape=false)
    text = text.to_s
    text = snip(text,escape) if escape
    text.gsub!(/(["'])(?!\$\{)(.*?)(\1)/) do |g|
      thing = $2
      thing1 = $3
      "#{$1}${#{@place += 1}:#{snippetize_quotes(thing,!escape)}}#{thing1}"
    end
    text
  end
  
  def snip(text,escape_bracket=false) #make snippet proof
    chars = /(\$|\`)/
    chars = /(\$|\`|\})/ if escape_bracket
    text.to_s.gsub(chars,'\\\\\\1')
  end
end

class TextmateCompletionsPlist
  attr_accessor :raw
  attr_accessor :scope
  attr_accessor :format
  attr_accessor :choices
  attr_accessor :parsed
  
  def initialize(path=nil,options={})
    require "#{ENV['TM_SUPPORT_PATH']}/lib/osx/plist"
    
    if path.match(/\{/)
      self.raw = path.to_s
      @fullsize = false
    else
      return false unless File.exist?(path)
      self.raw = File.read(path)
      @fullsize = true
    end
    
    @parsed = OSX::PropertyList.load(self.raw)
    # p parsed unless parsed.is_a? Array
    p @parsed if @parsed.is_a? Array
    @parsed = @parsed.first if @parsed.is_a? Array
    
    self.scope   = @parsed['scope'].split(/, ?/) if @fullsize and @parsed['scope']
    
    # This is for parsing tmPreference file completions directly from the bundle. DEPRECATED
    self.choices = (@fullsize ? @parsed['settings'] : @parsed)['completions']
    
    # This is for parsing the new format of plist that is used in Dialog2
    self.choices = @parsed['suggestions'] if @parsed['suggestions']
    
    self.format  = self.choices[0].is_a?(Array) ? :array : :hash
  end
  
  def to_ary
    return self.choices if self.format == :array
    return self.choices.map{|c|c['title'] || c['match'] || c['display']}
  end
  def to_hash
    # return self.choices if self.choices.is_a? Hash
    
    self.choices = self.choices.map do |choice|
      next unless choice and choice.respond_to? :to_str or choice.respond_to? :keys
      
      hashed_choice ||= choice if choice.respond_to? :keys
      
      if choice.respond_to? :to_str and choice.to_str =~ /^--/
        hashed_choice ||= { 'separator' => choice.to_str.gsub(/^-+\s*|\s*-+$/,'') } 
      end
      
      # Add all characters in every choice to the extra_chars
      # @extra_chars ||= []
      # @extra_chars += choice.to_str.scan(/[^a-z]/i)
      # @extra_chars.uniq!
      
      hashed_choice ||= { 'display' => choice.to_str }
      
      hashed_choice
    end
    
    return {'completions' => self.choices, 'extra_chars' => @extra_chars, 'images' => @images}
    
  end
end

class TextmateCompletionsText
  attr :raw, true
  attr :scope, true
  attr :choices, true
  
  def initialize(path,options={})
    return false unless path
    
    options[:split] ||= "\n"
    
    if path.match(options[:split])
      self.raw = path.to_s
    else
      return false unless File.exist?(path)
      self.raw = File.new(path).read
    end
    
    self.scope   = nil
    self.choices = self.raw.split(options[:split])
    
    self.choices = self.choices - self.choices.grep(options[:filter]) if options[:filter]
  end
  
  def to_ary
    self.choices
  end
end

class TextmateCompletionsParser
  PARSERS = {}
  
  def initialize(filepath=nil, options={})
    unless options[:debug] and filepath.is_a? String
      path = filepath || ENV['TM_FILEPATH']
      return false unless path and File.exist?(path)
      return false if File.directory?(path)
      
      @raw = IO.read(path)
    else
      @raw = filepath
    end
    
    @options = {}
    @options[:split] = "\n"
    
    @options.merge!(options)
    @options.merge!(PARSERS[options[:scope]]) if options[:scope]
    
    @raw = @raw.split(@options[:split])
    
    @filter  = arrayify @options[:filter]
    @selects = arrayify @options[:select]
    collect_selects!
    
    render!()
    @rendered.sort! if @options[:sort]
  end
  
  def to_ary
    @rendered
  end
  
  private
  def render!
    @filter.each do |filter|
      @raw -= @raw.grep(filter)
    end
    
    @rendered = @raw
    @rendered = @raw.grep(@select)
    
    @rendered.each do |r|
      @selects.each do |select|
        r.gsub!(select,'\1')
      end
    end
    
    @rendered -= @rendered.grep(/^\s*$/)
  end
  
  def collect_selects!
    @select = Regexp.new(@selects.collect do |select|
      select.to_s << '|'
    end.to_s.gsub(/\|$/,''))
  end
end

def arrayify(anything)
  anything.is_a?(Array) ? anything : [anything]
end

TextmateCompletionsParser::PARSERS[:css] = {
  :select =>[%r/^([#\.][a-z][-_\w\d]*)\b.*/i, #Ids and Classes
             %r/.*(?:id="(.*?)"|id='(.*?)').*/ #IDs in HTML
            ], 
  :filter =>[%r/^#([0-9a-f]{6}|[0-9a-f]{3})/,
             %r/^..*#.*$/
            ],
  :sort       => true,
  :split      => /[,;\n\s{}]|(\/\*|\*\/)/,
  :characters => /[-_:#\.\w]+$|\.$/
}

TextmateCompletionsParser::PARSERS[:css_values] = {
  :select =>[%r/(url\(.*?\))/,#URLs
             %r/(#([0-9a-f]{6}|[0-9a-f]{3}))/i, #HEX colors
            ],
  :sort   => true,
  :characters => /[#0-9a-z]+$/,
  :split      => /[ :;]/
}

TextmateCompletionsParser::PARSERS[:html_attributes] = {
  :sort        => true,
  :characters  => /(?:<\w+\b ?)?(\b\w*)$/, 
  :context     => /(<[^\s>]+ ?)([^>]*(<\B.*?\B>)?)+$/,
  :nil_context => false,
  :padding     => ' ',
}

TextmateCompletionsParser::PARSERS[:ruby] = {
  :select =>[%r/^[ \t]*(?:class)\s*(.*?)\s*(<.*?)?\s*(#.*)?$/,
             %r/^[ \t]*(?:def)\s*(.*?(\([^\)]*\))?)\s*(<.*?)?\s*(#.*)?$/,
             %r/^[ \t]*(?:attr_.*?)\s*(.*?(\([^\)]*\))?)\s*(<.*?)?\s*(#.*)?$/
            ], 
  :filter => [/test_/,'< Test::Unit::TestCase']
}

# ================= #
# =     TESTS     = #
# ================= #
if $0 == __FILE__

require 'test/unit'
require "stringio"
# STDIN = StringIO.new

puts "\nJust keep hittin' 1\n\n"

def print(text)
  return text
end
# =begin
class TextmateCodeCompletionTest < Test::Unit::TestCase
  def test_blank
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "", "TM_COLUMN_NUMBER" => "1", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal "test$0", TextmateCodeCompletion.new(['test']).to_snippet
  end
  def test_basic
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "basic", "TM_COLUMN_NUMBER" => "6", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal "basic$0", TextmateCodeCompletion.new(['basic'], %{basic}).to_snippet
  end
  
  def test_a
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "a", "TM_COLUMN_NUMBER" => "2", "TM_INPUT_START_COLUMN" => "1"})
    tcc = TextmateCodeCompletion.new(['aaa'], %{a})
    assert_equal "aaa$0", tcc.to_snippet  , $debug_codecompletion.inspect
    assert_equal 0, tcc.index             , $debug_codecompletion.inspect
    assert_equal 'aaa', tcc.choice        , $debug_codecompletion.inspect
  end
  
  def test_choices
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "\t", "TM_COLUMN_NUMBER" => "3", "TM_BUNDLE_PATH" => "#{ENV['TM_BUNDLE_PATH']}../CSS.tmbundle", "TM_INPUT_START_COLUMN" => "1"})
    
    TextmateCodeCompletion.new([' ','  ','real1','   ','real2','    '],  "\t").to_snippet
    assert_equal '--', $debug_codecompletion['choices'][1], $debug_codecompletion.inspect
    assert_equal 3, $debug_codecompletion['choices'].length, $debug_codecompletion.inspect
    
    assert_equal "\t${0:}", TextmateCodeCompletion.new('',    "\t").to_snippet, $debug_codecompletion.inspect
    assert_equal "\t${0:}", TextmateCodeCompletion.new(nil,   "\t").to_snippet, $debug_codecompletion.inspect
    assert_equal "\t${0:}", TextmateCodeCompletion.new([nil], "\t").to_snippet, $debug_codecompletion.inspect
    assert_equal "\t${0:}", TextmateCodeCompletion.new([''],  "\t").to_snippet, $debug_codecompletion.inspect
  end
  
  def test_in_snippet
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => %{${1:snippet}}, "TM_COLUMN_NUMBER" => "12", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal '\${1:snippet${0:}}', TextmateCodeCompletion.new(['nomatch'], %{${1:snippet}}).to_snippet
  end
  def test_in_snippet_match
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => %{${1:snippet}}, "TM_COLUMN_NUMBER" => "12", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal '\${1:snippet$0}', TextmateCodeCompletion.new(['snippet'], %{${1:snippet}}).to_snippet
  end
  
  def test_choice_partial_selection
    set_tm_vars({"TM_SELECTED_TEXT" => "selection", "TM_CURRENT_LINE" => "choice_partialselection", "TM_COLUMN_NUMBER" => "24", "TM_INPUT_START_COLUMN" => "15"})
    assert_equal "choice_partial${0:selection}", TextmateCodeCompletion.new(['test'], %{selection}).to_snippet, $debug_codecompletion.inspect
  end
  def test_choice_partial_selection_match
    set_tm_vars({"TM_SELECTED_TEXT" => "selection", "TM_CURRENT_LINE" => "choice_partialselection", "TM_COLUMN_NUMBER" => "24", "TM_INPUT_START_COLUMN" => "15"})
    assert_equal "_match$0", TextmateCodeCompletion.new(['choice_partial_match'], %{selection}).to_snippet, $debug_codecompletion.inspect
  end
  
  def test_selection_no_line
    set_tm_vars({"TM_SELECTED_TEXT" => "basic_selection", "TM_CURRENT_LINE" => "basic_selection", "TM_COLUMN_NUMBER" => "1", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal "test_selection$0", TextmateCodeCompletion.new(['test_selection'], %{basic_selection}).to_snippet, $debug_codecompletion.inspect
  end
  
  def test_snippetize
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "String", "TM_COLUMN_NUMBER" => "7", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal "String.method(${1:})$0", TextmateCodeCompletion.new(['String.method()'], %{String}).to_snippet, $debug_codecompletion.inspect
  end
  
  def test_snippetize_methods
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "String", "TM_COLUMN_NUMBER" => "7", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{String.method(${1:"${2:one}"},${3:two})(${4:})$0}, TextmateCodeCompletion.new(['String.method("one",two)()'], %{String}).to_snippet, $debug_codecompletion.inspect
  end
  def test_snippetize_methods_with_stuff
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "change_column", "TM_COLUMN_NUMBER" => "14", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal 'change_column(${1:table_name},${2: column_name},${3: type},${4: options = {\}})$0', TextmateCodeCompletion.new([%{change_column(table_name, column_name, type, options = {})}],'').to_snippet, $debug_codecompletion.inspect
  end
  def test_snippetize_bracket_escaping
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "{before} {inside} {after}", "TM_COLUMN_NUMBER" => "14","TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{{before} {ins${0:}ide} {after}}, TextmateCodeCompletion.new(['test'], %{{before} {inside} {after}}).to_snippet, $debug_codecompletion.inspect
  end
  def test_snippetize_quotes
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "String", "TM_COLUMN_NUMBER" => "7", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{String="${1:some '${2:thing}'}"$0}, TextmateCodeCompletion.new([%{String="some 'thing'"}], %{String}).to_snippet, $debug_codecompletion.inspect
  end
  
  def test_spaces
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "  padding-top: 1px;", "TM_COLUMN_NUMBER" => "10", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal "  padding_is_awesome$0-top: 1px;", TextmateCodeCompletion.new(['padding_is_awesome'], %{  padding-top: 1px;}).to_snippet, $debug_codecompletion.inspect
  end
  def test_tabs
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "\t\t\t\tpadding-top: 1px;", "TM_COLUMN_NUMBER" => "16", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal "\t\t\t\tpadding_is_awesome$0-top: 1px;", TextmateCodeCompletion.new(['padding_is_awesome'], "\t\t\t\tpadding-top: 1px;").to_snippet, $debug_codecompletion.inspect
    
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "\tpadding-top: 1px;", "TM_COLUMN_NUMBER" => "10", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal "\tpadding_is_awesome$0-top: 1px;", TextmateCodeCompletion.new(['padding_is_awesome'], %{	padding-top: 1px;}).to_snippet, $debug_codecompletion.inspect
    
    # Make sure it's not also recalculating the tabs after the cursor position
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "\t\t\t\tpadding\t\t\t\t-top: 1px;", "TM_COLUMN_NUMBER" => "16", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal "\t\t\t\tpadding_is_awesome$0\t\t\t\t-top: 1px;", TextmateCodeCompletion.new(['padding_is_awesome'], "\t\t\t\tpadding\t\t\t\t-top: 1px;").to_snippet, $debug_codecompletion.inspect
    
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "\tpadding\t\t\t\t-top: 1px;", "TM_COLUMN_NUMBER" => "10", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal "\tpadding_is_awesome$0\t\t\t\t-top: 1px;", TextmateCodeCompletion.new(['padding_is_awesome'], "\tpadding\t\t\t\t-top: 1px;").to_snippet, $debug_codecompletion.inspect
  end
  
  def test_extra_word_characters
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => ".", "TM_COLUMN_NUMBER" => "2", "TM_INPUT_START_COLUMN" => "1"})
    tcc = TextmateCodeCompletion.new(['.aaa'], %{.}, {:characters => /[-_:#\.\w]$/})
    assert_equal ".aaa$0", tcc.to_snippet  , $debug_codecompletion.inspect
    assert_equal 0, tcc.index              , $debug_codecompletion.inspect
    assert_equal '.aaa', tcc.choice        , $debug_codecompletion.inspect
  end
  
  def test_sort
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "basic", "TM_COLUMN_NUMBER" => "6", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal "basic$0", TextmateCodeCompletion.new(
      %w[basic2 basic3 basic basic1], 
      %{basic},
      {:sort => true}
    ).to_snippet
  end
  
  def test_html
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "<div><p><a><img ></a></p></div>", "TM_COLUMN_NUMBER" => "17", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{<div><p><a><img one="${1:}"$0></a></p></div>}, TextmateCodeCompletion.new(
      ['<img one=""','<img two=""','<div three=""','<div four=""'], 
      %{<div><p><a><img ></a></p></div>}, 
      {:scope => :html_attributes}
    ).to_snippet, $debug_codecompletion.inspect
  end
  def test_context_sensitive_filter
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => %{<div><p><a><img class="Value" t></a></p></div>}, "TM_COLUMN_NUMBER" => "32", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{<div><p><a><img class="Value" talc="${1:}"$0></a></p></div>}, TextmateCodeCompletion.new(
      ['class=""','turtles=""','talc=""','id=""','zero=""','nada=""','<img one=""','<img two=""','<div three=""','<div four=""'], 
      %{<div><p><a><img class="Value" t></a></p></div>}, 
      {:scope => :html_attributes}
    ).to_snippet, $debug_codecompletion.inspect
  end
  def test_html_with_other_attributes
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "<div><p><a><img class=\"Value\" ></a></p></div>", "TM_COLUMN_NUMBER" => "31", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{<div><p><a><img class="Value" class="${1:}"$0></a></p></div>}, TextmateCodeCompletion.new(
      ['<img id=""','<div id=""','<div class=""','<img class=""',], 
      %{<div><p><a><img class="Value" ></a></p></div>}, 
      {:scope => :html_attributes}
    ).to_snippet, $debug_codecompletion.inspect
  end
  def test_html_with_embedded_source
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => %{<div><p><a><img class="<%= something %>" ></a></p></div>}, "TM_COLUMN_NUMBER" => "42", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{<div><p><a><img class="<%= something %>" class="${1:}"$0></a></p></div>}, TextmateCodeCompletion.new(
      ['<img id=""','<div id=""','<div class=""','<img class=""',], 
      %{<div><p><a><img class="<%= something %>" ></a></p></div>}, 
      {:scope => :html_attributes}
    ).to_snippet, $debug_codecompletion.inspect
  end
  
  def test_padding
    # Insert the padding character if it's not there already
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "<img.>", "TM_COLUMN_NUMBER" => "6", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{<img. test$0>}, TextmateCodeCompletion.new(['test'], %{<img.>}, :padding => ' ').to_snippet, $debug_codecompletion.inspect
  end
  def test_no_padding
    # Don't insert the padding text if it's already there
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "<img >", "TM_COLUMN_NUMBER" => "6", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{<img test$0>}, TextmateCodeCompletion.new(['test'], %{<img >}, :scope => :html_attributes).to_snippet, $debug_codecompletion.inspect
  end
    
  def test_nil_line_before
    # Do insert if there's no line_before text
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => ">", "TM_COLUMN_NUMBER" => "1", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{test$0>}, TextmateCodeCompletion.new(['test'], %{>}).to_snippet, $debug_codecompletion.inspect
    
    # Don't insert anything if there's no line_before text and :nil_context===false
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => ">", "TM_COLUMN_NUMBER" => "1", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{${0:}>}, TextmateCodeCompletion.new(['test'], %{>}, :scope => :html_attributes).to_snippet, $debug_codecompletion.inspect
    
    # Don't insert anything if the line_before text doesn't match the :context and :nil_context===false
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "  <>", "TM_COLUMN_NUMBER" => "3", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{  ${0:}<>}, TextmateCodeCompletion.new(['test'], %{  <>}, :scope => :html_attributes).to_snippet, $debug_codecompletion.inspect
    
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "<>", "TM_COLUMN_NUMBER" => "3", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{<>${0:}}, TextmateCodeCompletion.new(['test'], %{<>}, :scope => :html_attributes).to_snippet, $debug_codecompletion.inspect
  end
  
  def test_caret_placement
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "\t\t</div>", "TM_COLUMN_NUMBER" => "1", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{test$0		</div>}, TextmateCodeCompletion.new(['test'], %{		</div>}).to_snippet, $debug_codecompletion.inspect
  end
  
  def test_html_with_no_attributes
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "<div>", "TM_COLUMN_NUMBER" => "5", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %{<div class="${1:}"$0>}, TextmateCodeCompletion.new(['<div class=""'], %{<div>}, :scope => :html_attributes).to_snippet, $debug_codecompletion.inspect
  end
  
  def test_go_basic
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "basic", "TM_COLUMN_NUMBER" => "6", "TM_INPUT_START_COLUMN" => "1"})
    ENV['TM_COMPLETIONS'] = 'basic,basic1'
    
    text = TextmateCodeCompletion.go!
    assert_equal "basic$0", text
  end
  
  def test_go_vars
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "basic", "TM_COLUMN_NUMBER" => "6", "TM_INPUT_START_COLUMN" => "1"})
    ENV['TM_COMPLETIONS'] = 'basicbasic1'
    ENV['TM_COMPLETION_split'] = ''
    
    text = TextmateCodeCompletion.go!
    assert_equal "basic$0", text
  end
  
  def test_shouldnt_have_to_escape_dollars
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "", "TM_COLUMN_NUMBER" => "1", "TM_INPUT_START_COLUMN" => "1"})
    assert_equal %q{\$\$(${1:'${2:selectors:mixed}'})\$\$$0}, TextmateCodeCompletion.new(["$$('selectors:mixed')$$"]).to_snippet
    assert_equal %q{\$apple\$$0}, TextmateCodeCompletion.new(["$apple$"]).to_snippet
  end
  
  def test_plist_split
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "basic", "TM_COLUMN_NUMBER" => "6", "TM_INPUT_START_COLUMN" => "1"})
    ENV['TM_COMPLETIONS'] = %{{ suggestions =(
          { title = "basic"; },
          { title = "basic1"; },
          { title = "basic2"; }
        );}}
    ENV['TM_COMPLETION_split'] = 'plist'
    
    text = TextmateCodeCompletion.go!
    assert_equal "basic$0", text
  end
  
  def test_plist_snippet
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "basic", "TM_COLUMN_NUMBER" => "6", "TM_INPUT_START_COLUMN" => "1"})
    ENV['TM_COMPLETIONS'] = %{{ suggestions =( { title = "basic 'All this text should be removed'"; snippet = "basic"; } );}}
    ENV['TM_COMPLETION_split'] = 'plist'
    
    text = TextmateCodeCompletion.go!
    # assert_equal "basic$0", text
    # Haven't implemented the code to make this pass yet :-!
  end
end
# =begin
# =end
class TextmateCompletionsPlistTest < Test::Unit::TestCase

  def test_plist_file
    `echo "{settings={ completions = ( 'fibbity', 'flabbity', 'floo' ); };}" >/tmp/test_plist_file.plist`
    completions = TextmateCompletionsPlist.new("/tmp/test_plist_file.plist")
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert completions.to_ary.length > 0
  end
  
  def test_plist_string_format1
    completions = TextmateCompletionsPlist.new("{ completions = ( 'fibbity', 'flabbity', 'floo' ); }")
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert completions.to_ary.length == 3, completions.choices
  end
  
  def test_plist_string_format1_dialog2
    completions = TextmateCompletionsPlist.new %q`
    {
        completions =     (
                    {
                display    = moo;
                image      = Drag;
                insert     = "(${1:one}, ${2:one}, ${3:three}${4:, ${5:five}, ${6:six}})";
                "tool_tip" = "(one, two, four[, five])\n This method does something or other maybe.\n Insert longer description of it here.";
            },
                    {
                display    = foo;
                image      = Macro;
                insert     = "(${1:one}, \"${2:one}\", ${3:three}${4:, ${5:five}, ${6:six}})";
                "tool_tip" = "(one, two)\n This method does something or other maybe.\n Insert longer description of it here.";
            },
                    {
                display    = bar;
                image      = Command;
                insert     = "(${1:one}, ${2:one}, \"${3:three}\"${4:, \"${5:five}\", ${6:six}})";
                "tool_tip" = "(one, two[, three])\n This method does something or other maybe.\n Insert longer description of it here.";
            }
        );
        images         = {
            Command    = "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Commands.png";
            Drag       = "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Drag Commands.png";
            Language   = "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Languages.png";
            Macro      = "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Macros.png";
            Preference = "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Preferences.png";
            Snippet    = "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Snippets.png";
            Template   = "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Template Files.png";
            Templates  = "/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Templates.png";
        };
    }
    `
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert_kind_of Hash, completions.to_hash
    assert_equal [
        {'image' => 'Drag',    'display' => 'moo', 'insert' => '(${1:one}, ${2:one}, ${3:three}${4:, ${5:five}, ${6:six}})',     'tool_tip' => "(one, two, four[, five])\n This method does something or other maybe.\n Insert longer description of it here."},
        {'image' => 'Macro',   'display' => 'foo', 'insert' => '(${1:one}, "${2:one}", ${3:three}${4:, ${5:five}, ${6:six}})',   'tool_tip' => "(one, two)\n This method does something or other maybe.\n Insert longer description of it here."},
        {'image' => 'Command', 'display' => 'bar', 'insert' => '(${1:one}, ${2:one}, "${3:three}"${4:, "${5:five}", ${6:six}})', 'tool_tip' => "(one, two[, three])\n This method does something or other maybe.\n Insert longer description of it here."},
    ], completions.to_hash['completions']
    assert completions.to_ary.length == 3, completions.choices
  end
  def test_plist_string_format1_dialog2_xml
    
    completions = TextmateCompletionsPlist.new %q{
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>completions</key>
  <array>
    <dict>
      <key>display</key>
      <string>moo</string>
      <key>image</key>
      <string>Drag</string>
      <key>insert</key>
      <string>(${1:one}, ${2:one}, ${3:three}${4:, ${5:five}, ${6:six}})</string>
      <key>tool_tip</key>
      <string>(one, two, four[, five])
 This method does something or other maybe.
 Insert longer description of it here.</string>
    </dict>
    <dict>
      <key>display</key>
      <string>foo</string>
      <key>image</key>
      <string>Macro</string>
      <key>insert</key>
      <string>(${1:one}, "${2:one}", ${3:three}${4:, ${5:five}, ${6:six}})</string>
      <key>tool_tip</key>
      <string>(one, two)
 This method does something or other maybe.
 Insert longer description of it here.</string>
    </dict>
    <dict>
      <key>display</key>
      <string>bar</string>
      <key>image</key>
      <string>Command</string>
      <key>insert</key>
      <string>(${1:one}, ${2:one}, "${3:three}"${4:, "${5:five}", ${6:six}})</string>
      <key>tool_tip</key>
      <string>(one, two[, three])
 This method does something or other maybe.
 Insert longer description of it here.</string>
    </dict>
  </array>
  <key>images</key>
  <dict>
    <key>Command</key>
    <string>/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Commands.png</string>
    <key>Drag</key>
    <string>/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Drag Commands.png</string>
    <key>Language</key>
    <string>/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Languages.png</string>
    <key>Macro</key>
    <string>/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Macros.png</string>
    <key>Preference</key>
    <string>/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Preferences.png</string>
    <key>Snippet</key>
    <string>/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Snippets.png</string>
    <key>Template</key>
    <string>/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Template Files.png</string>
    <key>Templates</key>
    <string>/Applications/TextMate.app/Contents/Resources/Bundle Item Icons/Templates.png</string>
  </dict>
</dict>
</plist>
    }
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert completions.to_ary.length == 3, completions.choices
  end
  
  def test_plist_string_format1_dialog2_only_completions
    plist = <<-PLIST
{	completions = (
		{	display = 'moo';
			image = 'Drag';
			insert = '(${1:one}, ${2:one}, ${3:three}${4:, ${5:five}, ${6:six}})';
			tool_tip = '(one, two, four[, five])\n This method does something or other maybe.\n Insert longer description of it here.';
		},
		{	display = 'foo';
			image = 'Macro';
			insert = '(${1:one}, "${2:one}", ${3:three}${4:, ${5:five}, ${6:six}})';
			tool_tip = '(one, two)\n This method does something or other maybe.\n Insert longer description of it here.';
		},
		{	display = 'bar';
			image = 'Command';
			insert = '(${1:one}, ${2:one}, "${3:three}"${4:, "${5:five}", ${6:six}})';
			tool_tip = '(one, two[, three])\n This method does something or other maybe.\n Insert longer description of it here.';
		},
	);
}
    PLIST
    completions = TextmateCompletionsPlist.new plist
    
    assert_equal OSX::PropertyList.load(plist), completions.parsed
    
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert completions.to_ary.length == 3, completions.choices
  end
  def test_plist_string_format1_dialog2_only_completions_xml
    plist = <<-'XML'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    	<key>completions</key>
    	<array>
    		<dict>
    			<key>display</key>
    			<string>moo</string>
    			<key>image</key>
    			<string>Drag</string>
    			<key>insert</key>
    			<string>(${1:one}, ${2:one}, ${3:three}${4:, ${5:five}, ${6:six}})</string>
    			<key>tool_tip</key>
    			<string>(one, two, four[, five])
     This method does something or other maybe.
     Insert longer description of it here.</string>
    		</dict>
    		<dict>
    			<key>display</key>
    			<string>foo</string>
    			<key>image</key>
    			<string>Macro</string>
    			<key>insert</key>
    			<string>(${1:one}, &quot;${2:one}&quot;, ${3:three}${4:, ${5:five}, ${6:six}})</string>
    			<key>tool_tip</key>
    			<string>(one, two)
     This method does something or other maybe.
     Insert longer description of it here.</string>
    		</dict>
    		<dict>
    			<key>display</key>
    			<string>bar</string>
    			<key>image</key>
    			<string>Command</string>
    			<key>insert</key>
    			<string>(${1:one}, ${2:one}, &quot;${3:three}&quot;${4:, &quot;${5:five}&quot;, ${6:six}})</string>
    			<key>tool_tip</key>
    			<string>(one, two[, three])
     This method does something or other maybe.
     Insert longer description of it here.</string>
    		</dict>
    	</array>
    </dict>
    </plist>
    XML
    completions = TextmateCompletionsPlist.new plist
    
    assert_equal OSX::PropertyList.load(plist), completions.parsed
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert completions.to_ary.length == 3, completions.choices
  end
  
  def test_plist_string_format2
    completions = TextmateCompletionsPlist.new %{{ suggestions =( { title = "basic"; }, { title = "basic1"; }, { title = "basic2"; } );}}
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert completions.to_ary.length == 3, completions.choices
  end
  
  def test_plist_both_formats
    completions = TextmateCompletionsPlist.new %{{
      completions = ( 'fibbity', 'flabbity', 'floo' );
      suggestions = ( { title = "basic"; }, { title = "basic1"; }, { title = "basic2"; } );
    }}
    assert ['basic', 'basic1', 'basic2'] == completions.to_ary
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert completions.to_ary.length == 3, completions.choices
  end
end

class TextmateCompletionsTextTest < Test::Unit::TestCase
  def test_txt
    completions = TextmateCompletionsText.new("README.txt")
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert completions.to_ary.length > 0
  end
  def test_txt_completions
    completion = TextmateCodeCompletion.new(TextmateCompletionsText.new("README.txt"),'').to_snippet
    assert_not_nil completion
  end
  def test_txt_completions_dict
    completions = TextmateCompletionsText.new(`cat /usr/share/dict/web2|grep ^fr`).to_ary
    completion = TextmateCodeCompletion.new(completions,'fra').to_snippet
    assert_not_nil completion
  end
  def test_strings
    them = %{one\ntwo\nthree}
    
    completions = TextmateCompletionsText.new(them)
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert completions.to_ary.length == 3
    
    them = %{one,two,three}
    
    completions = TextmateCompletionsText.new(them, :split => ',')
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert completions.to_ary.length == 3
    
    them = %{one,two,three}
    
    completions = TextmateCompletionsText.new(them, :split => ',', :filter => /three/)
    assert_not_nil completions
    assert_kind_of Array, completions.to_ary
    assert completions.to_ary.length == 2
  end
end

class TextmateCompletionsParserTest < Test::Unit::TestCase
  def test_parser_dir
    fred = TextmateCompletionsParser.new(File.dirname(__FILE__), :select => /^[ \t]*(?:class|def)\s*(.*?)\s*(<.*?)?\s*(#.*)?$/).to_ary
    assert_nil fred
  end
  def test_parser_symbol
    fred = TextmateCompletionsParser.new(nil, :scope => :ruby).to_ary
    assert_kind_of Array, fred.to_ary
    assert fred.to_ary.length > 0, fred.inspect
    
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "a", "TM_COLUMN_NUMBER" => "2", "TM_INPUT_START_COLUMN" => "1"})
    assert_not_nil TextmateCodeCompletion.new(fred).to_snippet
  end
  def test_parser_array
    fred = TextmateCompletionsParser.new(nil, 
      :split => "\n",
      :select => [%r/^[ \t]*(?:class)\s*(.*?)\s*(<.*?)?\s*(#.*)?$/,
                  %r/^[ \t]*(?:def)\s*(.*?(\([^\)]*\))?)\s*(<.*?)?\s*(#.*)?$/,
                  %r/^[ \t]*(?:attr_.*?)\s*(.*?(\([^\)]*\))?)\s*(<.*?)?\s*(#.*)?$/], 
      :filter => /_string/).to_ary
    assert_kind_of Array, fred.to_ary, $debug_codecompletion.inspect
    assert fred.to_ary.length > 0, $debug_codecompletion.inspect
    
    set_tm_vars({"TM_SELECTED_TEXT" => nil, "TM_CURRENT_LINE" => "a", "TM_COLUMN_NUMBER" => "2", "TM_INPUT_START_COLUMN" => "1"})
    assert_not_nil TextmateCodeCompletion.new(fred).to_snippet
  end
  
  def test_parser_array_with_empty_rows
    fred = TextmateCompletionsParser.new('codecompletion.rb', :scope => :ruby).to_ary
    assert fred.to_ary.grep(/^$/).length == 0, fred.to_ary.grep(/^$/).inspect
  end
end

def set_tm_vars(env)
  ENV['TM_BUNDLE_PATH']        = env['TM_BUNDLE_PATH'] if env['TM_BUNDLE_PATH']
  # ENV['TM_SUPPORT_PATH']       = env['TM_SUPPORT_PATH']
  ENV['TM_COLUMN_NUMBER']      = env['TM_COLUMN_NUMBER']
  ENV['TM_CURRENT_LINE']       = env['TM_CURRENT_LINE']
  ENV['TM_INPUT_START_COLUMN'] = env['TM_INPUT_START_COLUMN']
  ENV['TM_SELECTED_TEXT']      = env['TM_SELECTED_TEXT']
end
  
end # TESTS

=begin
=end
