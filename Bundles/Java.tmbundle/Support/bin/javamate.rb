#!/usr/bin/env ruby

require ENV["TM_SUPPORT_PATH"] + "/lib/tm/executor"
require ENV["TM_SUPPORT_PATH"] + "/lib/tm/save_current_document"
require ENV["TM_SUPPORT_PATH"] + "/lib/ui"
require "shellwords"

require "pstore"

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

cmd = ["java_compile_and_run.sh"]
cmd << ENV['TM_FILEPATH']
script_args = []
if ENV.include? 'TM_JAVAMATE_GET_ARGS'
  prev_args = JavaMatePrefs.get("prev_args")
  args = TextMate::UI.request_string(:title => "JavaMate", :prompt => "Enter any command line options:", :default => prev_args)
  JavaMatePrefs.set("prev_args", args)
  script_args = Shellwords.shellwords(args)
end

TextMate::Executor.run(cmd, :version_args => ["--version"], :script_args => script_args)