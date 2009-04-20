#!/usr/bin/env ruby -s
# encoding: utf-8

require ENV['TM_SUPPORT_PATH'] + "/lib/ui"

abort "Wrong arguments: use -path=«file to revert»" if $path.nil? and ARGV.size == 0

svn     = ENV['TM_SVN'] ||  $svn || 'svn'

# get paths from --path or from naked arguments
paths = ARGV.empty? ? [$path] : ARGV

warn_for_paths = []

# Escape paths for shell
paths_for_shell = paths.sort.uniq.map {|path| e_sh(path)}

# Ask for status
status = %x{#{svn} status #{paths_for_shell.join(" ")}}

# Get array of [status, path] tuples
status_for_paths = status.scan(/(.{1,8})\s+(.*)$/)

status_for_paths.each do|status_entry|
  status  = status_entry[0]
  path    = status_entry[1]

	# Reverting added or deleted files will not destroy data
	# Unmodified files will be skipped
  warn_for_paths << path unless (status =~ /^(A|D|\?)/)
end

# TextMate::UI.alert(:warning, "¿Que pasa?", "It's not dangerous to revert the file “#{paths_for_shell.inspect}”.")

res = if warn_for_paths.size > 0 then
  paths_to_display = warn_for_paths.map {|x| File.basename(x)}.join("”, “")
  plural = (warn_for_paths.size == 1) ? '' : 's'
  title_files = (warn_for_paths.size == 1) ? "“#{paths_to_display}”" : 'files'

  TextMate::UI.alert(:warning, "Revert #{title_files}?", "Do you really want to revert the file#{plural} “#{paths_to_display}” and lose all local changes?", 'Revert', 'Cancel')
else
  # Nothing dangerous; be happy
  'Revert'
end

if res =~ /Revert/i then
#  ENV['TM_SVN_REVERT'] = path # by using an env. variable we avoid shell escaping
  puts `#{svn} revert #{paths_for_shell.join(' ')}`
  
  # rescan_project
  %x{osascript &>/dev/null \
	   -e 'tell app "SystemUIServer" to activate' \
	   -e 'tell app "TextMate" to activate' &}
else
  exit -128
end
