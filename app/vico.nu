; JSON serializer for Nu cells
(class NuCell
	(- (id) proxyForJson is (self array)))

(global NSNotFound -1)

(global ViNormalMode 1)
(global ViInsertMode 2)
(global ViVisualMode 4)

(global ViMapSetsDot 1)
(global ViMapNeedMotion 2)
(global ViMapIsMotion 4)
(global ViMapLineMode 8)
(global ViMapNeedArgument 16)

(global current-window (do () (ViWindowController currentWindowController)))
(global current-explorer (do () ((current-window) explorer)))
(global current-document (do () ((current-window) currentDocument)))
(global current-view (do () ((current-window) currentView)))
(global current-text (do () ((current-view) innerView)))
(global current-tab (do () ((current-view) tabController)))
(global user-defaults (do () (NSUserDefaults standardUserDefaults)))

(global eventManager (ViEventManager defaultManager))
(global NSApp (NSApplication sharedApplication))

