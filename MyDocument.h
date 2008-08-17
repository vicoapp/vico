//
//  MyDocument.h
//  vizard
//
//  Created by Martin Hedenfalk on 2007-12-01.
//  Copyright __MyCompanyName__ 2007 . All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "ViTextView.h"

@interface MyDocument : NSDocument
{
	IBOutlet ViTextView *textView;
	IBOutlet NSTextField *statusbar;
	NSString *readContent;
}
@end
