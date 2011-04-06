#!/usr/bin/env ruby
# encoding: utf-8

require "#{ENV['TM_SUPPORT_PATH']}/lib/osx/plist"
require "#{ENV['TM_SUPPORT_PATH']}/lib/escape"
require "#{ENV['TM_SUPPORT_PATH']}/lib/exit_codes"

VICO = ENV['TM_APP_PATH'] + '/Contents/MacOS/vicotool'

module TextMate

  class AppPathNotFoundException < StandardError; end

  class << self
    def app_path
      ENV['TM_APP_PATH']
    end

    def app_name
      return %x{ps -cxwwp "$TM_PID" -o "command="}.chomp
    end

    def go_to(options = {})
      default_line = options.has_key?(:file) ? 1 : ENV['TM_LINE_NUMBER']
      options = {:file => ENV['TM_FILEPATH'], :line => default_line, :column => 1}.merge(options)
      if options[:file]
        `#{VICO} #{e_sh(options[:file])}`
      end
      `#{VICO} -e "(text gotoLine:#{options[:line]} column:#{options[:column]})((NSApplication sharedApplication) activateIgnoringOtherApps:YES)"`
    end

    def require_cmd(command, message = nil)
      if `which "#{command}"`.empty?
        require ENV['TM_SUPPORT_PATH'] + '/lib/tm/htmloutput'

        TextMate::HTMLOutput.show(
          :title      => "Command Not Found",
          :sub_title  => "Command Not Found - #{command}"
        ) do |io|
          io << <<-HTML
            <h3 class="error">Unable to locate <tt>#{command}</tt></h3>

            <p>#{message || "To succesfully run this action you need to
            install <tt>«#{command}»</tt>. If you know that it is already
            installed on your system, you instead need to update
            your search path.</p>

            <p>The manual has a section about
            <a href=\"help:anchor='search_path'%20bookID='TextMate%20Help'\">
            how to update your search path</a>."}</p>

            <p>For diagnostic purposes, the paths searched for <tt>«#{command}»</tt> were:</p>

            <ul>
              #{`echo $PATH`.gsub(/:/, "\n").gsub(/^(.*)$/, "<li>\\&</li>")}
            </ul>
          HTML
        end

        TextMate.exit_show_html
      end
    end

    def require_env_var(env_var, message = nil)
      unless ENV.has_key? env_var
        require ENV['TM_SUPPORT_PATH'] + '/lib/tm/htmloutput'
        TextMate::HTMLOutput.show(
          :title      => "Environment Variable Not Set",
          :sub_title  => "Environment Variable Not Set - #{env_var}"
        ) do |io|
          io << <<-HTML
            <h3 class="error">The environment variable <tt>#{env_var}</tt> is unset.</h3>

            <p>#{message || "To succesfully run this action you need to
            set the <tt>«#{env_var}»</tt> environment variable. If you know that it is already
            installed on your system, you instead need to update
            your search path."}</p>

            <p>The manual has a section about
            <a href=\"help:anchor='static_variables'%20bookID='TextMate%20Help'\">
            setting environment variables</a>.</p>
          HTML
        end
        TextMate.exit_show_html
      end
    end

    def min_support(version)
      # TBD
    end

    def rescan_project
      # TBD
    end
  end

  # project file hacks removed

end

