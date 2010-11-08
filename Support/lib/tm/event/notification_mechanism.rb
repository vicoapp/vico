module TextMate
  module Event
    module NotificationMechanism

      def self.all
        require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification_mechanism/growl'
        require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification_mechanism/null'
        require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification_mechanism/tooltip'
        [Null, Tooltip, Growl]
      end

    end
  end
end