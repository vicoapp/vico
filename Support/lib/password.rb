# Example usage:
# 
#   require "password"
# 
#   TextMate.call_with_password({ :user => 'duff', :url => 'http://example.com/blog/xmlrpc.php' }) do |pw|
#     pw == "foo" ? :reject_pw : :accept_pw
#   end
require "#{ENV["TM_SUPPORT_PATH"]}/lib/ui"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/textmate"

module TextMate

  def TextMate.call_with_password(args, &block)
    user, url = args[:user], args[:url]
    abort "misformed URL #{url}" unless url =~ %r{^(\w+)://([^/]+)(.*?/?)[^/]*$}
    proto, host, path = $1, $2, $3

    action = :reject_pw

    rd, wr = IO.pipe
    if pid = fork
      wr.close
      Process.waitpid(pid)
    else
      STDERR.reopen(wr)
      STDOUT.reopen('/dev/null', 'r')
      rd.close; wr.close
      exec(['/usr/bin/security', TextMate.app_path + "/Contents/MacOS/TextMate"], 'find-internet-password', '-g', '-a', user, '-s', host, '-r', proto)
    end

    action = block.call($1) if rd.gets =~ /^password: "(.*)"$/
    rd.close

    while action == :reject_pw
      break unless res = TextMate::UI.request_secure_string(:title => "Enter Password", :prompt => "Enter password for #{user} at #{proto}://#{host}#{path}")

      action = block.call(res)
      if action == :accept_pw then
        %x{security add-internet-password -a "#{user}" -s "#{host}" -r "#{proto}" -p "#{path}" -w "#{res}"}
      end
    end

    return action
  end

end
