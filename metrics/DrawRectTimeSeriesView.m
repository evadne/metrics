//
//  DrawRectTimeSeriesView.m
//  metrics
//
//  Created by Evadne Wu on 21/12/2016.
//  Copyright © 2016 Radius Development. All rights reserved.
//

#import "DrawRectTimeSeriesView.h"
#import <CoreVideo/CVDisplayLink.h>

NSColor * colourFromComponents (NSUInteger red, NSUInteger green, NSUInteger blue) {
	return [NSColor colorWithSRGBRed:(((float_t)red)/256.0f) green:(((float_t)green)/256.0f) blue:(((float_t)blue)/256.0f) alpha:1.0f];
}

@interface DrawRectTimeSeriesView ()
@property (strong) NSArray<NSColor *> *positiveColours;
@property (strong) NSArray<NSColor *> *negativeColours;
@property (strong, nonatomic) NSMutableArray<NSNumber *> *values;
@property (strong) NSTimer *timer;
@end

@implementation DrawRectTimeSeriesView

+ (NSMutableSet *) timerTargets {
	static NSMutableSet *timerTargets = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		timerTargets = [NSMutableSet set]; 
	});
	
	return timerTargets;
}

+ (NSTimer *) timer {
	static NSTimer *timer = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		__weak typeof(self) wSelf = self;
		timer = [NSTimer scheduledTimerWithTimeInterval:(10.0f / 60.0f) repeats:YES block:^(NSTimer * _Nonnull timer) {
			for (void(^block)(void) in wSelf.timerTargets) {
				block();
			}
		}];
	});
	
	return timer;
}

- (BOOL) isOpaque {
	return YES;
}

- (BOOL) wantsDefaultClipping {
	return NO;
}

- (id) initWithCoder:(NSCoder *)decoder {
	self = [super initWithCoder:decoder];
	if (!self) {
		return nil;
	}
	
	[self commonInit];
	return self;
}

- (id) initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self) {
		return nil;
	}
	
	[self commonInit];
	return self;
}

- (void) commonInit {
	__weak typeof(self) wSelf = self;
	
//	[super awakeFromNib];

	[self.class timer];
	[self.class.timerTargets addObject:(id)[^{
		[wSelf update];
	} copy]];
	
	self.positiveColours = @[
		colourFromComponents(237,248,251),
		colourFromComponents(178,226,226),
		colourFromComponents(102,194,164),
		colourFromComponents(35,139,69)
	];
	self.negativeColours = @[
		colourFromComponents(241,238,246),
		colourFromComponents(189,201,225),
		colourFromComponents(116,169,207),
		colourFromComponents(5,112,176)
	];
}

- (void) update {
	NSCParameterAssert(nil);
	[self fillValue];
	[self setNeedsDisplay:YES];
}

- (NSMutableArray *) values {
	if (!_values) {
		_values = [NSMutableArray array];
	}
	return _values;
}

- (void) fillValue {
	NSNumber *lastNumber;
	float_t target = ((lastNumber = self.values.lastObject)) ?
		(lastNumber.floatValue + (0.1f * ((float)rand()/(float)RAND_MAX) - 0.05f)) :
		(2.0f * ((float)rand()/(float)RAND_MAX) - 1.0f);
	[self.values addObject:@(MIN(1.0f, MAX(-1.0f, target)))];
}

- (CGFloat) stepWidth {
	return 64.0f;
}

- (void) drawRect:(NSRect)dirtyRect {
	CGContextRef context = NSGraphicsContext.currentContext.CGContext;
	[NSColor.whiteColor set];
	CGContextFillRect(context, self.bounds);
	CGRect bounds = self.bounds;
	CGFloat boundsWidth = CGRectGetWidth(bounds);
	CGFloat boundsHeight = CGRectGetHeight(bounds); 
	CGFloat stepWidth = self.stepWidth;
	NSUInteger availableNumberOfSteps = self.values.count;
	if (availableNumberOfSteps == 0) {
		return;
	}
	NSUInteger maximumNumberOfSteps = floorf(boundsWidth / stepWidth);
	NSUInteger fromStep = MAX(availableNumberOfSteps, maximumNumberOfSteps) - maximumNumberOfSteps; 
	
	for (NSUInteger stepOffset = 0; stepOffset < (availableNumberOfSteps - fromStep); stepOffset++) {
		NSUInteger step = fromStep + stepOffset;
		CGFloat offsetX = (fromStep == 0) ?
			(step * stepWidth) :
			(boundsWidth - (availableNumberOfSteps - step) * stepWidth);
		float_t value = ((NSNumber *)self.values[step]).floatValue;
		float_t absValue = fabsf(value);
		if (value != 0.0f) {
			NSArray *colours = (value > 0) ? self.positiveColours : self.negativeColours;
			NSUInteger numberOfBands = colours.count;
			NSUInteger band = ceilf(absValue * (float_t)numberOfBands);
			CGFloat fraction = (absValue - (1.0f / numberOfBands) * (band - 1));
			if (band > 1) {
				[(NSColor *)colours[band - 2] set];
				CGContextFillRect(context, (CGRect){ offsetX, boundsHeight * fraction, stepWidth, boundsHeight * (1.0f - fraction) });
			}
			[(NSColor *)colours[band - 1] set];
			CGContextFillRect(context, (CGRect){ offsetX, 0, stepWidth, boundsHeight * fraction });
		}
	}
}

@end
