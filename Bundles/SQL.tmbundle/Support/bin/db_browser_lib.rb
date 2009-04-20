# Add the path to the bundled libs to be used if the native bindings aren't installed
$: << ENV['TM_BUNDLE_SUPPORT'] + '/lib/' << ENV['TM_BUNDLE_SUPPORT'] + '/lib/connectors' if ENV['TM_BUNDLE_SUPPORT']

require 'ostruct'
require ENV['TM_SUPPORT_PATH'] + '/lib/osx/keychain'
require ENV['TM_SUPPORT_PATH'] + '/lib/ui'
require ENV['TM_SUPPORT_PATH'] + '/lib/exit_codes'

class ConnectorException < Exception; end
class MissingConfigurationException < ConnectorException; end

class Connector
  @@connector = nil

  def initialize(settings)
    @server = settings.server
    @settings = settings
    begin
      if @server == 'mysql'
        require 'mysql'
        get_mysql
      elsif @server == 'postgresql'
        begin
          require "rubygems"
          require "postgres"
        rescue LoadError
          require 'postgres-compat'
        end
        get_pgsql
      end
    rescue LoadError
      raise "Database connection library not found [#{$!}]"
    end
  end

  def do_query(query, database = nil)
    if @server == 'postgresql'
      mycon = self.get_pgsql(database)
      res = mycon.respond_to?(:exec) ? mycon.exec(query) : mycon.query(query)
    elsif @server == 'mysql'
      mycon = self.get_mysql(database)
      res = mycon.query(query)
    end
    if res
      Result.new(res)
    else
      mycon.affected_rows
    end
  end
  
  def server_version
    if @server == 'mysql'
      res = self.get_mysql.query('SHOW VARIABLES LIKE "version"')
      res.fetch_row[1]
    else
      puts "Not implemented for PGSQL yet!"
      exit
    end
  end

  def get_mysql(database = nil)
    unless @@connector
      @@connector = Mysql::new(@settings.host, @settings.user, @settings.password, database || @settings.name, @settings.port)
      begin
        encoding = @@connector.query('SELECT @@character_set_database AS server').fetch_hash
      rescue
        encoding = {:server => 'utf8'}
      end
      @@connector.query('SET NAMES utf8;') if encoding["server"] != 'latin1'
    end
    @@connector
  end

  def get_pgsql(database = nil)
    unless @connector
      if defined?(PostgresPR)
        @@connector = PostgresPR::Connection.new(database || @settings.name, @settings.user, @settings.password, 'tcp://' + @settings.host + ":" + @settings.port.to_s)
      else
        @@connector = PGconn.open(@settings.host, @settings.port, "", "", (database || @settings.name), @settings.user, @settings.password.to_s)
      end
    end
    @@connector
  end
  
  ####
  def table_list(database = nil)
    if @server == 'postgresql'
      query = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';"
    elsif @server == 'mysql'
      query = 'SHOW TABLES'
    end
    tables = []
    do_query(query, database).rows.each {|row| tables << row[0] }
    tables.sort
  end

  def database_list
    databases = []
    if @server == 'postgresql'
      do_query('SELECT datname FROM pg_catalog.pg_database').rows.each { |row| databases << row[0] }
    elsif @server == 'mysql'
      do_query('SHOW DATABASES').rows.each { |row| databases << row[0] }
    end
    databases.sort
  end

  def get_fields(table = nil)
    table ||= @settings.table
    field_list = []
    if @server == 'postgresql'
      query = "SELECT column_name, data_type, is_nullable, ordinal_position, column_default FROM information_schema.columns
                WHERE table_name='%s' ORDER BY ordinal_position" % table
    elsif @server == 'mysql'
      query = 'DESCRIBE ' + table
    end
    fields = do_query(query).rows
    fields.each { |field| field_list << {:name => field[0], :type => field[1], :nullable => field[2], :default => field[4]} }
    field_list
  end
  
  # Quoting
  def quote_field(field)
    if @server == 'mysql'
      return "`#{field}`"
    else
      return %Q{"#{field}"}
    end
  end

  def quote_value(value)
    if value.is_a? String
      if @server == 'mysql'
        return '"' + @@connector.escape_string(value) + '"'
      else
        return "'" + PGconn.escape(value) + "'"
      end
    else
      return value.to_s
    end
  end
