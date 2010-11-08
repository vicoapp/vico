# encoding: utf-8

module TextMate
  module IO
    
    @sync = false
    @blocksize = 4096
    
    class << self
    
      attr_accessor :sync
      def sync?; @sync end
      
      attr_accessor :blocksize

      def exhaust(named_fds, &block)
        
        leftovers = {}
        named_fds = named_fds.dup
        named_fds.delete_if { |key, value| value.nil? }
        named_fds.each_key {|k| leftovers[k] = "" }
        
        until named_fds.empty? do
          
          fd   = select(named_fds.values)[0][0]
          
          name = named_fds.find { |key, value| fd == value }.first
          data = fd.sysread(@blocksize) rescue ""
          
          if data.to_s.empty? then
            named_fds.delete(name)
            fd.close
          
          elsif not sync?
            if data =~ /\A(.*\n|)([^\n]*)\z/m
              if $1 == ""
                leftovers[name] += $2
                next
              end
              lines = leftovers[name].to_s + $1
              leftovers[name] = $2
              case block.arity
                when 1 then lines.each_line { |line| block.call(line) }
                when 2 then lines.each_line { |line| block.call(line, name) }
              end
            else
              raise "Malformed script output (most likely not UTF-8): ‘#{data.to_s}’" 
            end
          
          elsif sync?
            case block.arity
              when 1 then block.call(data)
              when 2 then block.call(data, name)
            end
          
          end
        end
        
        # clean up the crumbs
        if not sync?
          leftovers.delete_if {|name,crumb| crumb == ""}
          case block.arity
            when 1 then leftovers.each_pair { |name, crumb| block.call(crumb) }
            when 2 then leftovers.each_pair { |name, crumb| block.call(crumb, name) }
          end
        end
                
      end
      
    end
    
  end
end

# interactive unit tests
if $0 == __FILE__
  require "open3"
  #TextMate::IO.sync = false
  #TextMate::IO.blocksize = 1

  puts "1=== Line by Line"
  stdin, stdout, stderr = Open3.popen3("echo 'foo\nbar'; echo 1>&2 bar; echo fud")
  TextMate::IO.exhaust(:out => stdout, :err => stderr) do |data, type|
    puts "#{type}: “#{data.rstrip}”"
  end

  puts "2---"
  stdin, stdout, stderr = Open3.popen3('echo oof; echo 1>&2 rab; echo duf')
  TextMate::IO.exhaust(:out => stdout, :err => stderr) do |data|
    puts "“#{data.rstrip}”"
  end
  
  # check that everything still works with sync enabled.
  TextMate::IO.sync = true

  puts "3=== Streaming"  
  stdin, stdout, stderr = Open3.popen3("echo 'foo\nbar'; echo 1>&2 bar; echo fud")
  TextMate::IO.exhaust(:out => stdout, :err => stderr) do |data, type|
    puts "#{type}: “#{data.rstrip}”"
  end

  puts "4---"
  stdin, stdout, stderr = Open3.popen3('echo oof; echo 1>&2 rab; echo duf')
  TextMate::IO.exhaust(:out => stdout, :err => stderr) do |data|
    puts "“#{data.rstrip}”"
  end
end
