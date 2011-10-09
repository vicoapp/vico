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

#import "CXShading.h"
#import <objc/objc-runtime.h>

@implementation CXShading

static void ShadingFunction (void *			info, 
                            const CGFloat *	in, 
                            CGFloat *			out)
{
	_CXShadingDelegateMethod *	method = (_CXShadingDelegateMethod *) info;
	
	objc_msgSend( method->target, method->selector, in, out );
//	NSLog( @"%X:%g: %g,%g,%g,%g", method->target, *in, out[0], out[1], out[2], out[3] );
}


- (CGFunctionRef) shadingFunctionForColorspace:(CGColorSpaceRef) colorspace info:(void *)info
{
    size_t								components;
    static const CGFloat					inputValueRange [2] = { 0, 1 };
    static const CGFloat					outputValueRanges [8] = { 0, 1, 0, 1, 0, 1, 0, 1 };
    static const CGFunctionCallbacks	callbacks = { 0, &ShadingFunction, NULL };

    components = 1 + CGColorSpaceGetNumberOfComponents (colorspace); 
    return CGFunctionCreate (	info,  
                                1,  
                                inputValueRange,  
                                components,  
                                outputValueRanges,  
                                &callbacks); 
}


// kludge
static inline CGPoint CGPointFromNSPoint( NSPoint point )
{
	return *(CGPoint *)&point;
}

- (void) commonInit
{
	fColorSpace = CGColorSpaceCreateDeviceRGB();
	fFunction = [self shadingFunctionForColorspace:fColorSpace info:&fMethod];

	fMethod.target		= self;
	fMethod.selector	= @selector(linearInterpolationFunction:toColor:);
}

- (id)initWithStartingColor:(NSColor *)startColor endingColor:(NSColor *)endColor
{
	// Get both colors as Device RGBA
	startColor	= [startColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	endColor	= [endColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	
	[startColor	getRed:&fColors.from[0]
			green:&fColors.from[1]
			 blue:&fColors.from[2] 
			alpha:&fColors.from[3]];

	[endColor getRed:&fColors.to[0]
			green:&fColors.to[1]
			 blue:&fColors.to[2] 
			alpha:&fColors.to[3]];
	
	[self commonInit];
	
	return self;
}

- (void) dealloc
{
	if(fFunction != NULL)
	{
		CGFunctionRelease(fFunction);
	}
	
	if(fColorSpace != NULL)
	{
		CGColorSpaceRelease(fColorSpace);
	}
	
	if(fShading != NULL)
	{
		CGShadingRelease(fShading);	
	}
	
	[super dealloc];
}

#if 0
#pragma mark -
#pragma mark Simple linear gradient
#endif

static inline float LinearInterpolate(float from, float to, float alpha)
{
	return (((1.0f - alpha) * from) + (alpha * to));
}

- (void) linearInterpolationFunction:(const float *)alpha toColor:(float *)color
{
	float a = *alpha;
	
	color[0] = LinearInterpolate( fColors.from[0], fColors.to[0], a );
	color[1] = LinearInterpolate( fColors.from[1], fColors.to[1], a );
	color[2] = LinearInterpolate( fColors.from[2], fColors.to[2], a );
	color[3] = LinearInterpolate( fColors.from[3], fColors.to[3], a );
}

#if 0
#pragma mark -
#pragma mark Drawing
#endif

- (void)drawFromPoint:(NSPoint)fromPoint toPoint:(NSPoint)toPoint
{
	if(fShading != NULL)
	{
		CGShadingRelease(fShading);
	}
	
	fShading = CGShadingCreateAxial(fColorSpace, CGPointFromNSPoint(fromPoint), CGPointFromNSPoint(toPoint), fFunction, true, true);
	if( fShading == NULL )
	{
		[NSException raise:@"EvilCGShading" format:@"Cannot allocate CGShading!"];
	}
	
	CGContextDrawShading( [[NSGraphicsContext currentContext] graphicsPort], fShading );
}


@end
