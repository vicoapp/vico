;
; Experimental implementation of texmate's dialog infrastructure.
;

(class ShellNibOwner is NSObject
	(unless ($shellNibLoaded)
		(set $shellNibLoaded t)
		(ivar (id)parameters (id)shellCommand (id)windows))

	(imethod (id) initWithNibPath:(id) path parameters:(id) params shell:(id) shell is
		(super init)
		(set @windows (NSMutableArray array))
		(set @shellCommand shell)
		(set @parameters params)
		(@parameters setObject:self forKey:"controller")
		(set url (NSURL fileURLWithPath:path))
		(set nib ((NSNib alloc) initWithContentsOfURL:url))
		(set topLevelObjects ((NuReference alloc) init))
		(nib instantiateNibWithOwner:self topLevelObjects:topLevelObjects)
		((topLevelObjects value) each: (do (w)
			(if (w isKindOfClass:(NSWindow class))
				(@windows addObject:w)
				(w setDelegate:self)
				(w makeKeyAndOrderFront:nil))))
		self)

	(imethod (void) windowWillClose:(id) notification is
		(let (w (notification object))
			(w setDelegate:nil)
			(@windows removeObject:w)
			(if (eq (@windows count) 0)
				(@shellCommand exit)
				(set @shellCommand nil))))

	(imethod (void) returnArgument:(id) argument is
		(@windows each: (do (w)
			(w setDelegate:nil)
			(w performClose:nil)))
		(@parameters setObject:argument forKey:"result")
		(@parameters removeObjectForKey:"controller")
		(@shellCommand exitWithObject:@parameters)))

(unless (defined? shellCommand)
	(set shellCommand nil))

((NSApplication sharedApplication) activateIgnoringOtherApps:YES)
((ShellNibOwner alloc) initWithNibPath:nibFile parameters:params shell:shellCommand)