end

class Result
  def initialize(res)
    @res = res
  end

  def rows
    if defined?(Mysql) and @res.is_a? Mysql::Result
      @res
    else
      @res.rows
    end
  end

  def fields
    if defined?(Mysql) and @res.is_a? Mysql::Result
      @res.fetch_fields.map do |field|
        {:name => field.name,
         :type => [Mysql::Field::TYPE_DECIMAL, Mysql::Field::TYPE_TINY, Mysql::Field::TYPE_SHORT,
                   Mysql::Field::TYPE_LONG, Mysql::Field::TYPE_FLOAT, Mysql::Field::TYPE_DOUBLE].include?(field.type) ? :number : :string }
      end
    else
      @res.fields.map{|field| {:name => field.respond_to?(:name) ? field.name : field, :type => :string } }
    end
  end
  
  def num_rows
    if @res.respond_to? :num_rows
      @res.num_rows
    else
      rows.size
    end
  end
end

def render(template_file)
  template = File.read(File.dirname(__FILE__) + '/../templates/' + template_file + '.rhtml')
  ERB.new(template).result(binding)
end

def html(subtitle = nil)
  puts html_head(:window_title => "SQL", :page_title => "Database Browser", :sub_title => subtitle || @options.database.name, :html_head => render('head'))
  yield
  html_footer
  exit
end

def get_connection_settings(options)
  begin
    plist = open(File.expand_path('~/Library/Preferences/com.macromates.textmate.plist')) { |io| OSX::PropertyList.load(io) }

    unless connection = plist['SQL Connections'].find { |conn| conn['title'] == ENV['TM_SQL_CONNECTION'] }
      connection = plist['SQL Connections'][plist['SQL Active Connection'].first.to_i]
    end

    options.host = connection['hostName']
    options.user = connection['userName']
    if connection['serverType'] && ['mysql', 'postgresql'].include?(connection['serverType'].downcase!)
      options.server = connection['serverType']
    else
      options.server = 'mysql'
    end
    options.name   ||= connection['database']
    if connection['port']
      options.port = connection['port'].to_i
    else
      options.port = (options.server == 'postgresql') ? 5432 : 3306
    end
  rescue
    raise MissingConfigurationException.new
  end
end

def get_connection_password(options)
  proto = options.server == 'postgresql' ? 'pgsq' : 'mysq'

  OSX::Keychain::internet_password_for :account => options.user, :server => options.host, :protocol => proto
end

def store_connection_password(options, password)
  proto = @options.database.server == 'postgresql' ? 'pgsq' : 'mysq'

  OSX::Keychain::set_internet_password_for :account => options.user, :server => options.host, :protocol => proto, :password => password
end

def get_connection
  raise MissingConfigurationException.new unless @options.database.host and not @options.database.host.empty?
  
  # Get the stored password if available, or nil otherwise
  @options.database.password = get_connection_password(@options.database)

  begin
    # Try to connect with either our stored password, or with no password
    @connection = Connector.new(@options.database)
  rescue Exception => error
    if ['Access denied', 'no password specified', 'authentication failed', 'no password supplied'].find { |msg| error.message.include?(msg) }
      # If we got an access denied error then we can request a password from the user
      begin
        # Longer prompts get cut off
        break unless password = TextMate::UI.request_secure_string(:title => "Enter Password", :prompt => "Enter password for #{@options.database.user}@#{@options.database.name}")
        @options.database.password = password
        # Try to connect with the new password
        @connection = Connector.new(@options.database) rescue nil
      end until @connection
      store_connection_password(@options.database, password) if @connection
    else
      # Rethrow other errors (e.g. host not found)
      message = error.message
      message = message.split("\t")[2][1..-1] rescue message if error.is_a? RuntimeError
      raise ConnectorException.new(message)
    end
  end
  unless @connection
    abort <<-HTML
      <script type="text/javascript" charset="utf-8">window.close()</script>
    HTML
  end
  @connection
end
