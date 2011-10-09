//	
//	Copyright 2003,2005-2006 Chris Thomas. All rights reserved.
//	
//	Permission to use, copy, modify, and distribute this software for any
//	purpose with or without fee is hereby granted, provided that the above
//	copyright notice and this permission notice appear in all copies.
//	
//	THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//	WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//	MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
//	ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//	WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//	ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
//	OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//	

// Chris's eXperimental Objective-C interface to CGShading.

#include <ApplicationServices/ApplicationServices.h>

 // delegate for shading function - (void) shade:(float)alpha toColor:(float *)outColor
typedef struct
{
	id				target;
	SEL				selector;
} _CXShadingDelegateMethod;

@interface CXShading : NSObject
{
	CGShadingRef				fShading;
	CGColorSpaceRef				fColorSpace;
	CGFunctionRef				fFunction;
	_CXShadingDelegateMethod	fMethod;

	struct
	{
		CGFloat				from[4];
		CGFloat				to[4];
	} fColors;
}

- (id)initWithStartingColor:(NSColor *)startColor endingColor:(NSColor *)endColor;

- (void)drawFromPoint:(NSPoint)fromPoint toPoint:(NSPoint)toPoint;

@end
