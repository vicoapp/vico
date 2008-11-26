#import "ProjectDelegate.h"
#import "logging.h"

@implementation ProjectDelegate

@synthesize projectName;

/**
 Returns the support folder for the application, used to store the Core Data
 store file.  This code uses a folder named "Apa" for
 the content, either in the NSApplicationSupportDirectory location or (if the
 former cannot be found), the system's temporary directory.
 */

- (NSString *)applicationSupportFolder
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	return [basePath stringByAppendingPathComponent:@"xi"];
}


/**
 Creates, retains, and returns the managed object model for the application 
 by merging all of the models found in the application bundle.
 */

- (NSManagedObjectModel *)managedObjectModel
{
	if (managedObjectModel != nil)
	{
		return managedObjectModel;
	}
	
	managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
	return managedObjectModel;
}


/**
 Returns the persistent store coordinator for the application.  This 
 implementation will create and return a coordinator, having added the 
 store for the application to it.  (The folder for the store is created, 
 if necessary.)
 */

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
	if (persistentStoreCoordinator != nil)
	{
		return persistentStoreCoordinator;
	}
	
	NSFileManager *fileManager;
	NSString *applicationSupportFolder = nil;
	NSURL *url;
	NSError *error;
	
	fileManager = [NSFileManager defaultManager];
	applicationSupportFolder = [self applicationSupportFolder];
	if ( ![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL] )
	{
		[fileManager createDirectoryAtPath:applicationSupportFolder attributes:nil];
	}

	url = [NSURL fileURLWithPath:[applicationSupportFolder stringByAppendingPathComponent: @"project.xml"]];
	persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
	if (![persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error])
	{
		[[NSApplication sharedApplication] presentError:error];
	}    
	
	return persistentStoreCoordinator;
}


/**
 Returns the managed object context for the application (which is already
 bound to the persistent store coordinator for the application.) 
 */

- (NSManagedObjectContext *)managedObjectContext
{
	if (managedObjectContext != nil)
	{
		return managedObjectContext;
	}
	
	NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	if (coordinator != nil)
	{
		managedObjectContext = [[NSManagedObjectContext alloc] init];
		[managedObjectContext setPersistentStoreCoordinator:coordinator];
	}
	
	return managedObjectContext;
}

#if 0
/**
 Returns the NSUndoManager for the application.  In this case, the manager
 returned is that of the managed object context for the application.
 */

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
	return [[self managedObjectContext] undoManager];
}
#endif

/**
 Performs the save action for the application, which is to send the save:
 message to the application's managed object context.  Any encountered errors
 are presented to the user.
 */

- (IBAction)saveProject:(id)sender
{
	INFO(@"saving project, sender = %@", sender);
	NSError *error = nil;
	if (![[self managedObjectContext] save:&error])
	{
		[[NSApplication sharedApplication] presentError:error];
	}
}

#if 0
/**
 Implementation of the applicationShouldTerminate: method, used here to
 handle the saving of changes in the application managed object context
 before the application terminates.
 */

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	NSError *error;
	int reply = NSTerminateNow;
	
	if (managedObjectContext != nil)
	{
		if ([managedObjectContext commitEditing])
		{
			if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error])
			{
				
				// This error handling simply presents error information in a panel with an 
				// "Ok" button, which does not include any attempt at error recovery (meaning, 
				// attempting to fix the error.)  As a result, this implementation will 
				// present the information to the user and then follow up with a panel asking 
				// if the user wishes to "Quit Anyway", without saving the changes.
				
				// Typically, this process should be altered to include application-specific 
				// recovery steps.  
				
				BOOL errorResult = [[NSApplication sharedApplication] presentError:error];
				
				if (errorResult == YES)
				{
					reply = NSTerminateCancel;
				} 
				
				else
				{
					int alertReturn = NSRunAlertPanel(nil, @"Could not save changes while quitting. Quit anyway?" , @"Quit anyway", @"Cancel", nil);
					if (alertReturn == NSAlertAlternateReturn)
					{
						reply = NSTerminateCancel;
					}
				}
			}
		} 
		else
		{
			reply = NSTerminateCancel;
		}
	}
	
	return reply;
}
#endif

#pragma mark Code Added for AbstractTree Drag and Drop

/*
    Up to this point, the code in this file is generated when you select an Xcode project 
    of type Cocoa Core Data Application. The methods below are implemented to support 
    drag and drop. For general information on drag and drop in Cocoa, go to 
    http://developer.apple.com/documentation/Cocoa/Conceptual/DragandDrop/DragandDrop.html
    Outline views have their own API for drag and drop within the NSOutlineViewDataSource
    informal protocol. Reference for that protocol can be found at
    http://developer.apple.com/documentation/Cocoa/Reference/ApplicationKit/Protocols/NSOutlineViewDataSource_Protocol/Reference/Reference.html
*/

// Declare a string constant for the drag type - to be used when writing and retrieving pasteboard data...
NSString *AbstractTreeNodeType = @"AbstractTreeNodeType";

/*
    Run time setup.
*/
- (void)awakeFromNib
{
    // Set the outline view to accept the custom drag type AbstractTreeNodeType...
    [outlineView registerForDraggedTypes:[NSArray arrayWithObject:AbstractTreeNodeType]];
}

/*
    Beginning the drag from the outline view.
*/
- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
    // Tell the pasteboard what kind of data we'll be placing on it
    [pboard declareTypes:[NSArray arrayWithObject:AbstractTreeNodeType] owner:self];
    // Query the NSTreeNode (not the underlying Core Data object) for its index path under the tree controller.
    NSIndexPath *pathToDraggedNode = [[items objectAtIndex:0] indexPath];
    // Place the index path on the pasteboard.
    NSData *indexPathData = [NSKeyedArchiver archivedDataWithRootObject:pathToDraggedNode];
    [pboard setData:indexPathData forType:AbstractTreeNodeType];
    // Return YES so that the drag actually begins...
    return YES;
}

/*
    Performing a drop in the outline view. This allows the user to manipulate the structure of the tree by moving subtrees under new parent nodes.
*/
- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)anIndex
{
    // Retrieve the index path from the pasteboard.
    NSIndexPath *droppedIndexPath = [NSKeyedUnarchiver unarchiveObjectWithData:[[info draggingPasteboard] dataForType:AbstractTreeNodeType]];
    // We need to find the NSTreeNode positioned at the index path. We start by getting the root node of the tree.
    // In NSTreeController, arrangedObjects returns the root node of the tree.
    id treeRoot = [treeController arrangedObjects];
    // Find the node being moved by querying the root node. NSTreeNode is a 10.5 API.
    NSTreeNode *node = [treeRoot descendantNodeAtIndexPath:droppedIndexPath];
    // Use the tree controller to move the node. This will manage any changes necessary in the parent-child relationship.
    // modeNode:toIndex:Path is a 10.5 API addition to NSTreeController.
    [treeController moveNode:node toIndexPath:[[item indexPath] indexPathByAddingIndex:0]];
    // Return YES so that the user gets visual feedback that the drag was successful...
    return YES;
}

/*
    Validating a drop in the outline view.
*/
- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)anIndex
{
    // The index indicates whether the drop would take place directly on an item or between two items. 
    // Between items implies that sibling ordering is supported (it's not in this application),
    // so we only indicate a valid operation if the drop is directly over (index == -1) an item.
    return (anIndex == -1) ? NSDragOperationGeneric : NSDragOperationNone;
}

@end
