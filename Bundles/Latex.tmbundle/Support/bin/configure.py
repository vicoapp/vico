#!/usr/bin/env python

import os
import tmprefs
pref = tmprefs.Preferences()
defaults = '-d ' + "'" + pref.toDefString() + "' "
command = '"$DIALOG"' + ' -mp "" ' + defaults + '"$TM_BUNDLE_SUPPORT"'+"/nibs/tex_prefs.nib"
sin,result = os.popen4(command)

#print result