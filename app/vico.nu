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

(global NSStreamEventNone 0)
(global NSStreamEventOpenCompleted 1)
(global NSStreamEventHasBytesAvailable 2)
(global NSStreamEventHasSpaceAvailable 4)
(global NSStreamEventErrorOccurred 8)
(global NSStreamEventEndEncountered 16)
(global ViStreamEventWriteEndEncountered 4711)

(class NSTask
	(- (id)streamWithInput:(id)stdinData is
		(set stdout (NSPipe pipe))
		(if (eq stdinData nil)
			(set stdin (NSFileHandle fileHandleWithNullDevice))
			(else (set stdin (NSPipe pipe))))
		(self setStandardInput:stdin)
		(self setStandardOutput:stdout)
		(NSLog "launching #{(self launchPath)} with arguments #{((self arguments) description)}")
		(self launch)
		(NSLog "launched task with pid #{(self processIdentifier)}")
		(set stream (ViBufferedStream streamWithTask:self))
		(stream scheduleInRunLoop:(NSRunLoop currentRunLoop) forMode:NSDefaultRunLoopMode)
		(stream)))


(global NSLog (NuBridgedFunction functionWithName:"nu_log" signature:"v@"))
(global puts (NuBridgedFunction functionWithName:"nu_log" signature:"v@"))

