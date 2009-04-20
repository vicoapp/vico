#!/usr/bin/env ruby -w
# encoding: utf-8

require "#{ENV['TM_SUPPORT_PATH']}/lib/ui"
require "#{ENV['TM_SUPPORT_PATH']}/lib/progress"
require "#{ENV['TM_SUPPORT_PATH']}/lib/escape"
require "#{ENV['TM_SUPPORT_PATH']}/lib/shelltokenize" # for TextMate::selected_paths_array
require "#{ENV['TM_SUPPORT_PATH']}/lib/exit_codes"

module Subversion

	# Writes diff text to stdout for compatibility.
  def Subversion.diff_active_file( revision, command_description )
	
		error_handler = Proc.new do |error|
			TextMate::exit_show_tool_tip(error)
		end
	
		puts diff_working_copy_with_revision(:paths => TextMate::selected_paths_array,
																					:revision => revision,
																					:command_name => command_description,
																					:on_error => error_handler)  
  end

	# returns diff text
  def Subversion.diff_working_copy_with_revision( args )

		filepaths				= args[:paths]
		revision				= args[:revision]
		command					= args[:command_name]
		error_handler		=	args[:on_error]			|| lambda {|error| TextMate::UI.alert(:warning, "Could not complete diff operation", error)}
	
    svn         = ENV['TM_SVN'] || 'svn'
    diff_cmd    = ENV['TM_SVN_DIFF_CMD']
    diff_arg    = diff_cmd ? "--diff-cmd #{diff_cmd}" : ''

    error       = ''
    result      = ''

    TextMate::call_with_progress(:title => command, :message => "Accessing Subversion Repository…") do
      filepaths.each do |target_path|
        svn_header  = /\AIndex: #{Regexp.escape(target_path)}\n=+\n\z/
        res = %x{#{e_sh svn} 2>&1 diff "-r#{revision}" #{diff_arg} #{e_sh target_path}}

        if $? != 0
          # The command failed; show its output as a tooltip
          error << res
        elsif (custom_diff? or diff_cmd) and res =~ svn_header
          # Suppress output, as we only got a svn header (so likely diff-cmd opened its own window)
        else
          result << res
        end
      end

      error_handler.call(error)                     unless error.empty?
      error_handler.call("No differences found.")   if result.empty?
      result
    end
		result # should be redundant
  end

  # Returns true if ~/.subversion/config contains an uncommented entry for diff-cmd
  def Subversion.custom_diff?
    config_file = ENV['HOME'] + "/.subversion/config"
      
    if File.exists?(config_file)
      IO.foreach(config_file) do |line|
        return true if line =~ /^\s?diff-cmd\s?=\s?(.*)/
      end
    end
    
    return false
  end  
end
