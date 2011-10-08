#import "ViPreferencePane.h"

@interface repoUserTransformer : NSValueTransformer
{
}
@end

@interface statusIconTransformer : NSValueTransformer
{
	NSImage	*_installedIcon;
}
@end

@interface ViPreferencePaneBundles : ViPreferencePane <NSURLDownloadDelegate>
{
	IBOutlet NSTextField		*bundlesInfo;
	IBOutlet NSArrayController	*bundlesController;
	IBOutlet NSArrayController	*repoUsersController;
	IBOutlet NSTableView		*bundlesTable;
	IBOutlet NSTableView		*repoUsersTable;
	IBOutlet NSWindow		*selectRepoSheet;
	IBOutlet NSWindow		*progressSheet;
	IBOutlet NSButton		*progressButton;
	IBOutlet NSProgressIndicator	*progressIndicator;
	IBOutlet NSTextField		*progressDescription;
	IBOutlet NSSearchField		*repoFilterField;

	long long			 _receivedContentLength;
	BOOL				 _progressCancelled;
	NSMutableArray			*_processQueue;

	ViRegexp			*_repoNameRx;
	NSMutableArray			*_repositories;
	NSArray				*_filteredRepositories;
	NSArray				*_previousRepoUsers;
	NSURLDownload			*_repoDownload;

	NSURLConnection			*_userConnection;
	NSMutableData			*_userData;

	NSTask				*_installTask;
	NSPipe				*_installPipe;
	NSURLConnection			*_installConnection;
}

@property (nonatomic,readwrite,retain) NSArray *filteredRepositories;

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

