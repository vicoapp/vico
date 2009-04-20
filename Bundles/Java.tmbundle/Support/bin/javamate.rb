#!/usr/bin/env ruby

require ENV["TM_SUPPORT_PATH"] + "/lib/tm/executor"
require ENV["TM_SUPPORT_PATH"] + "/lib/tm/save_current_document"
require ENV["TM_SUPPORT_PATH"] + "/lib/ui"
require "shellwords"
require "pstore"
require 'pathname'

class JavaMatePrefs
  @@prefs = PStore.new(File.expand_path( "~/Library/Preferences/com.macromates.textmate.javamate"))
  def self.get(key)
    @@prefs.transaction { @@prefs[key] }
  end
  def self.set(key,value)
    @@prefs.transaction { @@prefs[key] = value }
  end
end

TextMate.save_current_document
TextMate::Executor.make_project_master_current_document

cmd = ["java_compile_and_run.sh"]
cmd << ENV['TM_FILEPATH']
script_args = []
if ENV.include? 'TM_JAVAMATE_GET_ARGS'
  prev_args = JavaMatePrefs.get("prev_args")
  args = TextMate::UI.request_string(:title => "JavaMate", :prompt => "Enter any command line options:", :default => prev_args)
  JavaMatePrefs.set("prev_args", args)
  script_args = Shellwords.shellwords(args)
end
cwd = Pathname.new(Pathname.new(Dir.pwd).realpath)

package = nil
File.open(ENV['TM_FILEPATH'], "r") do |f|
  while (line = f.gets)
    if line =~ /\s*package\s+([^\s;]+)/
      package = $1
      break
    end
  end
end

cmd << package if package

TextMate::Executor.run(cmd, :version_args => ["--version"], :script_args => script_args) do |line, type|
  case type
  when :err
    line.chomp!
    if line =~ /(.+\.java):(\d+):(.*)$/ 
      path = Pathname.new($1)
      line_no = $2
      error = $3
      abs_path = Pathname.new(path.realpath)
      line = "<a href='txmt://open?url=file://#{abs_path}&line=#{line_no}'>#{htmlize((path.to_s =~ /^\.\//) ? path : abs_path.relative_path_from(cwd))}:#{line_no}</a>:#{htmlize(error)}";
    else
      line = htmlize(line)
    end
    line = "<span style='color: red'>#{line}</span></br>"
  end
end