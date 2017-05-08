//
//  MultiLayerTimeSeriesView.m
//  metrics
//
//  Created by Evadne Wu on 01/01/2017.
//  Copyright © 2017 Radius Development. All rights reserved.
//

#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import "MultiLayerTimeSeriesView.h"

@interface MultiLayerTimeSeriesView () <CALayerDelegate>
+ (NSMutableSet *) timerTargets;
+ (CVDisplayLinkRef) displayLink;
- (void) tick:(const CVTimeStamp *)outputTime;
@property (nonatomic, readonly, strong) NSMutableArray<NSNumber *> *values;
@end

static CVReturn MultiLayerTimeSeriesViewCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext) {
	NSArray *targets = [MultiLayerTimeSeriesView.timerTargets copy];
	
	dispatch_sync(dispatch_get_main_queue(), ^{
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
		for (MultiLayerTimeSeriesView *target in targets) {
			[target tick:outputTime];
		}
		[CATransaction commit];
	});
	

	return kCVReturnSuccess;
}

@implementation MultiLayerTimeSeriesView

+ (NSMutableSet *) timerTargets {
	static NSMutableSet *timerTargets = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		timerTargets = [NSMutableSet set]; 
	});
	
	return timerTargets;
}

+ (CVDisplayLinkRef) displayLink {
	static CVDisplayLinkRef displayLink = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		CVDisplayLinkRef displayLink = NULL;
		CVDisplayLinkCreateWithActiveCGDisplays(&displayLink); 
		CVDisplayLinkSetOutputCallback(displayLink, &MultiLayerTimeSeriesViewCallback, (__bridge void *)self);
		CVDisplayLinkStart(displayLink);
	});
	
	return displayLink;
}

+ (NSArray <NSColor *> *)colors {
	static dispatch_once_t onceToken;
	static NSArray <NSColor *> *colors;
	dispatch_once(&onceToken, ^{
		NSColor * (^colourFromComponents)(NSUInteger, NSUInteger, NSUInteger) = ^ (NSUInteger red, NSUInteger green, NSUInteger blue) {
			return [NSColor colorWithSRGBRed:(((float_t)red)/256.0f) green:(((float_t)green)/256.0f) blue:(((float_t)blue)/256.0f) alpha:1.0f];
		};
			
		colors = @[
			colourFromComponents(5,112,176),
			colourFromComponents(116,169,207),
			colourFromComponents(189,201,225),
			colourFromComponents(241,238,246),
			colourFromComponents(237,248,251),
			colourFromComponents(178,226,226),
			colourFromComponents(102,194,164),
			colourFromComponents(35,139,69)
		]; 
	});
	
	return colors;
}

+ (CGImageRef) sharedStripeImage {
	static dispatch_once_t onceToken;
	static CGImageRef stripeImage;
	dispatch_once(&onceToken, ^{
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		uint32_t bitmapInfo = kCGImageAlphaNoneSkipFirst|kCGBitmapByteOrderDefault;
		size_t stepHeight = 32;
		size_t bufferWidth = 1;
		size_t bufferHeight = stepHeight * self.colors.count;
		CGContextRef context = CGBitmapContextCreate(NULL, bufferWidth, bufferHeight, 8, bufferWidth * 8, colorSpace, bitmapInfo);
		CGColorSpaceRelease(colorSpace);
		
		NSUInteger colorIndex = 0;
		for (NSColor *color in self.colors) {
			CGContextSetFillColorWithColor(context, color.CGColor);
			CGContextFillRect(context, (NSRect){ 0, stepHeight * colorIndex, bufferWidth, stepHeight });
			colorIndex = colorIndex + 1; 
		}
		stripeImage = CGBitmapContextCreateImage(context);
		CGContextRelease(context);
	});
	return stripeImage;
}

- (id) initWithCoder:(NSCoder *)decoder {
	return [[super initWithCoder:decoder] commonInit];
}

- (id) initWithFrame:(CGRect)frame {
	return [[super initWithFrame:frame] commonInit];
}

- (id) commonInit {
	self.layer = [CALayer layer];
	self.layer.backgroundColor = [NSColor whiteColor].CGColor;
	self.layer.opaque = YES;
	self.layer.masksToBounds = NO;
	self.layer.edgeAntialiasingMask = 0;
	self.layer.delegate = self;
	self.wantsLayer = YES;
	self.postsFrameChangedNotifications = YES;
	self.postsBoundsChangedNotifications = YES;
	
	_values = [NSMutableArray arrayWithCapacity:128];
	return self;
}

