# -----------------------
# TextMate::Process.run()
# -----------------------
# Method for opening processes under TextMate.
#
# # BASIC USAGE
#
# 1. out, err = TextMate::Process.run("svn", "commit", "-m", "A commit message")
#
#   'out' and 'err' are the what the process produced on stdout and stderr respectively.
#
# 2. TextMate::Process.run("svn", "commit", "-m", "A commit message") do |str, type|
#   case type
#   when :out
#     STDOUT << str
#   when :err
#     STDERR << str
#   end
# end
#
#   The block will be called with the output of the process as it becomes available.
#
# 3. TextMate::Process.run("svn", "commit", "-m", "A commit message") do |str|
#   STDOUT << str
# end
#
#   Similar to 2, except that the type of the output is not passed.
#
# # OPTIONS
#
# The last (non block) argument to run() can be a Hash that will augment the behaviour.
# The available options are (with default values in parenthesis)…
#
# * :interactive_input (true)
#
# Inject the interactive input library into the program so that any requests for
# input present the user with a dialog to enter it.
#
# * :echo (false)
#
# If using interactive input, echo the user's input onto the output
# (has no effect if interactive input is off).
#
# * :granularity (:line)
#
# The size of the buffer to use to read the process output. The value :line
# indicates that output will be passed a line at a time. Any other non integer
# value will result in an unspecified buffer size being used.
#
# * :input (nil)
#
# A string to send to the stdin of the process.
#
# * :env (nil)
#
# A hash of environment variables to set for the process.
#
# NOTES
#
# The following is not valid Ruby…
#
#   args = ["commit", "-m", "commit message"]
#   TextMate::Process("svn", *args, :buffer => true)
#
# To get around this, arguments to run() are flattened. This allows the
# almost as good version…
#
#   args = ["commit", "-m", "commit message"]
#   TextMate::Process("svn", args, :buffer => true)
#

require ENV['TM_SUPPORT_PATH'] + '/lib/io'
require 'fcntl'

module PTree # Process Tree Construction
    module_function

    def build
        list = %x{ps -axww -o "pid,ppid,command="}.sub(/^.*$\n/, '')

    all_nodes = { }
    all_nodes[0] = { :pid => 0, :cmd => 'System Startup', :children => [ ] }

        list.each do |line|
            abort "Syntax error: #{line}" unless line =~ /^\s*(\d+)\s+(\d+)\s+(.*)$/
      all_nodes[$1.to_i] = { :pid => $1.to_i, :ppid => $2.to_i, :cmd => $3, :children => [ ] }
        end

    all_nodes.each do |pid, process|
      next if pid == 0
      abort "Inconsistent Process Tree: parent (#{process[:ppid]}) for pid #{pid} does not exist" unless all_nodes.has_key? process[:ppid]
      all_nodes[process[:ppid]][:children] << process
    end

        all_nodes[0]
    end

    def find(tree, pid)
        return tree if tree[:pid] == pid

        tree[:children].each do |child|
            res = find(child, pid)
            return res unless res.nil?
        end

        nil
    end

    def traverse(tree, &block)
        tree[:children].each { |child| traverse(child, &block) }
        block.call(tree)
    end
end

def pid_exists?(pid)
    %x{ps >/dev/null -xp #{pid}}
    $? == 0
end

def kill_and_wait(pid)
    begin
        Process.kill("INT", pid)
        20.times { return unless pid_exists?(pid); sleep 0.02 }
        Process.kill("TERM", pid)
        20.times { return unless pid_exists?(pid); sleep 0.02 }
        Process.kill("KILL", pid)
    rescue
        # process doesn't exist anymore
    end
end

def setup_kill_handler(pid, &block)
    Signal.trap("USR1") do
        did_kill = false
        PTree.traverse(PTree.find(PTree.build, pid)) do |node|
            if !did_kill && pid_exists?(node[:pid])
                block.call("^C: #{node[:cmd]} (pid: #{node[:pid]})\n", :err)
                kill_and_wait(node[:pid])
                did_kill = true
            end
        end
	end
end

module TextMate
  module Process
    class << self

      TM_INTERACTIVE_INPUT_DYLIB = ENV['TM_SUPPORT_PATH'] + '/lib/tm_interactive_input.dylib'
      def run(*cmd, &block)

        cmd.flatten!

        options = {
          :interactive_input => true,
          :echo => false,
          :granularity => :line,
          :input => nil,
          :env => nil,
          :watch_fds => { },
        }

        options.merge! cmd.pop if cmd.last.is_a? Hash

        io = []
        3.times { io << ::IO::pipe }

        # F_SETOWN = 6, ideally this would be under Fcntl::F_SETOWN
        io[0][0].fcntl(6, ENV['TM_PID'].to_i) if ENV.has_key? 'TM_PID'

        pid = fork {
          at_exit { exit! }
          
          STDIN.reopen(io[0][0])
          STDOUT.reopen(io[1][1])
          STDERR.reopen(io[2][1])

          io.flatten.each { |fd| fd.close }

          options[:env].each { |k,v| ENV[k] = v } unless options[:env].nil?

          if options[:interactive_input] and File.exists? TM_INTERACTIVE_INPUT_DYLIB
            dil = ENV['DYLD_INSERT_LIBRARIES']
            if dil.nil? or dil.empty?
              ENV['DYLD_INSERT_LIBRARIES'] = TM_INTERACTIVE_INPUT_DYLIB
            elsif not dil.include? TM_INTERACTIVE_INPUT_DYLIB
              ENV['DYLD_INSERT_LIBRARIES'] = "#{TM_INTERACTIVE_INPUT_DYLIB}:#{dil}"
            end

            ENV['DYLD_FORCE_FLAT_NAMESPACE'] = "1"
            ENV['TM_INTERACTIVE_INPUT'] = "AUTO" + ((options[:echo]) ? "|ECHO" : "")
          end

          exec(*cmd.compact)
        }

        [ io[0][0], io[1][1], io[2][1] ].each { |fd| fd.close }

        if echo_fd = ENV['TM_INTERACTIVE_INPUT_ECHO_FD']
          ::IO.for_fd(echo_fd.to_i).close
          ENV.delete('TM_INTERACTIVE_INPUT_ECHO_FD')
        end

        if options[:input].nil?
          io[0][1].close
        else
          Thread.new { (io[0][1] << options[:input]).close }
        end

        out = ""
        err = ""

        block ||= proc { |str, fd|
          case fd
            when :out then out << str
            when :err then err << str
          end
        }

        previous_block_size = IO.blocksize
        IO.blocksize = options[:granularity] if options[:granularity].is_a? Integer
        previous_sync = IO.sync
        IO.sync = true unless options[:granularity] == :line

        setup_kill_handler(pid, &block)

        IO.exhaust(options[:watch_fds].merge(:out => io[1][0], :err => io[2][0]), &block)
        ::Process.waitpid(pid)

        IO.blocksize = previous_block_size
        IO.sync = previous_sync

        block_given? ? nil : [out,err]
      end

    end
  end
end