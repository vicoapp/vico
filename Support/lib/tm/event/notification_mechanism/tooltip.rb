require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification_mechanism/base'
require ENV['TM_SUPPORT_PATH'] + '/lib/ui'
             
module TextMate
  module Event
    module NotificationMechanism
      class Tooltip < Base
    
        def self.name
          "Tool Tip"
        end
    
        def self.code
          "tooltip"
        end
    
        def fire
          TextMate::UI.tool_tip("<strong>#{htmlize title}</strong><p>#{htmlize msg}</p>", :format => :html)
        end

      end
    end
  end
end

