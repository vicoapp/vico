module CVS
  CVS_PATH = ENV['CVS_PATH'] || 'cvs' unless defined?(CVS_PATH)
  
  class VersionedFile
    attr_accessor :path
    
    def initialize(path)
      @path = path
    end
    
    def dirname
      (File.dirname(@path) =~ %r{/$}) ? File.dirname(@path) : "#{File.dirname(@path)}/"
    end
    
    def basename
      File.basename @path
    end
    
    def status
      status_from_line cvs(:update, :pretend => true, :quiet => true)
    end
    
    def revision
      $1 if cvs(:status) =~ /Working revision:\s*([\d\.]+)/
    end
    
    def revisions(reload = false)
      @revisions = nil if reload
      @revisions ||= cvs(:log).inject([]) { |list,line| list << $1 if line =~ /^revision ([\d\.]+)/i; list}
    end
    
    def update(options={})
      options = options.dup
      if options.key?(:tag)
        options[:tag] = expand_revision(options[:tag])
        options[:sticky] = true unless options.key?(:sticky)
        options[:command_options] = "#{options[:sticky] ? '-r' : '-j'} #{options[:tag]}"
      elsif options[:reset_tags]
        options[:command_options] = '-A'
      end
      cvs(:update, options)
    end
    
    def diff(revision, other_revision = nil)
      revision, other_revision = expand_revision(revision), expand_revision(other_revision)
      
      if other_revision
        cvs(:diff, "-r #{other_revision} -r #{revision}")
      else
        cvs(:diff, "-r #{revision}")
      end
    end
    
    def version(revision)
      cvs(:update, "-p -r #{expand_revision(revision)}")
    end
    
    def commit(options={})
      options = options.dup
      options[:command_options] = "-m '#{options.delete(:message).gsub(/'/, "\\'")}'" if options.key?(:message)
      cvs(:commit, options)
    end
    
    def cvs(command, options={})
      options = {:command_options => options} if options.is_a? String
      cvs_options = [options[:cvs_options]].flatten.compact
      cvs_options << '-n' if options[:pretend]
      cvs_options << '-q' if options[:quiet]
      cvs_options << '-Q' if options[:silent]
      cvs_options = cvs_options.join(' ')
      
      files = options[:files] || [basename]
      files = files.map { |file| %("#{file.gsub(/"/, '\\"')}") }.join(' ')
      %x{cd "#{dirname}"; "#{CVS_PATH}" #{cvs_options} #{command} #{options[:command_options]} #{files} 2> /dev/null}
    end

    %w(status revisions diff revision version cvs).each do |method|
      class_eval "def self.#{method}(path, *args); new(path).#{method}(*args); end"
    end
    
    protected
    
    def expand_revision(revision)
      case revision
      when :head then 'HEAD'
      when :base then 'BASE'
      when :prev then revisions[revisions.index(self.revision)+1] rescue nil
      else revision
      end
    end
    
    def status_from_line(line)
      case line
      when /^(U|P) /i then :stale
      when /^A /i then     :added
      when /^M /i then     :modified
      when /^C /i then     :conflicted
      when /^\? /i then    :unknown
      when /^R /i then     :removed
      else                 :current
      end      
    end
  end
end