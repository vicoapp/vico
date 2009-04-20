#!/usr/bin/env ruby -w
# encoding: utf-8

$LOAD_PATH << ENV['TM_SUPPORT_PATH'] + "/lib"
require 'progress'
require 'versioned_file'

module CVS
	def CVS.diff_active_file(revision, command)
		target_path	= ENV['TM_FILEPATH']
		output_path	= File.basename(target_path) + ".diff"

		TextMate::call_with_progress(:title => command,
									:message => "Accessing CVS Repository…",
									:output_filepath => output_path) do
			have_data = false
			
			# idea here is to stream the data rather than submit it in one big block
			VersionedFile.diff(target_path, revision).each_line do |line|
				have_data = true unless line.empty?
				puts line
			end
			
			if not have_data then
				# switch to tooltip output to report lack of differences
				puts "No differences found."
				exit 206;
			end
		end
	end
end
