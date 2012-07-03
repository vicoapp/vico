/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ViMark.h"

@interface ViMarkGroup : NSObject
{
	SEL			 _groupSelector;
	NSMutableDictionary	*_groups;
}

@property (nonatomic, readonly) NSArray *groups;

+ (ViMarkGroup *)markGroupWithSelector:(SEL)aSelector;
- (ViMarkGroup *)initWithSelector:(SEL)aSelector;

- (NSString *)attribute;
- (void)rebuildFromMarks:(NSArray *)marks;
- (void)addMark:(ViMark *)mark;
- (void)addMarksFromArray:(NSArray *)marksToAdd;
- (void)removeMark:(ViMark *)mark;
- (void)clear;

@end




@interface ViMarkList : NSObject
{
	NSMutableArray		*_marks;
	NSMutableDictionary	*_marksByName;
	NSInteger		 _currentIndex;
	NSMutableDictionary	*_groups;
	id			 _identifier;
	NSImage			*_icon;
	id			 _userParameter;
}

@property (nonatomic, readonly) NSArray *marks;
@property (nonatomic, readwrite, retain) id userParameter;

+ (ViMarkList *)markListWithIdentifier:(id)anIdentifier;
+ (ViMarkList *)markList;
- (ViMarkList *)initWithIdentifier:(id)anIdentifier;

- (void)clear;
- (ViMark *)lookup:(NSString *)name;
- (NSUInteger)count;
- (void)addMark:(ViMark *)mark;
- (void)addMarksFromArray:(NSArray *)marksToAdd;
- (void)removeMarkAtIndex:(NSUInteger)index;
- (void)removeMark:(ViMark *)mark;

- (ViMark *)first;
- (ViMark *)last;
- (ViMark *)next;
- (ViMark *)previous;
- (ViMark *)current;
- (BOOL)atBeginning;
- (BOOL)atEnd;

- (void)push:(ViMark *)mark;
- (ViMark *)pop;

@end






@interface ViMarkStack : NSObject
{
	NSString	*_name;
	NSMutableArray	*_lists;
	NSInteger	 _currentIndex;
	NSInteger	 _maxLists;
}

@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readonly) ViMarkList *list;
@property (nonatomic, readwrite) NSInteger maxLists;

+ (ViMarkStack *)markStackWithName:(NSString *)name;
- (ViMarkStack *)initWithName:(NSString *)name;
- (ViMarkList *)makeList;
- (void)clear;
- (void)setMaxLists:(NSInteger)num;
- (void)removeListAtIndex:(NSUInteger)index;
- (ViMarkList *)push:(ViMarkList *)list;
- (ViMarkList *)listAtIndex:(NSInteger)anIndex;
- (ViMarkList *)next;
- (ViMarkList *)previous;
- (ViMarkList *)last;
- (ViMarkList *)current;
- (BOOL)atBeginning;
- (BOOL)atEnd;

@end






@interface ViMarkManager : NSObject
{
	NSMutableArray		*_stacks;
	NSMutableDictionary	*_namedStacks; // keyed by name
}

@property (nonatomic, readonly) NSArray *stacks;

+ (ViMarkManager *)sharedManager;
- (void)removeStack:(ViMarkStack *)stack;
- (void)removeStackWithName:(NSString *)name;
- (ViMarkStack *)makeStack;
- (ViMarkStack *)stackWithName:(NSString *)name;

@end
