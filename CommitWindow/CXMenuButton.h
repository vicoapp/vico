//
//  CXMenuButton.h
//
//  Created by Chris Thomas on 2006-10-09.
//  Copyright 2006 Chris Thomas. All rights reserved.
//  MIT license.
//

@interface CXMenuButton : NSButton
{
	IBOutlet NSMenu *		menu;
}

- (NSMenu *)menu;
- (void)setMenu:(NSMenu *)aValue;


@end
