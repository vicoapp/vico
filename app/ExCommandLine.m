#import "ExCommandLine.h"

@implementation ExCommandLine

- (void)drawRect:(NSRect)dirtyRect
{
	CGContextRef viewContext = [[NSGraphicsContext currentContext] graphicsPort];

	NSRect bounds = [self bounds];
	bounds.origin.x += 5;
	bounds.size.width -= 15;

	CGGradientRef backgroundGradient;
	CGColorSpaceRef backgroundColorSpace;

    CGContextSaveGState(viewContext);

	CGSize shadowOffset = CGSizeMake(0,0);
    CGContextSetShadow (viewContext, shadowOffset, 10);

    CGContextSaveGState(viewContext);
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:10 yRadius:10];
	[path setClip];

	CGContextBeginPath(viewContext);
 
	size_t numGradientPoints = 2;
	CGFloat gradientPoints[2] = { 0, 1 };
	CGFloat pointColors[8] = { 0.69, 0.69, 0.69, 1.0,
							  0.94, 0.94, 0.94, 1.0 };

	backgroundColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	backgroundGradient =
	  CGGradientCreateWithColorComponents(backgroundColorSpace, pointColors, gradientPoints, numGradientPoints);

	CGContextSetRGBFillColor (viewContext, 0, 0, 1, 1);

	CGPoint startPoint, endPoint;
	startPoint.x = 0.5;
	startPoint.y = 0.0;
	endPoint.x = 0.5;
	endPoint.y = bounds.size.height;
	CGContextDrawLinearGradient(viewContext, backgroundGradient, startPoint, endPoint, 0);

	CGContextRestoreGState(viewContext);

	CGColorSpaceRelease(backgroundColorSpace);

	CGContextRestoreGState(viewContext);
}

@end
