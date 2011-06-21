#import "ViPreferencePane.h"

@interface repoUserTransformer : NSValueTransformer
{
}
@end

@interface statusIconTransformer : NSValueTransformer
{
	NSImage *installedIcon;
}
@end

@interface ViPreferencePaneBundles : ViPreferencePane
{
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

	long long receivedContentLength;
	BOOL progressCancelled;
	NSMutableArray *processQueue;

	ViRegexp *repoNameRx;
	NSMutableArray *repositories;
	NSArray *filteredRepositories;
	NSArray *previousRepoUsers;
	NSURLDownload *repoDownload;

	NSURLConnection *userConnection;
	NSMutableData *userData;

	NSTask *installTask;
	NSPipe *installPipe;
	NSURLConnection *installConnection;
}

- (IBAction)filterRepositories:(id)sender;
- (IBAction)reloadRepositories:(id)sender;
- (IBAction)cancelProgressSheet:(id)sender;

- (IBAction)installBundles:(id)sender;
- (IBAction)uninstallBundles:(id)sender;

- (IBAction)acceptSelectRepoSheet:(id)sender;
- (IBAction)selectRepositories:(id)sender;
- (IBAction)addRepoUser:(id)sender;

- (void)reloadNextUser;
- (void)loadBundlesFromRepo:(NSString *)username;
- (void)setFilteredRepositories:(NSArray *)anArray;
- (void)installNextBundle;
- (void)reloadRepositoriesFromUsers:(NSArray *)usersToLoad;

@end

