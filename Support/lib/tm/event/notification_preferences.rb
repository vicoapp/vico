require ENV['TM_SUPPORT_PATH'] + '/lib/ui'
require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification'
require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification_mechanism'
require ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/notification_mechanism/tooltip'

module TextMate
  module Event
    module NotificationPreferences
       class  << self
         
         @@filename = File.expand_path "~/Library/Preferences/com.macromates.textmate.notifications.plist"
         @@prefs = nil

         def read
           if File.exists? @@filename
             File.open(@@filename, "r") do |f|
               @@prefs = OSX::PropertyList.load(f)
             end
           else
             @@prefs = {
               "notifications" => [
                 {"name" => "All", "mechanism" => NotificationMechanism::Tooltip.notification_pref_hash, "scope_selector" => ""}
                ]
             }
           end
         end

         def save
           File.open(@@filename, "w+") do |f|
             f << @@prefs.to_plist
           end
         end

         def notifications
           @@prefs["notifications"].collect { |c| Notification.new(c) }
         end

         def show
           TextMate::UI.dialog(
             :nib => ENV['TM_SUPPORT_PATH'] + '/lib/tm/event/NotificationPreferences.nib', 
             :parameters => {
               "preferences" => @@prefs,
               "mechanisms" => NotificationMechanism.all.collect { |m| m.notification_pref_hash }
             }
           ) do |dialog|
             dialog.wait_for_input do |params|
               @@prefs = params["preferences"]
               save
               false
             end
           end 
         end

         NotificationPreferences.read

       end
     end
  end
end

if __FILE__ == $PROGRAM_NAME
  TextMate::Event::NotificationPreferences.show
end
