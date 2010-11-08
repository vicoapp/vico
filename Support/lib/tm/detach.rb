# encoding: utf-8

require ENV['TM_SUPPORT_PATH'] + '/lib/ui.rb'

module TextMate
  class << self
    def detach(&block)
      pid = fork do
        STDOUT.reopen(open('/dev/null', 'w'))
        STDERR.reopen(open('/dev/null', 'w'))

        begin
          block.call
        rescue SystemExit => e
          # not sure why this is an exception!?!
        rescue Exception => e
          TextMate::UI.alert(:warning, "Error Running Command", "The script failed with the following exception:\n\n#{pretty_print_exception e}", "OK")
        end
      end
      Process.detach(pid)
    end

    def pretty_print_exception(e)
      str = "#{e.class.name}: #{e.message.sub(/`(\w+)'/, '‘\1’').sub(/ -- /, ' — ')}\n\n"

      e.backtrace.each do |b|
        if b =~ /(.*?):(\d+)(?::in\s*`(.*?)')?/ then
          file, line, method = $1, $2, $3
          display_name = File.basename(file)
          str << "At line #{line} in ‘#{display_name}’ "
          str << (method ? "(inside method ‘#{method}’)" : "(top level)")
          str << "\n"
        end
      end

      str
    end
  end
end

if __FILE__ == $0
  TextMate::detach {
    sleep 1
    gafung
  }

  TextMate::detach {
    sleep 5
    File.open('/tmp/this/is/not/here')
  }
end
