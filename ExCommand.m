//
//  ExCommand.m
//  vizard
//
//  Created by Martin Hedenfalk on 2008-03-17.
//  Copyright 2008 Martin Hedenfalk. All rights reserved.
//

#import "ExCommand.h"

@interface ExCommand (private)
- (void)parseString:(NSString *)string;
@end

@implementation ExCommand

@synthesize command;

- (ExCommand *)initWithString:(NSString *)string
{
	self = [super init];
	if(self)
	{
		[self parseString:string];
	}
	return self;
}

- (void)parseString:(NSString *)string
{
	command = [[string componentsSeparatedByString:@" "] objectAtIndex:0];
}

@end
