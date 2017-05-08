//
//  DummyView.m
//  metrics
//
//  Created by Evadne Wu on 28/12/2016.
//  Copyright © 2016 Radius Development. All rights reserved.
//

#import "DummyView.h"

@implementation DummyView
//
//- (BOOL) wantsUpdateLayer {
//	return YES;
//}
//
//- (BOOL) wantsLayer {
//	return YES;
//}
//
//- (void) updateLayer {
//	[super updateLayer];
////	self.layer.backgroundColor = self.backgroundColor.CGColor;
//}	

- (BOOL) wantsDefaultClipping {
	return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
	CGColorRef color = _backgroundColor.CGColor;
	if (color) {
		CGContextRef context = NSGraphicsContext.currentContext.CGContext;
		CGContextSaveGState(context);
		CGContextSetFillColorWithColor(context, color);
		CGContextFillRect(context, dirtyRect);
		CGContextRestoreGState(context);
	}
}

@end