- (void) viewWillMoveToSuperview:(NSView *)newSuperview {
	[super viewWillMoveToSuperview:newSuperview];
	if (newSuperview) {
		[self.class displayLink];
		[self.class.timerTargets addObject:self];
	} else {
		self.postsFrameChangedNotifications = NO;
		self.postsBoundsChangedNotifications = NO;
		[self.class.timerTargets removeObject:self];
	}
}

- (CGFloat) stepWidth {
	return 1.0f;
}

- (void) recreateSublayers {
	NSArray <CALayer *> *existingLayers = self.layer.sublayers;
	NSUInteger numberOfExistingLayers = existingLayers.count;
	NSUInteger numberOfRequiredLayers = CGRectGetWidth(self.bounds) / self.stepWidth;
	if (numberOfExistingLayers > numberOfRequiredLayers) {
		NSArray *removedLayers = [existingLayers objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, numberOfRequiredLayers - numberOfExistingLayers)]];
		for (CALayer *layer in removedLayers) {
			[layer removeFromSuperlayer];
		}
	} else if (numberOfExistingLayers < numberOfRequiredLayers) {
		NSUInteger numberOfAdditionalLayers = numberOfRequiredLayers - numberOfExistingLayers; 
		for (NSUInteger i = 0; i < numberOfAdditionalLayers; i++) {
			[self.layer addSublayer:[self newLayer]];
		} 
 }
}

- (void) layoutSublayersOfLayer:(CALayer *)layer { 
	if (layer != self.layer) {
		return;
	}
	[self recreateSublayers];
	
	CGFloat stepWidth = self.stepWidth;
	CGFloat stageWidth = CGRectGetWidth(self.bounds);
	CGFloat stageHeight = CGRectGetHeight(self.bounds);
	
	NSUInteger layerIndex = 0;
	for (CALayer *sublayer in self.layer.sublayers) {
		sublayer.bounds = (CGRect){ 0, 0, stepWidth, 8.0f * stageHeight };
		sublayer.backgroundColor = [NSColor colorWithRed:((CGFloat)layerIndex / stageWidth) green:1 blue:1 alpha:1].CGColor;
		layerIndex = layerIndex + 1;
	}
}

- (CALayer *) newLayer {
	CALayer *layer = [CALayer layer];
//	layer.anchorPoint = CGPointZero;
	layer.backgroundColor = [NSColor redColor].CGColor;
//	layer.contents = (__bridge id)self.class.sharedStripeImage;
//	layer.contentsRect = (CGRect) { 0, 0, 1, 0.125f };
//	layer.contentsScale = 1.0f; 
	return layer;
}

- (void) fillValue {
	NSNumber *lastNumber;
	float_t target = ((lastNumber = self.values.lastObject)) ?
		(lastNumber.floatValue + (0.1f * ((float)rand()/(float)RAND_MAX) - 0.05f)) :
		(2.0f * ((float)rand()/(float)RAND_MAX) - 1.0f);
	[self.values addObject:@(MIN(1.0f, MAX(-1.0f, target)))];
	
	if (self.values.count > 128) {
		[self.values removeObjectsInRange:(NSRange){ 0, self.values.count - 128 }];
	}
}

- (void) tick:(const CVTimeStamp *)outputTime {
	[self fillValue];
	
	NSArray <NSNumber *> *values = self.values;
	NSArray <CALayer *> *layers = self.layer.sublayers;
	NSUInteger numberOfValuesShown = MIN(layers.count, values.count);
	
	if (numberOfValuesShown == 0)
		return;
	
	NSArray <NSNumber *> *valuesShown = [values objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(values.count - numberOfValuesShown,numberOfValuesShown)]];
	
	NSArray <CALayer *> *layersAdjusted = [layers objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(layers.count - valuesShown.count, valuesShown.count)]];
	
	CGFloat stepWidth = self.stepWidth;
	CGFloat stageWidth = CGRectGetWidth(self.bounds);
	CGFloat stageHeight = CGRectGetHeight(self.bounds);
	NSUInteger index = 0;
	
//	NSLog(@"tick %i/%i %i/%i", values.count, valuesShown.count, layers.count, layersAdjusted.count);
	for (CALayer *layer in layersAdjusted) {
		layer.position = (CGPoint){
			(stageWidth - (CGFloat)index * stepWidth),
			valuesShown[index].floatValue / stageHeight
		};
//		NSLog(@"-> %@", NSStringFromPoint(layer.position));
		index = index + 1;
//		layer.contentsRect = (CGRect) {
//			0,
//			valuesShown[index].floatValue / 9.0f,
//			1,
//			0.125f
//		};
	}
}

@end
