# encoding: utf-8

require ENV["TM_SUPPORT_PATH"] + "/lib/escape"
require ENV["TM_SUPPORT_PATH"] + "/lib/exit_codes"

module TextMate
  class << self
    def require_cmd(cmd)
      unless File.executable?(cmd) or ENV['PATH'].split(':').any? { |dir| File.executable? File.join(dir, cmd) }
        TextMate::HTMLOutput.show(:title => "Can't find “#{cmd}” on PATH.", :sub_title => "") do |io|
          io << "<p>The current PATH is:</p>"
          io << "<blockquote>"
          ENV["PATH"].split(":").each do |p|
            io << htmlize(p + "\n")
          end
          io << "</blockquote>"
          io << "<p>Please add the directory containing “<code>#{cmd}</code>” to <code>PATH</code> in TextMate's Shell Variables preferences.</p>"
          io << "<p>Alternatively, the PATH can be retrieved from Terminal but this requires a relaunch: "
          io << "<button onclick=\"TextMate.system('#{(ENV["TM_SUPPORT_PATH"]+"/bin/set_tm_path.sh").gsub(" ", "\\\\\\\\ ")}', null)\">Set PATH and Relaunch.</button></p>"
        end
        TextMate.exit_show_html
      end
    end
  end
end
