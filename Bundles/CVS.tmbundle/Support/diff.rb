module CVS
  class Diff
    attr_accessor :raw
    
    def initialize(raw)
      @raw = raw
    end
    
    def changes(reload=false)
      @changes = nil if reload
      @changes ||= @raw.split(/\n/)[5..-1].select { |l| l =~ /^\d/ }.inject({}) do |changes,line|
        changes.merge change_from_hunk_header(line)
      end rescue []
    end
    
#     def source_line_status(n)
#       changes.find { |(lines,status)| lines.include?(n) }.last rescue :unchanged
#     end
    
    def source_line(n)
      m = n
      changes.each do |(lines,status)|
        case status
        when :added
          return :added if lines.include?(n)
          m -= lines.to_a.length if lines.end < n
        when :deleted
          m += lines.to_a.length if lines.begin <= n
        end
      end
      m
    end
    
    private
    
    def change_from_hunk_header(line)
      case line
      when /^(\d+),(\d+)d(\d+)$/
        {($1.to_i)..($2.to_i) => :deleted}
      when /^(\d+)a(\d+),(\d+)$/
        {($2.to_i)..($3.to_i) => :added}
      when /^(\d+)c(\d+)/
        {($1.to_i)..($1.to_i) => :changed}
      end
    end
  end
end