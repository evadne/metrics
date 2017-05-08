//
//  DisplayLinkTimeSeriesView.m
//  metrics
//
//  Created by Evadne Wu on 31/12/2016.
//  Copyright © 2016 Radius Development. All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import "DisplayLinkTimeSeriesView.h"

@interface DisplayLinkTimeSeriesView ()
+ (NSMutableSet *) timerTargets;
- (void) tick:(const CVTimeStamp *)outputTime;
+ (NSArray <NSColor *> *) colors;
+ (NSArray *) positiveColors;
+ (NSArray *) negativeColors;

@property (nonatomic, readonly, assign) CGContextRef inContext;
@property (nonatomic, readonly, assign) CGContextRef outContext;
@property (nonatomic, readonly, assign) vImage_Buffer inBuffer;
@property (nonatomic, readonly, assign) vImage_Buffer outBuffer;
@property (nonatomic, readonly, assign) NSUInteger lastTimestamp;
@property (nonatomic, readonly, strong) NSMutableArray<NSNumber *> *values;
@end

static CVReturn DisplayLinkTimeSeriesViewCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext) {
	NSArray *targets = [DisplayLinkTimeSeriesView.timerTargets copy];
	
	dispatch_group_t group = dispatch_group_create();
	for (DisplayLinkTimeSeriesView *target in targets) {
		dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			[target tick:outputTime];
		});
	}
	
	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
	
	dispatch_sync(dispatch_get_main_queue(), ^{
		for (DisplayLinkTimeSeriesView *target in targets) {
			[target setNeedsDisplay:YES];
			[target displayIfNeeded];
		}
	});

	return kCVReturnSuccess;
}

@implementation DisplayLinkTimeSeriesView

- (id) initWithCoder:(NSCoder *)decoder {
	return [[super initWithCoder:decoder] commonInit];
}

- (id) initWithFrame:(CGRect)frame {
	return [[super initWithFrame:frame] commonInit];
}

- (id) commonInit {
	_values = [NSMutableArray array];
	self.wantsLayer = YES;
	self.layer.backgroundColor = [NSColor whiteColor].CGColor;
	self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
		
	__weak typeof(self) wSelf = self; 
	
	[NSNotificationCenter.defaultCenter addObserverForName:NSViewFrameDidChangeNotification object:self queue:nil usingBlock:^(NSNotification * _Nonnull note) {
		[wSelf rebuildBuffers];
	}];
	
	[NSNotificationCenter.defaultCenter addObserverForName:NSViewBoundsDidChangeNotification object:self queue:nil usingBlock:^(NSNotification * _Nonnull note) {
		[wSelf rebuildBuffers];
	}];
	
	return self;
}

- (BOOL) wantsUpdateLayer {
	return YES;
}

- (BOOL) isOpaque {
	return YES;
}

- (void) updateLayer {
	if (_outContext) {
		CGImageRef image = CGBitmapContextCreateImage(_outContext);
		self.layer.contents = (__bridge id)image;
		CGImageRelease(image);
	}
}

- (void) dealloc {
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void) viewWillMoveToSuperview:(NSView *)newSuperview {
	[super viewWillMoveToSuperview:newSuperview];
	if (newSuperview) {
		self.postsFrameChangedNotifications = YES;
		self.postsBoundsChangedNotifications = YES;
		[self.class displayLink];
		[self.class.timerTargets addObject:self];
	} else {
		self.postsFrameChangedNotifications = NO;
		self.postsBoundsChangedNotifications = NO;
		[self.class.timerTargets removeObject:self];
	}
}

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
		CVDisplayLinkSetOutputCallback(displayLink, &DisplayLinkTimeSeriesViewCallback, (__bridge void *)self);
		CVDisplayLinkStart(displayLink);
	});
	
	return displayLink;
}

