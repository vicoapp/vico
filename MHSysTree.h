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
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "sys_tree.h"
#import <Foundation/Foundation.h>

struct rb_entry
{
    RB_ENTRY(rb_entry) entry;
    id obj;
    SEL compareSelector;
};

/* This is an objective-c wrapper around sys_tree. sys_tree is a red-black tree
   implementation.  It invokes compare: on all objects you insert into it, to
   figure out where to sort your objects. */

@interface MHSysTree : NSObject
{
    unsigned nitems;
    RB_HEAD(id_tree, rb_entry) root;
    SEL compareSelector;
}

int id_cmp(struct rb_entry *a, struct rb_entry *b);

RB_PROTOTYPE(id_tree, rb_entry, entry, id_cmp);

- (id)initWithCompareSelector:(SEL)aSelector;
- (id)init;
- (MHSysTree *)copy;

- (void)addObject:(id)anObject;
- (void)addObjectsFromArray:(NSArray *)anArray;
- (void)removeObject:(id)anObject;
- (void)removeAllObjects;

- (unsigned)count;
- (BOOL)containsObject:(id)anObject;
- (id)find:(id)anObject;
- (struct rb_entry *)lookup:(id)anObject;

- (NSArray *)allObjects;
- (void)removeEntry:(struct rb_entry *)anEntry;
- (void)makeObjectsPerformSelector:(SEL)aSelector target:(id)aTarget;

- (struct rb_entry *)root;
- (struct rb_entry *)first;
- (struct rb_entry *)next:(struct rb_entry *)current;
- (struct rb_entry *)left:(struct rb_entry *)current;
- (struct rb_entry *)right:(struct rb_entry *)current;
- (struct rb_entry *)parent:(struct rb_entry *)current;

@end

