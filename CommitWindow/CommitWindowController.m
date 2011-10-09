//
//  CommitWindowController.m
//
//  Created by Chris Thomas on 2/6/05.
//  Copyright 2005-2007 Chris Thomas. All rights reserved.
//	MIT license.
//

#import "CommitWindowController.h"
#import "CXMenuButton.h"
#import "CWTextView.h"

#import "CXTextWithButtonStripCell.h"
#import "NSString+StatusString.h"
#import "NSTask+CXAdditions.h"

#define kStatusColumnWidthForSingleChar	13
#define kStatusColumnWidthForPadding	13

@interface CommitWindowController (Private)
- (void) populatePreviousSummaryMenu;
- (void) windowDidResize:(NSNotification *)notification;
- (void) summaryScrollViewDidResize:(NSNotification *)notification;
@end

// Forward string comparisons to NSString
@interface NSAttributedString (CommitWindowExtensions)
- (NSComparisonResult)compare:(id)anArgument;
@end

@implementation NSAttributedString (CommitWindowExtensions)
- (NSComparisonResult)compare:(id)aString
{
	return [[self string] compare:[aString string]];
}
@end


@implementation CommitWindowController

// Not necessary while CommitWindow is a separate process, but it might be more integrated in the future.
- (void) dealloc
{
	// TODO: make sure the nib objects are being released properly
	
	[fDiffCommand release];
	[fActionCommands release];
	[fFileStatusStrings release];
	
	[super dealloc];
}

// Add a command to the array of commands available for the given status substring
- (void) addAction:(NSString *)name command:(NSArray *)arguments forStatus:(NSString *)statusString
{
	NSArray *			commandArguments = [NSArray arrayWithObjects:name, arguments, nil];
	NSMutableArray *	commandsForAction = nil;
	
	if(fActionCommands == nil)
	{
		fActionCommands = [[NSMutableDictionary alloc] init];
	}
	else
	{
		commandsForAction = [fActionCommands objectForKey:statusString];
	}
	
	if(commandsForAction == nil)
	{
		commandsForAction = [NSMutableArray array];
		[fActionCommands setObject:commandsForAction forKey:statusString];
	}
	
	[commandsForAction addObject:commandArguments];
}

- (BOOL)standardChosenStateForStatus:(NSString *)status
{
	BOOL	chosen = YES;

	// Deselect external commits and files not added by default
	// We intentionally do not deselect file conflicts by default
	// -- those are most likely to be a problem.

	if(	[status hasPrefix:@"X"]
	 ||	[status hasPrefix:@"?"])
	{
		chosen = NO;
	}
	
	return chosen;
}

