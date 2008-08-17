//
//  ViTagStack.h
//  vizard
//
//  Created by Martin Hedenfalk on 2008-04-06.
//  Copyright 2008 Martin Hedenfalk. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ViTagStack : NSObject
{
	NSMutableArray *stack;
}

- (void)pushFile:(NSString *)aFile line:(NSUInteger)aLine column:(NSUInteger)aColumn;
- (NSDictionary *)pop;

@end
