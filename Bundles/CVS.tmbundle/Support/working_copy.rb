module CVS
  class WorkingCopy < VersionedFile
    def initialize(path)
      @path = (path =~ %r{/$}) ? path : "#{path}/" # add / if not there
    end
    
    def dirname
      @path
    end
    
    def basename
      '.'
    end
    
    def status
      cvs(:update, :pretend => true, :quiet => true).inject({}) do |files,line|
        files.update($1 => status_from_line(line)) if line =~ /^\S (.*)$/
        files
      end
    end
  end
end