// fFilesController and fFilesStatusStrings should be set up before calling setupUserInterface.
- (void) setupUserInterface
{
	CXTextWithButtonStripCell *		cell = (CXTextWithButtonStripCell *)[fPathColumn dataCell];
	
	if([cell respondsToSelector:@selector(setLineBreakMode:)])
	{
		[cell setLineBreakMode:NSLineBreakByTruncatingHead];		
	}

	//
	// Set up button strip
	//
	NSMutableArray *		buttonDefinitions = [NSMutableArray array];
	
	//	Diff command
	if( fDiffCommand != nil )
	{
		NSMutableDictionary *	diffButtonDefinition;
		NSMethodSignature *		diffMethodSignature	= [self methodSignatureForSelector:@selector(doubleClickRowInTable:)];
		NSInvocation *			diffInvocation		= [NSInvocation invocationWithMethodSignature:diffMethodSignature];
		
		// Arguments 0 and 1
		[diffInvocation setTarget:self];
		[diffInvocation setSelector:@selector(doubleClickRowInTable:)];
		
		// Pretend the table view is the sender
		[diffInvocation setArgument:&fTableView atIndex:2];

		diffButtonDefinition = [NSMutableDictionary dictionary];
		[diffButtonDefinition setObject:@"Diff" forKey:@"title"];
		[diffButtonDefinition setObject:diffInvocation forKey:@"invocation"];

		[buttonDefinitions addObject:diffButtonDefinition];
	}

	// Action menu
	if(fActionCommands != nil)
	{
	 	NSMenu *						itemActionMenu;
		NSMutableDictionary *			actionMenuButtonDefinition;

		itemActionMenu = [[NSMenu alloc] initWithTitle:@"Test"];
		[itemActionMenu setDelegate:self];
		
		actionMenuButtonDefinition = [NSMutableDictionary dictionaryWithObject:itemActionMenu forKey:@"menu"];
		[actionMenuButtonDefinition setObject:@"Modify" forKey:@"title"];

		[buttonDefinitions addObject:actionMenuButtonDefinition];
		
		[itemActionMenu release];
	}
	
	if( [buttonDefinitions count] > 0 )
	{
		[cell setButtonDefinitions:buttonDefinitions];
	}
	
	//
	// Set up summary text view resizing
	//
	[self windowDidResize:nil];
	
	fPreviousSummaryFrame = [fSummaryScrollView frame];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(summaryScrollViewDidResize:)
		name:NSViewFrameDidChangeNotification
		object:fSummaryScrollView];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(windowDidResize:)
		name:NSWindowDidResizeNotification
		object:fWindow];
		
	//
	// Add status to each item and choose default commit state
	//
	if( fFileStatusStrings != nil )
	{
		NSArray *	files = [fFilesController arrangedObjects];
		int			count = MIN([files count], [fFileStatusStrings count]);
		int			i;
		
		UInt32		maxCharsToDisplay = 0;
		
		for( i = 0; i < count; i += 1 )
		{
			NSMutableDictionary *	dictionary	= [files objectAtIndex:i];
			NSString *				status		= [fFileStatusStrings objectAtIndex:i];
			BOOL					itemSelectedForCommit;
			UInt32					statusLength;
			
			// Set high-water mark
			statusLength = [status length];
			if( statusLength > maxCharsToDisplay )
			{
				maxCharsToDisplay = statusLength;
			}
			
			[dictionary setObject:status forKey:@"status"];
			[dictionary setObject:[status attributedStatusString] forKey:@"attributedStatus"];

			itemSelectedForCommit = [self standardChosenStateForStatus:status];
			[dictionary setObject:[NSNumber numberWithBool:itemSelectedForCommit] forKey:@"commit"]; 
		}

		// Set status column size
		[fStatusColumn setWidth:12 + maxCharsToDisplay * kStatusColumnWidthForSingleChar + (maxCharsToDisplay-1) * kStatusColumnWidthForPadding];
	}
	
	//
	// Populate previous summary menu
	//
	[self populatePreviousSummaryMenu];

	[fTableView setTarget:self];
	[fTableView setDoubleAction:@selector(doubleClickRowInTable:)];

	//
	// Map the enter key to the OK button
	//
	[fOKButton setKeyEquivalent:@"\x03"];
	[fOKButton setKeyEquivalentModifierMask:0];

	//
	// Bring the window to absolute front.
	// -[NSWindow orderFrontRegardless] doesn't work (maybe because we're an LSUIElement).
	//
	
	// Process Manager works, though!
	{
		ProcessSerialNumber process;
	
		GetCurrentProcess(&process);
		SetFrontProcess(&process);
	}
	
	
	[self setWindow:fWindow];
	[fWindow setLevel:NSModalPanelWindowLevel];
	[fWindow center];
	
	//
	// Grow the window to fit as much of the file list onscreen as possible
	//
	{
		NSScreen *		screen		= [fWindow screen];
		NSRect			usableRect	= [screen visibleFrame];
		NSRect			windowRect	= [fWindow frame];
		NSTableView *	tableView	= [fPathColumn tableView];
		float			rowHeight	= [tableView rowHeight] + [tableView intercellSpacing].height;
		int				rowCount	= [[fFilesController arrangedObjects] count];
		float			idealVisibleHeight;
		float			currentVisibleHeight;
		float			deltaVisibleHeight;
		
		currentVisibleHeight	= [[tableView superview] frame].size.height;
		idealVisibleHeight		= (rowHeight * rowCount) + [[tableView headerView] frame].size.height;
		
//		NSLog(@"current: %g ideal:%g", currentVisibleHeight, idealVisibleHeight );
		
		// Don't bother shrinking the window
		if(currentVisibleHeight < idealVisibleHeight)
		{
			deltaVisibleHeight = (idealVisibleHeight - currentVisibleHeight);

//			NSLog( @"old windowRect: %@", NSStringFromRect(windowRect) );

			// reasonable margin
			usableRect = NSInsetRect( usableRect, 20, 20 );
			windowRect = NSIntersectionRect(usableRect, NSInsetRect(windowRect, 0, ceilf(0.5f * -deltaVisibleHeight)));
			
//			NSLog( @"new windowRect: %@", NSStringFromRect(windowRect) );
			
			[fWindow setFrame:windowRect display:NO];
		}
	}
	
	// center again after resize
	[fWindow center];
	[fWindow makeKeyAndOrderFront:self];
	
}

