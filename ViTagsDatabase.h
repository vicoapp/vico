//
//  ViTagsDatabase.h
//  vizard
//
//  Created by Martin Hedenfalk on 2008-03-31.
//  Copyright 2008 Martin Hedenfalk. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ViTagsDatabase : NSObject
{
	NSMutableDictionary *tags;
	NSString *prefixPath;
}

- (ViTagsDatabase *)initWithFile:(NSString *)aFile inDirectory:(NSString *)aDirectory;
- (NSArray *)lookup:(NSString *)symbol;

@end
