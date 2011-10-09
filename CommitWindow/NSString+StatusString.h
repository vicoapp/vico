//
//  NSString+StatusString.h
//  CommitWindow
//
//  Created by Chris Thomas on 6/24/06.
//  Copyright 2006 Chris Thomas. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString(VersionControlStatusString)
- (NSAttributedString *) attributedStatusString;
@end