- (void) resetStatusColumnSize
{
	//
	// Add status to each item and choose default commit state
	//
	NSArray *	files = [fFilesController arrangedObjects];
	int			count = [files count];
	int			i;
	
	UInt32		maxCharsToDisplay = 0;
	
	for( i = 0; i < count; i += 1 )
	{
		NSMutableDictionary *	dictionary	= [files objectAtIndex:i];
		NSString *				status		= [dictionary objectForKey:@"status"];
		UInt32					statusLength;
		
		// Set high-water mark
		statusLength = [status length];
		if( statusLength > maxCharsToDisplay )
		{
			maxCharsToDisplay = statusLength;
		}
	}

	// Set status column size
	[fStatusColumn setWidth:12 + maxCharsToDisplay * kStatusColumnWidthForSingleChar + (maxCharsToDisplay-1) * kStatusColumnWidthForPadding];
}

#if 0
#pragma mark -
#pragma mark Summary save/restore
#endif

#define kMaxSavedSummariesCount					5
#define kDisplayCharsOfSummaryInMenuItemCount	30
#define kPreviousSummariesKey					"prev-summaries"
#define kPreviousSummariesItemTitle				"Previous Summaries"

- (void) populatePreviousSummaryMenu
{
	NSUserDefaults *  	defaults		= [NSUserDefaults standardUserDefaults];
	NSArray *			summaries		= [defaults arrayForKey:@kPreviousSummariesKey];
	
	if( summaries == nil )
	{
		// No previous summaries, no menu
		[fPreviousSummaryPopUp setEnabled:NO];
	}
	else
	{
		NSMenu *			menu = [[NSMenu alloc] initWithTitle:@kPreviousSummariesItemTitle];
		NSMenuItem *		item;

		int	summaryCount = [summaries count];
		int	index;

		// PopUp title
		[menu addItemWithTitle:@kPreviousSummariesItemTitle action:@selector(restoreSummary:) keyEquivalent:@""];
		
		// Add items in reverse-chronological order
		for(index = (summaryCount - 1); index >= 0; index -= 1)
		{
			NSString *	summary = [summaries objectAtIndex:index];
			NSString *	itemName;
			
			itemName = summary;
			
			// Limit length of menu item names
			if( [itemName length] > kDisplayCharsOfSummaryInMenuItemCount )
			{
				itemName = [itemName substringToIndex:kDisplayCharsOfSummaryInMenuItemCount];
				
				// append ellipsis
				itemName = [itemName stringByAppendingFormat: @"%C", 0x2026];
			}

			item = [menu addItemWithTitle:itemName action:@selector(restoreSummary:) keyEquivalent:@""];
			[item setTarget:self];
			
			[item setRepresentedObject:summary];
		}

		[fPreviousSummaryPopUp setMenu:menu];
	}
}

// To make redo work, we need to add a new undo each time
- (void) restoreTextForUndo:(NSString *)newSummary
{
	NSUndoManager *	undoManager = [[fCommitMessage window] undoManager];
    NSString *		oldSummary = [fCommitMessage string];
    
    [undoManager registerUndoWithTarget:self
                                            selector:@selector(restoreTextForUndo:)
                                            object:[[oldSummary copy] autorelease]];

	[fCommitMessage setString:newSummary];

}

- (void) restoreSummary:(id)sender
{
	NSString *		newSummary = [sender representedObject];
	
	[self restoreTextForUndo:newSummary];
}

