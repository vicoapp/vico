require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification_mechanism/base'
             
module TextMate
  module Event
    module NotificationMechanism
      class Null < Base
    
        def self.name
          "None"
        end
    
        def self.code
          "none"
        end
    
        def fire

        end
      
      end
    end
  end
end

