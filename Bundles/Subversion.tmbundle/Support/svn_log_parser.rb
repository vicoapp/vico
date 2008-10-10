# 
#  svn_log_parser.rb
#  Subversion.tmbundle
#  
#  Low-level:
# 	LogParser.parse_path(path) {|hash_for one_log_entry| ... }
# 	LogParser.parse(string_or_IO) {|hash_for one_log_entry| ... }
#
#  High-level:
#  	Subversion.view_revision(path)
#
#  Created by Chris Thomas on 2006-12-30.
#  Copyright 2006 Chris Thomas. All rights reserved.
# 

require 'rexml/document'
require 'time'
require 'uri'
require 'yaml'

require "#{ENV["TM_SUPPORT_PATH"]}/lib/osx/plist"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/ui"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/progress"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/escape"

ListNib = File.dirname(__FILE__) + "/nibs/RevisionSelector.nib"

module Subversion
	
	
	# Streaming 'svn log --xml' output parser.
	class LogParser
		
		# path may be a Subversion working copy path or a repository URL
		def LogParser.parse_path(path, &block)
			path = File.expand_path(path)
			log_cmd = %Q{"#{ENV['TM_SVN']||svn}" log --xml "#{path}"}

			IO.popen(log_cmd, "r") do |io|
				LogParser.parse(io) do |hash|
					block.call(hash)
				end
			end # IO.popen
		end
		
		# source may be a string or an IO subclass
		def LogParser.parse(source, &block)
			listener = LogParser.new(&block)
			
			# TODO: remove and report any text prior to the XML data
			REXML::Document.parse_stream(source, listener)
		end

		# This listener makes no attempt to validate according to schema.
		# The SVN log node names are unique and nonrecursive,
		# so this shouldn't be an issue. But it would be nice as a sanity check.
		def initialize(&block)
			@callback_block = block
		end
	
		def xmldecl(*ignored)
		end
	
		def tag_start(name, attributes)
			case name
			when 'logentry'
				revision = attributes['revision']
				@current_log = {'rev' => revision.to_i}
			end
		end

		def tag_end(name)
			case name
			when 'author','msg'
				@current_log[name] = @text
			when 'date'
				@current_log[name] = Time.xmlschema(@text)
			when 'logentry'
				@callback_block.call(@current_log)
			end
		end
	
		def text(text)
			@text = text
		end

	end # class LogParser
end # module Subversion

if __FILE__ == $0
	
#	test_path = "~/TestRepo/TestFiles"
# REXML thinks this is perfectly acceptable XML input.
#I'm pretty sure it's not, but I haven't read the spec in the last four years.
	Subversion::LogParser.parse(%Q{Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
		quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat
		. Duis aute irure dolor in reprehenderit in voluptate velit esse
		 cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
		}) do |hash|
		puts hash.inspect
	end

# It catches this and other angle-bracket problems, though.
	Subversion::LogParser.parse(%Q{<Lo> <lo> <lo> <.&&>>>><<<<<DFDFSFD<S<DF<D<F>DFWE242$>@$>@>$&&&&!!!>> dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
		quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat
		. Duis aute irure dolor in reprehenderit in voluptate velit esse
		 cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
		}) do |hash|
		puts hash.inspect
	end
	
	# # plist
	# plist = []
	# Subversion::LogParser.parse_path(test_path) do |hash|
	# 	plist << hash
	# end
	# puts plist.to_plist
	
end

