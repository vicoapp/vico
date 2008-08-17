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
	NSString *method;
	NSArray *arguments;
}

- (ExCommand *)initWithString:(NSString *)string;

@property(readonly) NSString *command;
@property(readonly) NSString *method;
@property(readonly) NSArray *arguments;

@end
