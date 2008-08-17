//
//  ExCommand.h
//  vizard
//
//  Created by Martin Hedenfalk on 2008-03-17.
//  Copyright 2008 Martin Hedenfalk. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ExCommand : NSObject
{
	NSString *command;
}

- (ExCommand *)initWithString:(NSString *)string;

@property(readonly) NSString *command;

@end
