//
//  TestExCommand.m
//  vizard
//
//  Created by Martin Hedenfalk on 2008-03-29.
//  Copyright 2008 Martin Hedenfalk. All rights reserved.
//

#import "TestExCommand.h"
#import "ExCommand.h"


@implementation TestExCommand

- (void)test010_SetCommand
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"w"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects([ex command], @"write", nil);
	STAssertEqualObjects([ex method], @"ex_write", nil);
}

- (void)test011_NonexistentSimpleCommand
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"foo bar baz"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.command, @"foo", nil);
	STAssertNil(ex.method, nil);
}

- (void)test012_SimpleCommandWithSimpleParameter
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"edit /path/to/file.txt"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.command, @"edit", nil);
	STAssertEqualObjects(ex.method, @"ex_edit", nil);
	STAssertNotNil(ex.arguments, nil);
	STAssertTrue([ex.arguments count] == 1, nil);
	STAssertEqualObjects([ex.arguments objectAtIndex:0], @"/path/to/file.txt", nil);
}

@end
