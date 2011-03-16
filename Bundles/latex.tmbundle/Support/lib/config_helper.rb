require ENV['TM_SUPPORT_PATH'] + "/lib/osx/plist"
module Config
  class <<self
    def load
      return merge_plists(load_default_file,load_user_file)
    end
    
    private
    
    def load_file(filename)
      return nil if !FileTest.exist?(filename)
      File.open(filename) do |f|
        plist = OSX::PropertyList.load(f)
        return plist
      end
    end
    def load_user_file
      user_file = File.expand_path('~/Library/Preferences/com.macromates.textmate.latex_config.plist')
      load_file(user_file)
    end
    def load_default_file
      default_file = ENV['TM_BUNDLE_SUPPORT'] + "/latex.config"
      load_file(default_file)
    end
    # Merges the two data structures read from plists. The structures should consist of hashes, arrays and strings only. User_list takes precedence in case of ties.
    def merge_plists(default_list,user_list)
      case
      when default_list.nil?
        user_list
      when user_list.nil?
        default_list
      when default_list.is_a?(Hash) && user_list.is_a?(Hash)
        new_hash = Hash.new
        (user_list.keys + default_list.keys ).uniq.each do |key|
          new_hash[key] = merge_plists(default_list[key],user_list[key])
        end
        new_hash
      when default_list.is_a?(Array) && user_list.is_a?(Array)
        (user_list + default_list).uniq
      when default_list.is_a?(String) && user_list.is_a?(String)
        user_list
      else
        raise MismatchedTypesException, "Found mismatched types: #{default_list} is a #{default_list.class} while #{user_list} is a #{user_list.class}."
      end
    end
  end
end