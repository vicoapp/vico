/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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

@interface ViPreferencePaneBundles : ViPreferencePane <NSURLConnectionDelegate>
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
	NSURL				*_repoURL;
	int				_repoPage;
	NSURLConnection			*_repoConnection;
	NSMutableData			*_repoData;
	NSMutableArray			*_repoJson;


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

