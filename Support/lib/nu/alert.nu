((NSApplication sharedApplication) activateIgnoringOtherApps:YES)

(unless (defined? buttonTitles)
	(set buttonTitles (NSArray arrayWithList:'("OK" "Cancel"))))
(unless (defined? messageTitle)
	(set messageTitle "Something happened"))
(unless (defined? informativeText)
	(set informativeText "It was unexpected"))
(unless (defined? alertStyle)
	(set alertStyle "informational"))

(set alert ((NSAlert alloc) init))
(buttonTitles each: (do (title)
	(alert addButtonWithTitle:title)))
(alert setMessageText:messageTitle)
(alert setInformativeText:informativeText)
(case alertStyle
	("warning" (alert setAlertStyle:NSWarningAlertStyle))
	("critical" (alert setAlertStyle:NSCriticalAlertStyle))
	(else (alert setAlertStyle:NSInformationalAlertStyle)))

(shellCommand exitWithObject:(- (alert runModal) 1000))

