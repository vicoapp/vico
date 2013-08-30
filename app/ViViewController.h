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

#import "ViTabController.h"

/** A ViViewController manages a split view in Vico.
 * @see ViDocumentView.
 */
@interface ViViewController : NSViewController
{
	ViTabController	*__weak _tabController;
	BOOL		 _modified;
	BOOL		 _processing;
}

/** The ViTabController this view belongs to. */
@property (nonatomic,readwrite,weak) ViTabController *tabController;

/** The inner NSView will be made key when the view gets focus. */
@property (nonatomic,readonly) NSView *innerView;

/** YES if the view represents a modified object.
 * When this is YES, a different close button is displayed in the tab bar.
 */
@property (nonatomic,readwrite) BOOL modified;

/** YES if the view represents an object that is busy processing a command.
 * When this is YES, a spinner is displayed in the tab bar.
 */
@property (nonatomic,readwrite) BOOL processing;

- (void)attach;
- (void)detach;

@end
