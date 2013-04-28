#import "ExCommandLine.h"

// Allow conversion of NSBezierPath to a CGPathRef.
@implementation NSBezierPath (BezierPathQuartzUtilities)
- (CGPathRef)quartzPath
{
	NSInteger i, numElements;
 
	// Need to begin a path here.
	CGPathRef		   immutablePath = NULL;
 
	// Then draw the path elements.
	numElements = [self elementCount];
	if (numElements > 0)
	{
		CGMutablePathRef	path = CGPathCreateMutable();
		NSPoint			 points[3];
		BOOL				didClosePath = YES;
 
		for (i = 0; i < numElements; i++)
		{
			switch ([self elementAtIndex:i associatedPoints:points])
			{
				case NSMoveToBezierPathElement:
					CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
					break;
 
				case NSLineToBezierPathElement:
					CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
					didClosePath = NO;
					break;
 
				case NSCurveToBezierPathElement:
					CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y,
										points[1].x, points[1].y,
										points[2].x, points[2].y);
					didClosePath = NO;
					break;
 
				case NSClosePathBezierPathElement:
					CGPathCloseSubpath(path);
					didClosePath = YES;
					break;
			}
		}
 
		// Be sure the path is closed or Quartz may not do valid hit detection.
		if (!didClosePath)
			CGPathCloseSubpath(path);
 
		immutablePath = CGPathCreateCopy(path);
		CGPathRelease(path);
	}
 
	return immutablePath;
}
@end

@implementation ExCommandLine

- (void)drawRect:(NSRect)dirtyRect
{
	NSRect bounds = [self bounds];
	NSRect backgroundBounds = CGRectOffset(bounds, 10, 10);
	backgroundBounds.size.width -= 25;
	backgroundBounds.size.height -= 20;

	CGContextRef viewContext = [[NSGraphicsContext currentContext] graphicsPort];
	CGLayerRef backgroundLayer = CGLayerCreateWithContext(viewContext, bounds.size, NULL);
	CGContextRef backgroundContext = CGLayerGetContext(backgroundLayer);

	// Clip to a rounded rectangle.
	NSBezierPath *backgroundClipRect = [NSBezierPath bezierPathWithRoundedRect:backgroundBounds xRadius:10 yRadius:10];
	CGPathRef backgroundClipRef = [backgroundClipRect quartzPath];
	CGContextAddPath(backgroundContext, backgroundClipRef);
	CGContextClip(backgroundContext);

	CGContextBeginPath(backgroundContext);
 
	// Draw the clipped gradient to the background layer.
	size_t numGradientPoints = 2;
	CGFloat gradientPoints[2] = { 0, 1 };
	CGFloat pointColors[8] = { 0.69, 0.69, 0.69, 1.0,
							  0.94, 0.94, 0.94, 1.0 };

	CGColorSpaceRef backgroundColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	CGGradientRef backgroundGradient =
	  CGGradientCreateWithColorComponents(backgroundColorSpace, pointColors, gradientPoints, numGradientPoints);

	CGPoint startPoint, endPoint;
	startPoint.x = 0.5;
	startPoint.y = 0.0;
	endPoint.x = 0.5;
	endPoint.y = bounds.size.height;
	CGContextDrawLinearGradient(backgroundContext, backgroundGradient, startPoint, endPoint, 0);

	CGColorSpaceRelease(backgroundColorSpace);

	// Now draw the layer to the view context with a shadow.
	CGContextSaveGState(viewContext);

	CGSize shadowOffset = CGSizeMake(0,0);
	CGContextSetShadow (viewContext, shadowOffset, 10);

	CGContextDrawLayerAtPoint(viewContext, NSMakePoint(0,0), backgroundLayer);

	CGContextRestoreGState(viewContext);
}

@end
