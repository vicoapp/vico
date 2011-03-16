# Searches current file for \label{} commands. If in a project setting, and if TM_LATEX_MASTER is set, then
# searches all files \include'd in the master latex file.
#
#
# If TM_LATEX_MASTER is present, look for all \include commands in it, and add those files to the search.
# Otherwise, work with current file.
if !(ENV.has_key?("TM_LATEX_MASTER")) then
  if ENV.has_key?("TM_FILEPATH") then 
    filelist = [ENV["TM_FILEPATH"]]
  else
    exit 1
  end
else
  masterfile = ENV["TM_LATEX_MASTER"]
  filepath = File.dirname(masterfile) + "/"
  filelist = Array.new
  File.open("#{masterfile}") do |theFile|
    theFile.each { |line|
      if line.match(/\\include\{([^}]*)(\.tex)?\}/)
        filelist << (filepath + $1 + ".tex")
      end
    }
  end
end

# Get label prefix to expand
if !(ENV.has_key?("TM_CURRENT_WORD")) then
  matchregex = /^(.*)\\label\{([^}]*)\}/
else
  word = ENV["TM_CURRENT_WORD"].to_s
  if !(/\{/.match(word)) then
    word = word.gsub(/\}/,'')
    print "\"#{word}\","
    matchregex = Regexp.new("^(.*)\\\\label\\{(#{word}[^}]*)\\}")
  else
    matchregex = /^(.*)\\label\{([^}]*)\}/
  end
end
# Process the filelist looking for \label{} commands.
filelist.each {|filename|
  File.open("#{filename}") do |theFile|
#    lastline = ""
    theFile.each { |line|
      if line.match(matchregex)
        m = $~
# Commented out because it doesn't work as it's supposed to.
# if there is nothing in front of the \label, then use the previous line as context.
#        if m[1].to_s.match(/[\t\s]*/) then
#          context = lastline.dump
#        else 
#          context = m[1]
#        end
        context = m[1]
        print "\"#{context.gsub(/\\/,'')} : #{m[2]}\","
#        print "\"#{context} : #{m[2]}\","
      end
#      lastline=line
    }
  end
  
}
