//
//  CommitWindowCommandLine.h
//  CommitWindow
//
//  Created by Chris Thomas on 6/24/06.
//  Copyright 2006 Chris Thomas. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CommitWindowController.h"

@interface CommitWindowController(CommandLine)
- (IBAction) commit:(id) sender;
- (IBAction) cancel:(id) sender;
@end
