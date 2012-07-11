; JSON serializer for Nu cells
(class NuCell
	(- (id) proxyForJson is (self array)))

(load "cocoa")

(global NSNotFound -1)

(global ViNormalMode 1)
(global ViInsertMode 2)
(global ViVisualMode 4)

(global ViMapSetsDot 1)
(global ViMapNeedMotion 2)
(global ViMapIsMotion 4)
(global ViMapLineMode 8)
(global ViMapNeedArgument 16)
(global ViMapNoArgumentOnToggle 32)

(global ViRegexpIgnoreCase 1)

(global current-window (do () (ViWindowController currentWindowController)))
(global current-explorer (do () ((current-window) explorer)))
(global current-document (do () ((current-window) currentDocument)))
(global current-view (do () ((current-window) currentView)))
(global current-text (do () ((current-view) innerView)))
(global current-tab (do () ((current-view) tabController)))

(global eventManager (ViEventManager defaultManager))
(global event-manager (ViEventManager defaultManager))
(global mark-manager (ViMarkManager sharedManager))
(global user-defaults (NSUserDefaults standardUserDefaults))
(global NSApp (NSApplication sharedApplication))

(global NSStreamEventNone 0)
(global NSStreamEventOpenCompleted 1)
(global NSStreamEventHasBytesAvailable 2)
(global NSStreamEventHasSpaceAvailable 4)
(global NSStreamEventErrorOccurred 8)
(global NSStreamEventEndEncountered 16)
(global ViStreamEventWriteEndEncountered 4711)

(global NSLog (NuBridgedFunction functionWithName:"nu_log" signature:"v@"))
(global puts (NuBridgedFunction functionWithName:"nu_log" signature:"v@"))

(global NSMaxRange (do (range) (+ (range first) (range second))))
(global NSBackwardsSearch 4)

(global ViViewPositionDefault 0)
(global ViViewPositionPreferred 1)
(global ViViewPositionReplace 2)
(global ViViewPositionTab 3)
(global ViViewPositionSplitLeft 4)
(global ViViewPositionSplitRight 5)
(global ViViewPositionSplitAbove 6)
(global ViViewPositionSplitBelow 7)

(bridge constant NSImageNameStatusAvailable "@")
(bridge constant NSImageNameStatusPartiallyAvailable "@")
(bridge constant NSImageNameStatusUnavailable "@")

(bridge constant NSFontAttributeName "@")
(bridge constant NSParagraphStyleAttributeName "@")
(bridge constant NSForegroundColorAttributeName "@")
(bridge constant NSUnderlineStyleAttributeName "@")
(bridge constant NSSuperscriptAttributeName "@")
(bridge constant NSBackgroundColorAttributeName "@")
(bridge constant NSAttachmentAttributeName "@")
(bridge constant NSLigatureAttributeName "@")
(bridge constant NSBaselineOffsetAttributeName "@")
(bridge constant NSKernAttributeName "@")
(bridge constant NSLinkAttributeName "@")
(bridge constant NSStrokeWidthAttributeName "@")
(bridge constant NSStrokeColorAttributeName "@")
(bridge constant NSUnderlineColorAttributeName "@")
(bridge constant NSStrikethroughStyleAttributeName "@")
(bridge constant NSStrikethroughColorAttributeName "@")
(bridge constant NSShadowAttributeName "@")
(bridge constant NSObliquenessAttributeName "@")
(bridge constant NSExpansionAttributeName "@")
(bridge constant NSCursorAttributeName "@")
(bridge constant NSToolTipAttributeName "@")
(bridge constant NSMarkedClauseSegmentAttributeName "@")
(bridge constant NSWritingDirectionAttributeName "@")
(bridge constant NSVerticalGlyphFormAttributeName "@")


(global NSLineBreakByWordWrapping 0)
(global NSLineBreakByCharWrapping 1)
(global NSLineBreakByClipping 2)
(global NSLineBreakByTruncatingHead 3)
(global NSLineBreakByTruncatingTail 4)
(global NSLineBreakByTruncatingMiddl 5)

