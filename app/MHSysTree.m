/*
 * Copyright 2006 Martin Hedenfalk <martin@bzero.se>
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
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.kk
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "MHSysTree.h"
#import "logging.h"

@implementation MHSysTree

RB_GENERATE(id_tree, rb_entry, entry, id_cmp);

int
id_cmp(struct rb_entry *a, struct rb_entry *b)
{
	return (int)((pointer_t)[a->obj performSelector:a->compareSelector withObject:b->obj]);
}

- (id)initWithCompareSelector:(SEL)aSelector
{
	if ((self = [super init]) != nil) {
		RB_INIT(&_root);
		_nitems = 0;
		_compareSelector = aSelector;
#ifdef __OBJC_GC__
		_strongRefs = [[NSMutableSet alloc] init];
#endif
	}

	return self;
}

- (id)init
{
	return [self initWithCompareSelector:@selector(compare:)];
}

- (void)dealloc
{
	[self removeAllObjects];
	[super dealloc];
}

- (void)finalize
{
	[self removeAllObjects];
	[super finalize];
}

- (void)addObject:(id)anObject
{
	struct rb_entry *e = malloc(sizeof(*e));
	e->obj = [anObject retain];
#ifdef __OBJC_GC__
	[_strongRefs addObject:anObject];
#endif
	e->compareSelector = _compareSelector;
	struct rb_entry *duplicate = RB_INSERT(id_tree, &_root, e);
	if (duplicate) {
		INFO(@"*********** got duplicate object %@ for new object %@", duplicate->obj, anObject);
		[self removeEntry:duplicate];
		duplicate = RB_INSERT(id_tree, &_root, e);
		if (duplicate) {
			INFO(@"!!!!!!!!!!! got second duplicate object %p for new object %p", duplicate->obj, anObject);
		}
	}
	_nitems++;
}

- (void)addObjectsFromArray:(NSArray *)anArray
{
	for (id obj in anArray)
		[self addObject:obj];
}

- (void)removeEntry:(struct rb_entry *)anEntry
{
	RB_REMOVE(id_tree, &_root, anEntry);
#ifdef __OBJC_GC__
	[_strongRefs removeObject:anEntry->obj];
#endif
	[anEntry->obj release];
	free(anEntry);
	_nitems--;
}

- (void)removeObject:(id)anObject
{
	struct rb_entry *e = [self lookup:anObject];
	if (e)
		[self removeEntry:e];
}

- (unsigned)count
{
	return _nitems;
}

- (BOOL)containsObject:(id)anObject
{
	return [self lookup:anObject] == nil ? NO : YES;
}

- (id)find:(id)anObject
{
	struct rb_entry *e = [self lookup:anObject];
	return e ? e->obj : nil;
}

- (struct rb_entry *)lookup:(id)anObject
{
	struct rb_entry find;
	find.obj = anObject;
	find.compareSelector = _compareSelector;

	return RB_FIND(id_tree, &_root, &find);
}

- (NSArray *)allObjects
{
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:_nitems];
	struct rb_entry *e;
	RB_FOREACH(e, id_tree, &_root) {
		[array addObject:e->obj];
	}

	return array;
}

- (void)removeAllObjects
{
	struct rb_entry *e;
	while ((e = RB_MIN(id_tree, &_root)) != NULL) {
		[self removeEntry:e];
	}
}

- (MHSysTree *)copy
{
	MHSysTree *cp = [[MHSysTree alloc] initWithCompareSelector:_compareSelector];
	struct rb_entry *e;
	RB_FOREACH(e, id_tree, &_root) {
		[cp addObject:e->obj];
	}
	return cp;
}

- (void)makeObjectsPerformSelector:(SEL)aSelector target:(id)aTarget context:(id)context
{
	struct rb_entry *e;
	RB_FOREACH(e, id_tree, &_root) {
		[aTarget performSelector:aSelector withObject:e->obj withObject:context];
	}
}

- (struct rb_entry *)root
{
	return RB_ROOT(&_root);
}

- (struct rb_entry *)first
{
	return RB_MIN(id_tree, &_root);
}

- (struct rb_entry *)last
{
	return RB_MAX(id_tree, &_root);
}

- (struct rb_entry *)next:(struct rb_entry *)current
{
	return RB_NEXT(id_tree, &_root, current);
}

- (struct rb_entry *)left:(struct rb_entry *)current
{
	return RB_LEFT(current, entry);
}

- (struct rb_entry *)right:(struct rb_entry *)current
{
	return RB_RIGHT(current, entry);
}

- (struct rb_entry *)parent:(struct rb_entry *)current
{
	return RB_PARENT(current, entry);
}

@end
