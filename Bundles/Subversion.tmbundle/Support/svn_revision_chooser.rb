# encoding: utf-8

# 
#  svn_revision_chooser.rb
#  Subversion.tmbundle
#  
#  Created by Chris Thomas on 2006-12-30.
#  Copyright 2006 Chris Thomas. All rights reserved.
# 

location = File.dirname(__FILE__)
puts location

require "#{ENV["TM_SUPPORT_PATH"]}/lib/osx/plist"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/ui"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/progress"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/escape"

require "#{location}/svn_log_parser.rb"

$nib = "#{location}/nibs/RevisionSelector.nib"
$tm_dialog = "#{ENV["TM_SUPPORT_PATH"]}/bin/tm_dialog"

module Subversion
	
	def self.svn_cmd(args)
		command = %Q{"#{ENV['TM_SVN']||'svn'}" #{args}}
		result_text = %x{#{command}}
		raise "\n#{command}\n#{result_text}" if $CHILD_STATUS != 0
		result_text
	end

	def self.svn_cmd_popen(args)
		command = %Q{"#{ENV['TM_SVN']||'svn'}" #{args}}
		if block_given? then
			IO.popen(command) {|f| f.each_line {|line| yield line}}
		else
			IO.popen(command)
		end
	end

	def self.human_readable_mktemp(filename, rev)
		extname = File.extname(filename)
		filename = File.basename(filename)
		# TODO: Make sure the filename can fit in 255 characters, the limit on HFS+ volumes.

		"#{filename.sub(extname, '')}-r#{rev}#{extname}"
	end

	def self.view_revision(path)
		# Get the desired revision number
		revisions = choose_revision(path, "View revision of #{File.basename(path)}", :multiple)
		return if revisions.nil?

		files						= []

		TextMate.call_with_progress(:title => "View Revision",
										          :summary => "Retrieving revision data…",
															:details => "#{File.basename(path)}") do |dialog|
			revisions.each do |revision|
				# Get the file at the desired revision
				dialog.parameters = {'summary' => "Retrieving revision #{revision}…"}

				temp_name = '/tmp/' + human_readable_mktemp(path, revision)
				svn_cmd("cat -r#{revision} #{e_sh path} > #{e_sh temp_name}")
				files << temp_name
		  end
		end

		# Open the files in TextMate and delete them on close
		### mate -w doesn't work on multiple files, so we'll do one file at a time...
		files.each do |file|
			fork do 
				%x{"#{ENV['TM_SUPPORT_PATH']}/bin/mate" -w #{e_sh(file)}}
				File.delete(file)
			end
		end
	end

	# on failure: returns nil
	def self.choose_revision(path, prompt, number_of_revisions = 1)
		escaped_path = e_sh(path)

		# Validate file
		case svn_cmd("status #{escaped_path}")
		when /^\?.*/
			TextMate::UI.alert(:warning, "File “#{File.basename(path)}” is not in the repository.", "Please add the file to the repository before using this command.")
			return nil
		when /^A.*/
			TextMate::UI.alert(:warning, "File “#{File.basename(path)}” is not in the repository.", "Please commit the file to the repository before using this command.")
			return nil
		end

    # # Get the server name   
    # info = YAML::load(svn_cmd("info #{escaped_path}"))
    # repository = info['Repository Root']
    # uri = URI::parse(repository)
    
    # the above will fail for users that run a localized system
    # instead we should do ‘svn info --xml’, though since the
    # code is not used, I just commented it. --Allan 2007-02-20

		# Display progress dialog
		log_data = ''

		# Show the log
		revision = 0
		TextMate::UI.dialog(:nib => ListNib,
														:center => true,
														:parameters => {'title' => prompt,'entries' => [], 'hideProgressIndicator' => false}) do |dialog|

			# Parse the log
			begin
				plist = []
				log_data = svn_cmd_popen("log --xml #{escaped_path}")

				fork do
					Subversion::LogParser.parse(log_data) do |hash|
						plist << hash
						# update every ten entries (? may do better with a timeout)
						if (plist.size % 10) == 0 then
							dialog.parameters = {'entries' => plist}
						end 
					end
					dialog.parameters = {'entries' => plist, 'hideProgressIndicator' => true}

					if plist.size == 0
						TextMate::UI.alert(:warning, "No revisions of file “#{path}” found", "Either there’s only one revision of this file, and you already have it, or this file was never added to the repository in the first place, or I can’t read the contents of the log for reasons unknown.")
					end
				end
			rescue REXML::ParseException => exception
				TextMate::UI.alert(:warning, "Could not parse log data for “#{path}”", "This may be a bug. Error: #{error}.")
			end

			dialog.wait_for_input do |params|
				revision = params['returnArgument']
				STDERR.puts params['returnButton']
#				STDERR.puts "Want:#{number_of_revisions} got:#{revision.length}"
				button_clicked = params['returnButton']

				if (button_clicked != nil) and (button_clicked == 'Cancel')
					false # exit
				else
					unless (number_of_revisions == :multiple) or (revision.length == number_of_revisions) then
						TextMate::UI.alert(:warning, "Please select #{number_of_revisions} revision#{number_of_revisions == 1 ? '' : 's'}.", "So far, you have selected #{revision.length} revision#{revision.length == 1 ? '' : 's'}.")
						true # continue
					else
						false # exit
					end
				end
			end

#			dialog.close
		end

		# Return the revision number or nil
		revision = nil if revision == 0
		revision
	end
	
end


if __FILE__ == $0
	
#	test_path = "~/Library/Application Support/TextMate/Bundles/Ada.tmbundle"
	test_path = "~/TestRepo/TestFiles"
	
	Subversion.choose_revision_of_path(test_path)
end