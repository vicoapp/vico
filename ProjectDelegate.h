#import <Cocoa/Cocoa.h>

extern NSString *AbstractTreeNodeType;

@interface ProjectDelegate : NSObject
{
	NSString *projectName;

	IBOutlet NSWindow *window;
	IBOutlet NSOutlineView *outlineView;
	IBOutlet NSTreeController *treeController;

	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	NSManagedObjectModel *managedObjectModel;
	NSManagedObjectContext *managedObjectContext;
}

@property(readwrite, copy) NSString *projectName;

- (IBAction)saveProject:(id)sender;

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

@end
