require 'English' # you are angry, english!

cvs				= ENV['TM_CVS']
#commit_paths	= ENV['CommitPaths']
commit_tool		= ENV['CommitWindow']
bundle			= ENV['TM_BUNDLE_SUPPORT']
support			= ENV['TM_SUPPORT_PATH']
ignore_file_pattern = /(\/.*)*(\/\..*|\.(tmproj|o|pyc)|Icon)/

CURRENT_DIR		= Dir.pwd + "/"

require (bundle + '/versioned_file.rb')
require (bundle + '/working_copy.rb')
require (support + '/lib/shelltokenize.rb')
require (bundle + "/lib/Builder.rb")

mup = Builder::XmlMarkup.new(:target => STDOUT)

mup.html {
	mup.head {
			mup.title("CVS commit")
			mup.style( "@import 'file://"+bundle+"/Stylesheets/cvs_style.css';", "type" => "text/css")
	}

	mup.body { 
		mup.h1("CVS Commit")
		STDOUT.flush
		mup.hr

		# Ignore files without changes
#puts TextMate::selected_paths_for_shell
    working_copies = TextMate::selected_paths_array.map do |path|
      File.directory?(path) ?
        CVS::WorkingCopy.new(path) :
        CVS::VersionedFile.new(path)
    end
    
		#status_command = %Q{"#{cvs}" -nq update #{TextMate::selected_paths_for_shell}}
#puts status_command
		#status_output = %x{#{status_command}}
#puts status_output
		#paths = status_output.scan(/^(.)....(\s+)(.*)\n/)
		status = working_copies.inject({}) do |h,wc|
		  case wc
	    when CVS::WorkingCopy then h.update(wc.status)
      when CVS::VersionedFile then h.update(wc.path => wc.status)
      end
		  h
		end
		paths = status.keys
		

    def paths_for_status(hash, *status)
      hash.inject([]) { |arr,(k,v)| arr << k if status.include?(v); arr }
    end
    
# 		def status_to_paths()
# 			paths = matches.collect { |m| m[2] }
# 			paths.collect{|path| path.sub(/^#{CURRENT_DIR}/, "") }
# 		end

		def matches_to_status(matches)
			matches.collect {|m| m[0]}
		end
		
		# Ignore files with '?', but report them to the user
		#unknown_paths = paths.select { |m| m[0] == '?' }
		
		unknown_paths = paths_for_status(status, :unknown)
		unknown_to_report_paths = unknown_paths.select { |path| ignore_file_pattern =~ path }
		
    #unknown_to_report_paths = paths.select{ |m| m[0] == '?' and not ignore_file_pattern =~ m[2]}
		unless unknown_to_report_paths.empty?
			mup.div( "class" => "info" ) {
				mup.text! "These files are not added to the repository, and so will not be committed:"		
				mup.ul{ unknown_to_report_paths.each{ |path| mup.li(path) } }
			}
		end

		# Fail if we have conflicts -- cvs commit will fail, so let's
		# error out before the user gets too involved in the commit
		conflict_paths = paths_for_status(status, :conflicted)

		unless conflict_paths.empty?
			mup.div( "class" => "error" ) {
				mup.text! "Cannot continue; there are merge conflicts in files:"		
				mup.ul{ conflict_paths.keys.each { |path| mup.li(path) } }
				mup.text! "Canceled."
			}	
			exit -1
		end

		# Remove the unknown paths from the commit
		commit_paths = paths.select { |path| [:modified, :added, :removed].include? status[path] }

		if commit_paths.empty?
			mup.div( "class" => "info" ) {
				mup.text! "File(s) not modified; nothing to commit."
				mup.ul{ unknown_paths.keys.each { |path| mup.li(path) } }
			}
			exit 0
		end

		STDOUT.flush

		commit_status = commit_paths.map { |path| status[path].to_s[0,1].upcase }.join(":")
		
		commit_path_text = commit_paths.collect { |path| path.quote_filename_for_shell }.join(" ")

		commit_args = %x{"#{commit_tool}" --status #{commit_status} #{commit_path_text}}

		status = $CHILD_STATUS
		if status != 0
			mup.div( "class" => "error" ) {
				mup.text! "Canceled (#{status >> 8})."
			}	
			exit -1
		end

		mup.div("class" => "command"){ mup.strong(%Q{#{cvs} commit }); mup.text!(commit_args) }
		
		mup.pre {
			STDOUT.flush

      puts working_copies.first.cvs(:commit, commit_args.gsub(working_copies.first.dirname, ''))
		}
	}
}