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

#import "ViTextView.h"
#import "Nu.h"
#import <Carbon/Carbon.h>

@interface NuParser (fix)
- (void)close;
@end

@class ViRegexp;

@protocol ViShellThingProtocol <NSObject>

- (void)exit;
- (void)exitWithObject:(id)obj;
- (void)exitWithError:(int)code;
- (void)log:(NSString *)message;

@end

@protocol ViShellCommandProtocol <NSObject>

- (id)eval:(NSString *)script
     error:(NSError **)outError;
- (NSString *)eval:(NSString *)script
additionalBindings:(NSDictionary *)bindings
       errorString:(NSString **)errorString
       backChannel:(NSString *)channelName;
- (NSError *)openURL:(NSString *)pathOrURL
             andWait:(BOOL)waitFlag
         backChannel:(NSString *)channelName;
- (void)setStartupBasePath:(NSString *)basePath;
- (NSError *)openURL:(NSString *)pathOrURL;
- (NSError *)newDocumentWithData:(NSData *)data
                         andWait:(BOOL)waitFlag
                     backChannel:(NSString *)channelName;
- (NSError *)newDocumentWithData:(NSData *)data;
- (IBAction)newProject:(id)sender;

@end

@interface ViAppController : NSObject <ViShellCommandProtocol, NSTextViewDelegate>
{
	IBOutlet NSMenu		*encodingMenu;
	IBOutlet NSMenu		*viewMenu;
	IBOutlet NSTextField	*scriptInput;
	IBOutlet NSTextView	*scriptOutput;
	IBOutlet NSMenuItem	*closeDocumentMenuItem;
	IBOutlet NSMenuItem	*closeWindowMenuItem;
	IBOutlet NSMenuItem	*closeTabMenuItem;
	IBOutlet NSMenuItem	*showFileExplorerMenuItem;
	IBOutlet NSMenuItem	*showSymbolListMenuItem;
	IBOutlet NSMenuItem	*checkForUpdatesMenuItem;
	NSConnection		*shellConn;

	TISInputSourceRef	 original_input_source;
	BOOL			 _recently_launched;
	NSWindow		*_menuTrackedKeyWindow;
	BOOL			 _trackingMainMenu;

	// input of scripted ex commands
	// XXX: in search of a better place (refugees from ExEnvironment)
	BOOL			 _busy;
	NSString		*_exString;
	ViTextStorage		*_fieldEditorStorage;
	ViTextView		*_fieldEditor;

	NuBlock			*_statusSetupBlock;
}

@property(nonatomic,readonly) NSMenu *encodingMenu;
@property(nonatomic,readonly) TISInputSourceRef original_input_source;

@property(retain,readwrite) NuBlock *statusSetupBlock;

- (id)eval:(NSString *)script
withParser:(NuParser *)parser
  bindings:(NSDictionary *)bindings
     error:(NSError **)outError;
- (id)eval:(NSString *)script
     error:(NSError **)outError;

+ (NSString *)supportDirectory;
- (IBAction)showPreferences:(id)sender;
- (IBAction)visitWebsite:(id)sender;
- (IBAction)editSiteScript:(id)sender;
- (IBAction)installTerminalHelper:(id)sender;
- (IBAction)showMarkInspector:(id)sender;

- (NSString *)getExStringForCommand:(ViCommand *)command prefix:(NSString *)prefix;
- (NSString *)getExStringForCommand:(ViCommand *)command;

- (NSWindow *)keyWindowBeforeMainMenuTracking;
- (void)forceUpdateMenu:(NSMenu *)menu;

@end
