
# Includes
support = ENV['TM_SUPPORT_PATH']
require(support + "/lib/Builder.rb")
require(support + "/lib/shelltokenize.rb")
require(support + "/lib/escape.rb")
require(support + "/lib/erb_streaming.rb")
require "cgi"
require "erb"

# Arguments
bundle				= ENV['TM_BUNDLE_SUPPORT']
work_path			= ENV['WorkPath']
work_paths			= TextMate.selected_paths_array
ignore_file_pattern = %r{(^|/)(\.[^/]+|Icon|.*\.(tmproj|o|pyc))$}

# First escape for use in the shell, then escape for use in a JS string
def e_sh_js(str)
  (e_sh str).gsub("\\", "\\\\\\\\")
end

def shorten_path(path)
	prefix = ENV['WorkPath']
	if prefix.nil?
		work_paths = TextMate.selected_paths_array
		prefix = work_paths.first unless work_paths.nil? || work_paths.size != 1
	end

	if prefix && prefix == path
		File.basename(path)
	elsif prefix
		File.expand_path(path).gsub(/#{Regexp.escape prefix}\//, '')
	else
		File.expand_path(path).gsub(/#{Regexp.escape File.expand_path('~')}/, '~')
	end
end

svn = ENV['TM_SVN'] || 'svn'
unless svn[0] == ?/
  svn = `which svn`.chomp
  ENV['TM_SVN'] = svn
end

display_title = work_paths[0] if work_path.nil? and (not work_paths.nil?) and (work_paths.size == 1)
display_title ||= '(selected files)'

#
# Status or update?
#
$is_status		= false
$is_checkout	= false
command_name	= 'update'

ARGV.each do |arg|
	case arg
	when '--status'
		$is_status = true
		command_name = 'status'
	when '--checkout'
		$is_checkout = true
		command_name = 'checkout'
	end
end


StatusColumnNames = ['File', 'Property', 'Lock', 'History', 'Switched', 'Repository Lock']

StatusMap = {	'A' => 'added',
				'D' => 'deleted',
				'G' => 'merged',
				'U' => 'updated',
				'M' => 'modified',
				'L' => 'locked',
				'B' => 'broken',
				'R' => 'replaced',
				'C' => 'conflict',
				'!' => 'missing',
				'+' => 'added',
				'"' => 'typeconflict',
				'?' => 'unknown',
				'I' => 'ignored',
				'X' => 'external',
				' ' => 'none'}

# this may be more dynamic in the future
# it also possibly should not be stashed in mup
def status_column_count
	# update has three columns vs. up to eight for status as of 1.3.x
	# But, for status, if we assume eight, we might have compatibility
	# issues with earlier versions which had fewer columns (unless they
	# had more padding than I recall). The last three columns seem to be
	# network status-only, so this isn't a big deal for now.
	$is_status ? 5 : 3
end

def status_colspan
	$is_status ? (status_column_count + 5) : (status_column_count + 1)
end

def status_map(status)
	StatusMap[status]
end

ERB.run_to_stream(IO.read(bundle + '/Templates/Status.rhtml'), STDOUT)
