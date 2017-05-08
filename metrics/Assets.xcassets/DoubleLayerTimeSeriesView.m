//
//  DoubleLayerTimeSeriesView.m
//  metrics
//
//  Created by Evadne Wu on 31/12/2016.
//  Copyright © 2016 Radius Development. All rights reserved.
//

#import <CoreVideo/CoreVideo.h>
#import <Quartz/Quartz.h>
#import "DoubleLayerTimeSeriesView.h"

@interface DoubleLayerTimeSeriesView ()
@property (nonatomic, readonly, strong) CALayer *leftLayer;
@property (nonatomic, readonly, strong) CALayer *rightLayer;
@end

@implementation DoubleLayerTimeSeriesView

+ (CGImageRef) newImageWithBackgroundColor:(NSColor *)color {
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	uint32_t bitmapInfo = kCGImageAlphaNoneSkipFirst|kCGBitmapByteOrderDefault;
	size_t bufferWidth = 120;
	size_t bufferHeight = 30;
	CGContextRef context = CGBitmapContextCreate(NULL, bufferWidth, bufferHeight, 8, bufferWidth * 8, colorSpace, bitmapInfo);
	CGColorSpaceRelease(colorSpace);
	CGContextSetFillColorWithColor(context, color.CGColor);
	CGContextFillRect(context, (NSRect){ 0, 0, bufferWidth, bufferHeight });
	CGImageRef image = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	return image;
}

- (id) initWithCoder:(NSCoder *)decoder {
	return [[super initWithCoder:decoder] commonInit];
}

- (id) initWithFrame:(CGRect)frame {
	return [[super initWithFrame:frame] commonInit];
}

- (id) commonInit {
	self.wantsLayer = YES;
	self.layer = [CALayer layer];
	self.layer.backgroundColor = [NSColor whiteColor].CGColor;
	self.layer.opaque = YES;
	self.layer.masksToBounds = NO;
	self.layer.edgeAntialiasingMask = 0;
	
	_leftLayer = [CALayer layer];
	_rightLayer = [CALayer layer];
	
	_leftLayer.opaque = YES;
	_leftLayer.anchorPoint = CGPointZero;
	_leftLayer.contentsScale = 1.0f;
	_leftLayer.contentsGravity = kCAGravityTopLeft;
	_leftLayer.masksToBounds = NO;
	_leftLayer.edgeAntialiasingMask = 0;
	
	_rightLayer.opaque = YES;
	_rightLayer.anchorPoint = (CGPoint){ 1, 0 };
	_rightLayer.contentsScale = 1.0f;
	_rightLayer.contentsGravity = kCAGravityTopLeft;
	_rightLayer.masksToBounds = NO;
	_rightLayer.edgeAntialiasingMask = 0;
	
	[self.layer addSublayer:_leftLayer];
	[self.layer addSublayer:_rightLayer];
	
	CGImageRef leftImage = [self.class newImageWithBackgroundColor:[NSColor yellowColor]];
	_leftLayer.contents = (__bridge id)leftImage;
	CGImageRelease(leftImage);
	
	CGImageRef rightImage = [self.class newImageWithBackgroundColor:[NSColor purpleColor]];
	_rightLayer.contents = (__bridge id)rightImage;
	CGImageRelease(rightImage);
	
	return self;
}

- (BOOL) isOpaque {
	return YES;
}

- (void) viewWillMoveToSuperview:(NSView *)newSuperview {
	[super viewWillMoveToSuperview:newSuperview];
	if (newSuperview) {
		[self setNeedsLayout:YES];
	}
}

- (void) layout {
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	
	CGRect bounds = self.layer.bounds;
	CGFloat stageWidth = CGRectGetWidth(bounds);
	CGFloat stageHeight = CGRectGetHeight(bounds);
	CGFloat speed = 30.0f;
	NSCParameterAssert(fmodf(stageWidth, speed) == 0.0f);
	NSCParameterAssert(fmodf(stageHeight, 1.0f) == 0.0f);
	
	[_leftLayer removeAllAnimations];
	[_rightLayer removeAllAnimations];
	
	CAMediaTimingFunction *timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];

	CABasicAnimation *leftAnimation = [CABasicAnimation animationWithKeyPath:@"bounds"];
	leftAnimation.fromValue = [NSValue valueWithRect:(NSRect){ 0, 0, stageWidth, stageHeight }];
	leftAnimation.toValue = [NSValue valueWithRect:(NSRect){ 0, 0, 0, stageHeight }];
	leftAnimation.duration = stageWidth / speed;	
	leftAnimation.repeatCount = MAXFLOAT;
	leftAnimation.timingFunction = timingFunction;
	
	CABasicAnimation *rightAnimation = [CABasicAnimation animationWithKeyPath:@"bounds"];
	rightAnimation.fromValue = [NSValue valueWithRect:(NSRect){ 0, 0, 0, stageHeight }];
	rightAnimation.toValue = [NSValue valueWithRect:(NSRect){ 0, 0, stageWidth, stageHeight }];
	rightAnimation.duration = stageWidth / speed;	
	rightAnimation.repeatCount = MAXFLOAT;
	rightAnimation.timingFunction = timingFunction;

	[_leftLayer addAnimation:leftAnimation forKey:@"bounds"];
	[_rightLayer addAnimation:rightAnimation forKey:@"bounds"];
	
	_leftLayer.frame = bounds;
	_rightLayer.frame = bounds;

#if 0	
	CABasicAnimation *moveAnimation = [CABasicAnimation animationWithKeyPath:@"position.x"];
	moveAnimation.fromValue = @(0.0f);
	moveAnimation.toValue = @(-1.0f * stageWidth);
	moveAnimation.duration = stageWidth / speed;
	moveAnimation.removedOnCompletion = YES;
	moveAnimation.repeatCount = MAXFLOAT;
	moveAnimation.additive = YES;
	
	_leftLayer.frame = bounds;
	_rightLayer.frame = CGRectOffset(bounds, stageWidth, 0.0f);	
	[_leftLayer addAnimation:moveAnimation forKey:@"positioning"];
	[_rightLayer addAnimation:moveAnimation forKey:@"positioning"];
#endif

	[CATransaction commit];
}

@end