// Save, in a MRU list, the most recent commit summary
- (void) saveSummary
{
	NSUserDefaults *  	defaults		= [NSUserDefaults standardUserDefaults];
	NSString *			latestSummary	= [fCommitMessage string];
	
	// avoid empty string
	if( ! [latestSummary isEqualToString:@""] )
	{
		NSArray *			oldSummaries = [defaults arrayForKey:@kPreviousSummariesKey];
		NSMutableArray *	newSummaries;

		if( oldSummaries != nil )
		{
			NSUInteger	oldIndex;
			
			newSummaries = [oldSummaries mutableCopy];
			
			// Already in the array? Move it to latest position
			oldIndex = [newSummaries indexOfObject:latestSummary];
			if( oldIndex != NSNotFound )
			{
				[newSummaries exchangeObjectAtIndex:oldIndex withObjectAtIndex:[newSummaries count] - 1];
			}
			else
			{
				// Add object, remove oldest object
				[newSummaries addObject:latestSummary];
				if( [newSummaries count] > kMaxSavedSummariesCount )
				{
					[newSummaries removeObjectAtIndex:0];
				}
			}
		}
		else
		{
			// First time
			newSummaries = [NSMutableArray arrayWithObject:latestSummary];
		}

		[defaults setObject:newSummaries forKey:@kPreviousSummariesKey];

		// Write the defaults to disk
		[defaults synchronize];
	}
}

#if 0
#pragma mark -
#pragma mark File action menu
#endif



- (void) chooseAllItems:(BOOL)chosen
{
	NSArray *	files = [fFilesController arrangedObjects];
	int			count = [files count];
	int			i;
	
	for( i = 0; i < count; i += 1 )
	{
		NSMutableDictionary *	dictionary	= [files objectAtIndex:i];

		[dictionary setObject:[NSNumber numberWithBool:chosen] forKey:@"commit"]; 
	}
}

- (void) choose:(BOOL)chosen itemsWithStatus:(NSString *)status
{
	NSArray *	files = [fFilesController arrangedObjects];
	int			count = [files count];
	int			i;
	
	for( i = 0; i < count; i += 1 )
	{
		NSMutableDictionary *	dictionary	= [files objectAtIndex:i];
		
		if( [[dictionary objectForKey:@"status"] hasPrefix:status] )
		{
			[dictionary setObject:[NSNumber numberWithBool:chosen] forKey:@"commit"]; 
		}
	}
}

- (IBAction) chooseAllFiles:(id)sender
{
	[self chooseAllItems:YES];
}

- (IBAction) chooseNoFiles:(id)sender
{
	[self chooseAllItems:NO];
}

- (IBAction) revertToStandardChosenState:(id)sender
{
	NSArray *	files = [fFilesController arrangedObjects];
	int			count = [files count];
	int			i;
	
	for( i = 0; i < count; i += 1 )
	{
		NSMutableDictionary *	dictionary	= [files objectAtIndex:i];
		BOOL					itemChosen = YES;
		NSString *				status = [dictionary objectForKey:@"status"];

		itemChosen = [self standardChosenStateForStatus:status];
		[dictionary setObject:[NSNumber numberWithBool:itemChosen] forKey:@"commit"]; 
	}
}

#if 0
#pragma mark -
#pragma mark Summary view resize
#endif

- (void) summaryScrollViewDidResize:(NSNotification *)notification
{
	// Adjust the size of the lower controls
	NSRect	currentSummaryFrame			= [fSummaryScrollView frame];
	NSRect	currentLowerControlsFrame	= [fLowerControlsView frame];

	float	deltaV = currentSummaryFrame.size.height - fPreviousSummaryFrame.size.height;
	
	[fLowerControlsView setNeedsDisplayInRect:[fLowerControlsView bounds]];
	
	currentLowerControlsFrame.size.height	-= deltaV;
	
	[fLowerControlsView setFrame:currentLowerControlsFrame];
	
	fPreviousSummaryFrame = currentSummaryFrame;
}

- (void) windowDidResize:(NSNotification *)notification
{
	// Adjust max allowed summary size to 60% of window size
	[fCommitMessage setMaxHeight:[fWindow frame].size.height * 0.60];
}

#if 0
#pragma mark -
#pragma mark Command utilities
#endif

