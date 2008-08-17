#import <Cocoa/Cocoa.h>

@interface ProjectDelegate : NSObject
{
	IBOutlet NSWindow *window;
	
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	NSManagedObjectModel *managedObjectModel;
	NSManagedObjectContext *managedObjectContext;
	
	IBOutlet NSOutlineView *outlineView;
	IBOutlet NSTreeController *treeController;	
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

@end
