module TextMate
  module Event
    module NotificationMechanism
      class Base
      
        attr_reader :scope, :conf, :title, :msg
      
        def initialize(scope, conf, title, msg)
          @scope = scope
          @title = title
          @msg = msg
          @conf = conf
        end
      
        def name 
          conf.name
        end
      
        def self.notification_pref_hash
          {"name" => name, "code" => code}
        end
      end

    end
  end
end