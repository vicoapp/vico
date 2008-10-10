#!/usr/bin/env ruby

require 'ostruct'
require File.dirname(__FILE__) + '/db_browser_lib'
require ENV['TM_SUPPORT_PATH'] + '/lib/exit_codes'
require ENV['TM_SUPPORT_PATH'] + '/lib/ui'

@options = OpenStruct.new(:server => 'mysql', :database => OpenStruct.new)

begin
  get_connection_settings(@options.database)
  @connection = get_connection
rescue
  TextMate::exit_show_tool_tip "No connection"
end

def completion_for(list, word)
  list = list.select { |e| e =~ /^#{Regexp.quote word}/ }
  return nil if list.empty?
  if list.size == 1
    completed_word = list.first
  else
    TextMate::exit_show_tool_tip "Cancelled" unless choice = TextMate::UI.menu(list)
    completed_word = list[choice]
  end
  return completed_word[word.size..-1]
end

def complete_field(table, field)
  completion_for(@connection.get_fields(table).map { |f| f[:name] }, field.to_s) rescue nil
end

def complete_table(table)
  completion_for(@connection.table_list(@options.database.name), table.to_s) rescue nil
end

line = ENV['TM_CURRENT_LINE']
line = line[0..ENV['TM_LINE_INDEX'].to_i-1]
line =~ /(\w+)(?:(\.)(\w+)?)?$/
table, table_complete, field = $1, $2, $3

unless table_complete
  completed_table = complete_table(table.to_s)
  TextMate::exit_show_tool_tip "No matches found" unless completed_table
  print completed_table + "."
  exit
else
  completed_field = complete_field(table, field)
  TextMate::exit_show_tool_tip "No matches found" unless completed_field
  print completed_field
end
