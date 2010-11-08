require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification_preferences'
require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification_mechanism'

module TextMate
  module Event
    class Notification
    
      def initialize(data)
        @data = data
      end
    
      def name
        @data["name"]
      end
    
      def mechanism
        NotificationMechanism.all.find { |t| @data["mechanism"]["code"] == t.code }
      end
    
      def scope_selector
        @data["scope_selector"] || ""
      end
    
      def fire(scope, title, msg)
        mechanism.new(scope, self, title, msg).fire
      end
      
      def self.all
        NotificationPreferences.notifications
      end
      
      def self.all_for_mechanism(mechanism)
        all.find_all { |notification| notification.mechanism == mechanism }
      end
    end
  end
end