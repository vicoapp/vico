require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification_mechanism/base'
require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification'
require ENV['TM_SUPPORT_PATH'] + '/lib/textmate'
require ENV['TM_SUPPORT_PATH'] + '/lib/ui'
require 'osx/cocoa'
             
module TextMate
  module Event
    module NotificationMechanism
      class Growl < Base
          
        def self.name
          "Growl"
        end
    
        def self.code
          "growl"
        end
    
        def self.available?
          %x{ps -xwwco "command" | grep -sq '^GrowlHelperApp$'}
          $? == 0
        end

        def self.icon
          require 'osx/cocoa'
          app_path = TextMate.app_path
          plist = open(app_path + '/Contents/Info.plist') { |io| OSX::PropertyList.load(io) }
          icon  = app_path + '/Contents/Resources/' + plist['CFBundleIconFile'] + ".icns"
          OSX::NSImage.alloc().initWithContentsOfFile_(icon).TIFFRepresentation
        end
        
        def self.register
            growl_notifications = Notification.all_for_mechanism(Growl).collect { |n| n.name }
            regData = {
                'ApplicationName'=> TextMate.app_name,
                'AllNotifications'=> growl_notifications,
                'DefaultNotifications'=> growl_notifications,
                'ApplicationIcon'=> Growl.icon
            }
                  
            dict = OSX::NSDictionary.dictionaryWithDictionary(regData)
            notifyCenter = OSX::NSDistributedNotificationCenter.defaultCenter
        
            notifyCenter.postNotificationName_object_userInfo_deliverImmediately_("GrowlApplicationRegistrationNotification", nil, dict, true)
        end

        def fire
          if Growl.available?
            d = OSX::NSDictionary.dictionaryWithDictionary_({
              'NotificationName'=> name,
              'ApplicationName'=> TextMate.app_name,
              'NotificationTitle'=> title,
              'NotificationDescription'=> msg
            })
            notCenter = OSX::NSDistributedNotificationCenter.defaultCenter()
            notCenter.postNotificationName_object_userInfo_deliverImmediately_('GrowlNotification', nil, d, true)
         else
           TextMate::UI.tool_tip("<strong>#{htmlize title}</strong><p>#{htmlize msg}</p>", :format => :html)
         end
        end
      
        Growl.register if Growl.available?
      
      end
    end
  end
end