+ (NSArray <NSColor *> *) colors {
	static dispatch_once_t token;
	static NSArray *colors = nil;
	
	dispatch_once(&token, ^{
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

+ (NSArray *) positiveColors {
	static dispatch_once_t token;
	static NSArray *positiveColors = nil;
	
	dispatch_once(&token, ^{
		NSColor * (^colourFromComponents)(NSUInteger, NSUInteger, NSUInteger) = ^ (NSUInteger red, NSUInteger green, NSUInteger blue) {
			return [NSColor colorWithSRGBRed:(((float_t)red)/256.0f) green:(((float_t)green)/256.0f) blue:(((float_t)blue)/256.0f) alpha:1.0f];
		};
			
		positiveColors = @[
			colourFromComponents(237,248,251),
			colourFromComponents(178,226,226),
			colourFromComponents(102,194,164),
			colourFromComponents(35,139,69)
		];
	});
	return positiveColors;
}

+ (NSArray *) negativeColors {
	static dispatch_once_t token;
	static NSArray *negativeColors = nil;
	
	dispatch_once(&token, ^{
		NSColor * (^colourFromComponents)(NSUInteger, NSUInteger, NSUInteger) = ^ (NSUInteger red, NSUInteger green, NSUInteger blue) {
			return [NSColor colorWithSRGBRed:(((float_t)red)/256.0f) green:(((float_t)green)/256.0f) blue:(((float_t)blue)/256.0f) alpha:1.0f];
		};
			
		negativeColors = @[
			colourFromComponents(241,238,246),
			colourFromComponents(189,201,225),
			colourFromComponents(116,169,207),
			colourFromComponents(5,112,176)
		];
	});
	return negativeColors;
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

- (void) rebuildBuffers {
	CGSize bufferSize = self.bounds.size;
	if (bufferSize.width == 0.0 || bufferSize.height == 0.0) {
		return;
	}
	
	size_t bufferWidth = (size_t)rint(bufferSize.width);
	if (bufferWidth == 0) {
		bufferWidth = 1;
	}
	
	size_t bufferHeight = (size_t)rint(bufferSize.height);
	if (bufferHeight == 0) {
		bufferHeight = 1;
	}
	
	if (_inContext)
		if (CGBitmapContextGetWidth(_inContext) == bufferWidth)
			if (CGBitmapContextGetHeight(_inContext) == bufferHeight)
				if (_outContext)
					if (CGBitmapContextGetWidth(_outContext) == bufferWidth)
						if (CGBitmapContextGetHeight(_outContext) == bufferHeight)
							return;
	
	if (_inContext) {
		CGContextRelease(_inContext);
		_inContext = NULL;
	}
	
	if (_outContext) {
		CGContextRelease(_outContext);
		_outContext = NULL;
	}
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	uint32_t bitmapInfo = kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Big;
	
	_inContext = CGBitmapContextCreate(NULL, bufferWidth, bufferHeight, 8, bufferWidth * 8, colorSpace, bitmapInfo);
	_outContext = CGBitmapContextCreate(NULL, bufferWidth, bufferHeight, 8, bufferWidth * 8, colorSpace, bitmapInfo);
	CGColorSpaceRelease(colorSpace);
	
	_inBuffer = (vImage_Buffer){
		.data = CGBitmapContextGetData(_inContext),
		.width = CGBitmapContextGetWidth(_inContext),
		.height = CGBitmapContextGetHeight(_inContext),
		.rowBytes = CGBitmapContextGetBytesPerRow(_inContext)
	};
	
	_outBuffer = (vImage_Buffer){
		.data = CGBitmapContextGetData(_outContext),
		.width = CGBitmapContextGetWidth(_outContext),
		.height = CGBitmapContextGetHeight(_outContext),
		.rowBytes = CGBitmapContextGetBytesPerRow(_outContext)
	};
}

- (void) tick:(const CVTimeStamp *)outputTime {
	[self fillValue];
	
	if (self.inLiveResize) {
		return;
	}
	
	if (!_inContext || !_outContext) {
		return;
	}
	
	NSUInteger fromTimestamp = self.lastTimestamp;
	NSUInteger toTimestamp = (outputTime->videoTime / outputTime->videoRefreshPeriod);
	NSUInteger maxVisibleSteps = (NSUInteger)ceilf(CGRectGetWidth(self.bounds) / self.stepWidth);
	NSUInteger availableSteps = self.values.count;
	NSUInteger wantedSteps = MIN(MIN(availableSteps, maxVisibleSteps), (toTimestamp - fromTimestamp));
	
	vImage_Buffer tmpBuffer = _inBuffer;
	_inBuffer = _outBuffer;
	_outBuffer = tmpBuffer;
	
	CGContextRef tmpContext = _inContext;
	_inContext = _outContext;
	_outContext = tmpContext;
	
	vImage_CGAffineTransform transform = (vImage_CGAffineTransform){ 1, 0, 0, 1, -1.0f * (float_t)wantedSteps * self.stepWidth, 0.0f };

	static uint8_t backColor[4] = {0};
	static vImage_Flags flags = kvImageBackgroundColorFill;
	vImageAffineWarpCG_ARGB8888(&_inBuffer, &_outBuffer, NULL, &transform, backColor, flags);
	
	CGContextSetFillColorWithColor(_outContext, self.class.colors[toTimestamp % 8].CGColor);
	CGContextFillRect(_outContext, (CGRect){ self.bounds.size.width - (float_t)wantedSteps * self.stepWidth, 0.0f, self.stepWidth, self.bounds.size.height });
	
	_lastTimestamp = toTimestamp;
}

- (CGFloat) stepWidth {
	return 1.0f;
}

@end
