#!/usr/bin/env ruby
# encoding: utf-8

require 'optparse'
require 'ostruct'
require 'erb'
require 'iconv'
require File.dirname(__FILE__) + '/db_browser_lib'
require ENV['TM_BUNDLE_SUPPORT'] + '/lib/json'
require 'cgi'
require "#{ENV["TM_SUPPORT_PATH"]}/lib/web_preview" if ENV["TM_SUPPORT_PATH"]

NO_TABLE = '__none__'

@options = OpenStruct.new
@options.offset    = 0
@options.page_size = 10
@options.mode      = 'home'

@options.database = OpenStruct.new
@options.database.server   = 'mysql'
@options.database.host     = nil
@options.database.user     = nil
@options.database.password = nil
@options.database.port     = nil
@options.database.name     = nil
@options.database.table    = nil

require "#{ENV["TM_SUPPORT_PATH"]}/lib/osx/plist" if ENV["TM_SUPPORT_PATH"]

# Parse commandline options
begin
  OptionParser.new do |opts|
    opts.banner = "Usage: db_browser.rb [options]"

    opts.on("--database database", "Set database name") { |database| @options.database.name = database }
    opts.on("--table table", "Set database table") { |table| @options.database.table = table }
    opts.on("--query query", "Run query on database") { |query| @options.query = query.to_s.strip }
    opts.on("--rows rows", OptionParser::DecimalInteger, "Set page size for query output") { |rows| @options.page_size = rows }
    opts.on("--offset offset", OptionParser::DecimalInteger, "Set offset") { |offset| @options.offset = offset }

    opts.on('--mode=mode', ['home', 'frame', 'tables', 'search']) { |mode| @options.mode = mode }
    
    opts.on('--version', 'Print mysql server version and exit') { @options.mode = 'version' }
    opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }
  end.parse!
rescue OptionParser::InvalidOption, OptionParser::InvalidArgument, OptionParser::AmbiguousArgument => e
  puts e.reason + ": " + e.args.pop
  exit
end

begin
  get_connection_settings(@options.database)
  @connection = get_connection
rescue MissingConfigurationException
  # Show initial setup message
  html('Configuration') do
    print File.read(ENV['TM_BUNDLE_SUPPORT'] + '/install.html')
  end
rescue ConnectorException => error
  html('Connection Error') do
    puts <<-HTML
      <h1>Connection Error</h1>
      <blockquote>
        #{error.message}
      </blockquote>
      <p>Please correct your connection settings in the <a href="javascript:launchConfig()">configuration dialog</a>.</p>
    HTML
  end
end

if @options.mode == 'version'
  puts @connection.server_version
  exit
end

def print_data(query = nil)
  @page_size = @options.page_size
  offset     = @options.offset
  if not query or query.to_s.size == 0
    query     = "SELECT * FROM %s" % @options.database.table
    @page_size = 5
    offset    = 0
  end
  run_query = query.sub(/;\s*$/, '')
  @limited  = true
  if not query=~ /\bLIMIT\b/i and run_query =~ /\s*SELECT/i
    run_query << ' LIMIT %d OFFSET %d' % [@page_size, offset]
    @limited = false
  end

  @query = query
  begin
    @result = @connection.do_query(run_query)
    if @result.is_a? Result
      @title = 'Query complete'
      if @result.num_rows == 0
        @message = 'There are no records to show'
      else
        @pager = 'Records %d to %d' % [offset + 1, offset + @result.num_rows]
      end
    else
      @message = @result.to_s + " row#{:s if @result.to_i != 1} affected"
    end
  rescue Exception => e
    @title = "Invalid query"

    if defined?(Mysql::Error) and e.is_a? Mysql::Error
      @message = escape(smarty(e.message))
    elsif e.is_a? RuntimeError # used by Postgresql connector
      # This is my best guess at decyphering the error messages returned by Postgresql
      # I've added the rescue as a fallback
      @message = e.message.split("\t")[2][1..-1] rescue e.message
    else
      # This is a code error (this will never be reached, of course ;)
      @message = "<b>#{e.class.name}: #{escape(smarty(e.message))}</b>"
      @message += '<pre>' + "\t" + escape(e.backtrace.join("\n\t")) + '</pre>'
    end
  end
  render('result')
end

# ====================
# = Template helpers =
# ====================
def smarty(text)
  text.to_s.sub(" -- ", ' — ')
end

def escape(text)
  CGI.escapeHTML(text.to_s)
end

def e_js(str)
  str.to_s.gsub(/(?=['\\])/, '\\')
end

def format(content, type)
  return '' unless content
  begin
    Iconv.iconv('utf-8', 'utf-8', content)
  rescue Exception => e
    content = content.unpack('C*').map { |ch| ch < 128 ? ch : ?? }.pack('C*')
  end
  if type == :number
    content
  else
    full_content = escape(content)
    content = escape(content).gsub("\n", "<br>")
    if content.length > 30
      content = content[/\A.{29}\w*/m] + '<span style="color: red;font-weight: bold">' + '…</span>'
    end
    tag = '<span'
    tag << ' title="' + full_content + '"' if content != full_content
    tag << '>' + content + '</span>'
  end
end

def get_data_link(link, new_params = {})
  params = []
  params << "'" + e_js(escape((new_params[:database] || @options.database.name).to_s)) + "'"
  params << "'" + e_js(escape((new_params[:table] || @options.database.table).to_s)) + "'"
  params << (new_params[:query] ? escape(new_params[:query].inspect) : "''")
  params << @options.page_size.to_i
  params << new_params[:offset].to_i
  '<a href="javascript:getData(' + params.join(', ') + ')">' + link + "</a>"
end

# ===============
# = Entry point =
# ===============

if @options.mode == 'tables'
  @tables = @connection.table_list(@options.database.name)
  print render('tables')
elsif @options.mode == 'home'
  html do
    STDOUT.flush
    @content = ''
    if @options.query.to_s.size > 0
      @content = print_data(@options.query)
    elsif ENV['TM_BUNDLE_SUPPORT']
      @content = '<h2>Database Browser</h2>Please choose a table from the left'
    end
    begin
      @databases = @connection.database_list
    rescue ConnectorException => e
      abort e.message
    end
    print render('main')
  end
elsif @options.mode == 'search'
  query = 'SELECT * FROM ' + @options.database.table
  conditions = JSON.parse(STDIN.read)
  unless conditions.empty?
    query << ' WHERE '
    conditions.each_pair do |field, value|
      query << @connection.quote_field(field) + " = " + @connection.quote_value(value)
    end
  end
  print print_data(query)
elsif @options.query.to_s.size > 0
  print print_data(@options.query)
elsif @options.database.table
  if @options.database.table != NO_TABLE
    @table  = @options.database.table
    @fields = @connection.get_fields
    print render('columns')
    print print_data
  end
end