- (NSString *) absolutePathForPath:(NSString *)path
{
	if([path hasPrefix:@"/"])
		return path;

	NSString *			absolutePath = nil;
	NSString *			errorText;
	int					exitStatus;
	NSArray *			arguments = [NSArray arrayWithObjects:@"/usr/bin/which", path, nil];

	exitStatus = [NSTask executeTaskWithArguments:arguments
		    					input:nil
		                        outputString:&absolutePath
		                        errorString:&errorText];
	
	[self checkExitStatus:exitStatus forCommand:arguments errorText:errorText];

	// Trim whitespace
	absolutePath = [absolutePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	return absolutePath;
}

- (void) checkExitStatus:(int)exitStatus forCommand:(NSArray *)arguments errorText:(NSString *)errorText
{
	if( exitStatus != 0 )
	{
		// This error dialog text sucks for an isolated end user, but allows us to diagnose the problem accurately.
		NSRunAlertPanel(errorText, @"Exit status (%d) while executing %@", @"OK", nil, nil, exitStatus, arguments);
		[NSException raise:@"ProcessFailed" format:@"Subprocess %@ unsuccessful.", arguments];
	}	
}


#if 0
#pragma mark -
#pragma mark ButtonStrip action menu delegate
#endif

- (void)chooseActionCommand:(id)sender
{
	NSMutableArray *		arguments		= [[sender representedObject] mutableCopy];
	NSString *				pathToCommand;
	NSMutableDictionary *	fileDictionary	= [[fFilesController arrangedObjects] objectAtIndex:[fTableView selectedRow]];
	NSString *				filePath		= [[fileDictionary objectForKey:@"path"] stringByStandardizingPath];
	NSString *				errorText;
	NSString *				outputStatus;
	int						exitStatus;
	
	// make sure we have an absolute path
	pathToCommand = [self absolutePathForPath:[arguments objectAtIndex:0]];
	[arguments replaceObjectAtIndex:0 withObject:pathToCommand];
	
	[arguments addObject:filePath];
	
	exitStatus = [NSTask executeTaskWithArguments:arguments
		    					input:nil
		                        outputString:&outputStatus
		                        errorString:&errorText];
	[self checkExitStatus:exitStatus forCommand:arguments errorText:errorText];
	
	//
	// Set the file status to the new status
	//
	NSRange		rangeOfStatus;
	NSString *	newStatus;
	
	rangeOfStatus = [outputStatus rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if( rangeOfStatus.location == NSNotFound)
	{
		NSRunAlertPanel(@"Cannot understand output from command", @"Command %@ returned '%@'", @"OK", nil, nil, arguments, outputStatus);
		[NSException raise:@"CannotUnderstandReturnValue" format:@"Don't understand %@", outputStatus];
	}
	
	newStatus = [outputStatus substringToIndex:rangeOfStatus.location];

	[fileDictionary setObject:newStatus forKey:@"status"];
	[fileDictionary setObject:[newStatus attributedStatusString] forKey:@"attributedStatus"];
	[fileDictionary setObject:[NSNumber numberWithBool:[self standardChosenStateForStatus:newStatus]] forKey:@"commit"];
	
	[self resetStatusColumnSize];
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	//
	// Remove old items
	//
	UInt32 itemCount = [menu numberOfItems];
	for( UInt32 i = 0; i < itemCount; i += 1 )
	{
		[menu removeItemAtIndex:0];
	}
	
	//
	// Find action items usable for the selected row
	//
	NSArray *		keys = [fActionCommands allKeys];
	NSString *		fileStatus	= [[[fFilesController arrangedObjects] objectAtIndex:[fTableView selectedRow]] objectForKey:@"status"];

	unsigned int	possibleStatusCount = [keys count];

	for(unsigned int index = 0; index < possibleStatusCount; index += 1)
	{
		NSString *	possibleStatus = [keys objectAtIndex:index];

		if( [fileStatus rangeOfString:possibleStatus].location != NSNotFound )
		{	
			// Add all the commands we find for this status
			NSArray *		commands		= [fActionCommands objectForKey:possibleStatus];
			unsigned int	commandCount	= [commands count];

			for(unsigned int arrayOfCommandsIndex = 0; arrayOfCommandsIndex < commandCount; arrayOfCommandsIndex += 1)
			{
				NSArray *	commandArguments = [commands objectAtIndex:arrayOfCommandsIndex];

				NSMenuItem *	item = [menu addItemWithTitle:[commandArguments objectAtIndex:0]
												action:@selector(chooseActionCommand:)
												keyEquivalent:@""];
				
				[item setRepresentedObject:[commandArguments objectAtIndex:1]];
				[item setTarget:self];
			}
		}
	}
}

@end
