
# Cocoa Functions
find /System/Library/Frameworks/{AppKit,Foundation}.framework -name \*.h -exec grep '^[A-Z][A-Z_]* [^;]* \**NS[A-Z][A-Za-z]* *(' '{}' \;|perl -pe 's/.*?\s\*?(NS\w+)\s*\(.*/$1/'|sort|uniq|./list_to_regexp.rb >/tmp/functions.txt

# Cocoa Protocols Classes
{ find /System/Library/Frameworks/{AppKit,Foundation}.framework -name \*.h -exec grep '@interface NS[A-Za-z]*' '{}' \;|perl -pe 's/.*?(NS[A-Za-z]+).*/$1/';
  find /System/Library/Frameworks/{AppKit,Foundation}.framework -name \*.h -exec grep '@protocol NS[A-Za-z]*' '{}' \;|perl -pe 's/.*?(NS[A-Za-z]+).*/$1/';
}|sort|uniq|./list_to_regexp.rb >/tmp/classes.txt

# Cocoa Types
find /System/Library/Frameworks/{AppKit,Foundation}.framework -name \*.h -exec grep 'typedef .* _*NS[A-Za-z]*' '{}' \;|perl -pe 's/.*?(NS[A-Za-z]+);.*/$1/'|perl -pe 's/typedef .*? _?(NS[A-Za-z0-9]+) \{.*/$1/'|grep -v typedef|sort|uniq|./list_to_regexp.rb >/tmp/types.txt

# Cocoa Constants
find /System/Library/Frameworks/{AppKit,Foundation}.framework -name \*.h -exec awk '/\}/ { pr = 0; } { if(pr) print $0; } /^(typedef )?enum .*\{[^}]*$/ { pr = 1; }' '{}' \;|expand|grep '^ *NS[A-Z]'|perl -pe 's/^\s*(NS[A-Z][A-Za-z0-9_]*).*/$1/'|sort|uniq|./list_to_regexp.rb >/tmp/constants.txt

# Cocoa Notifications
find /System/Library/Frameworks/{AppKit,Foundation}.framework -name \*.h -exec grep '\*NS.*Notification' '{}' \;|perl -pe 's/.*?(NS[A-Za-z]+Notification).*/$1/'|sort|uniq|./list_to_regexp.rb >/tmp/notifications.txt