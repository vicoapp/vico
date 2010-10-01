#import <Cocoa/Cocoa.h>
#import "ViRegexp.h"

@interface statusIconTransformer : NSValueTransformer
{
	NSImage *installedIcon;
}
@end

@interface ViPreferencesController : NSWindowController
{
	NSView *blankView;
	IBOutlet NSView *generalView;
	IBOutlet NSView *editingView;
	IBOutlet NSView *fontsColorsView;
	IBOutlet NSView *bundlesView;
	IBOutlet NSPopUpButton *themeButton;
	IBOutlet NSTextField *currentFont;
	IBOutlet NSTextField *bundlesInfo;
	IBOutlet NSArrayController *bundlesController;
	IBOutlet NSArrayController *repoUsersController;
	IBOutlet NSTableView *bundlesTable;
	IBOutlet NSTableView *repoUsersTable;
	IBOutlet NSWindow *selectRepoSheet;
	IBOutlet NSWindow *progressSheet;
	IBOutlet NSProgressIndicator *bundleProgress;
	IBOutlet NSTextField *progressDescription;
	IBOutlet NSSearchField *repoFilterField;
#if 0
	IBOutlet NSPopUpButton *insertModeInputSources;
	IBOutlet NSPopUpButton *normalModeInputSources;
#endif
	ViRegexp *repoNameRx;
	NSMutableArray *repositories;
	NSArray *filteredRepositories;
	NSMutableDictionary *repoDownloads;
	NSMutableArray *bundlesToProcess;
	NSArray *previousRepoUsers;

	NSTask *installTask;
	NSPipe *installPipe;
	NSURLConnection *installConnection;
}

+ (ViPreferencesController *)sharedPreferences;
- (IBAction)switchToItem:(id)sender;
- (IBAction)selectFont:(id)sender;

- (IBAction)filterRepositories:(id)sender;
- (IBAction)reloadRepositories:(id)sender;
- (IBAction)cancelReloadRepositories:(id)sender;

- (IBAction)installBundles:(id)sender;
- (IBAction)uninstallBundles:(id)sender;

- (IBAction)acceptSelectRepoSheet:(id)sender;
- (IBAction)selectRepositories:(id)sender;
- (IBAction)addRepoUser:(id)sender;

- (void)show;
- (void)setFilteredRepositories:(NSArray *)anArray;
- (void)installNextBundle;
- (void)setSelectedFont;
- (void)reloadRepositoriesFromUsers:(NSArray *)users;

@end
