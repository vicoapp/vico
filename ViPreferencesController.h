#import "ViRegexp.h"

@interface statusIconTransformer : NSValueTransformer
{
	NSImage *installedIcon;
}
@end

@interface ViPreferencesController : NSWindowController
{
	NSView *blankView;
	NSString *forceSwitchToItem;
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
	IBOutlet NSButton *progressButton;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSTextField *progressDescription;
	IBOutlet NSSearchField *repoFilterField;
#if 0
	IBOutlet NSPopUpButton *insertModeInputSources;
	IBOutlet NSPopUpButton *normalModeInputSources;
#endif
	long long receivedContentLength;
	BOOL progressCancelled;
	NSMutableArray *processQueue;

	ViRegexp *repoNameRx;
	NSMutableArray *repositories;
	NSArray *filteredRepositories;
	NSArray *previousRepoUsers;
	NSURLDownload *repoDownload;

	NSTask *installTask;
	NSPipe *installPipe;
	NSURLConnection *installConnection;
}

+ (ViPreferencesController *)sharedPreferences;
- (IBAction)switchToItem:(id)sender;
- (IBAction)selectFont:(id)sender;

- (IBAction)filterRepositories:(id)sender;
- (IBAction)reloadRepositories:(id)sender;
- (IBAction)cancelProgressSheet:(id)sender;

- (IBAction)installBundles:(id)sender;
- (IBAction)uninstallBundles:(id)sender;

- (IBAction)acceptSelectRepoSheet:(id)sender;
- (IBAction)selectRepositories:(id)sender;
- (IBAction)addRepoUser:(id)sender;

- (void)show;
- (void)showItem:(NSString *)item;
- (void)reloadNextUser;
- (void)setFilteredRepositories:(NSArray *)anArray;
- (void)installNextBundle;
- (void)setSelectedFont;
- (void)reloadRepositoriesFromUsers:(NSArray *)users;

@end
