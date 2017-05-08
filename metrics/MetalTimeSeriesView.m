//
//  MetalTimeSeriesView.m
//  metrics
//
//  Created by Evadne Wu on 01/01/2017.
//  Copyright © 2017 Radius Development. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "MetalTimeSeriesView.h"

typedef struct {
	vector_float2 position;
	vector_short3 color;
} MTSVertex;

static vector_short3 positiveColors[4] = (vector_short3[]){
	{ 237, 248, 251 },
	{ 178, 226, 226 },
	{ 102, 194, 164 },
	{ 35, 139, 69 }
};

static vector_short3 negativeColors[4] = (vector_short3[]){
	{ 241, 238, 246 },
	{ 189, 201, 225 },
	{ 116,169, 207 },
	{ 5, 112, 176 }
};

NS_INLINE int bandNumberForValue (float_t value) {
	return (value >= .75f) ? 4 :
		(value >= .5f) ? 3 :
		(value >= .25f) ? 2 :
		(value > 0) ? 1 :
		(value == 0) ? 0 :
		(value > -.25f) ? -1 :
		(value > -.5f) ? -2 :
		(value > -.75f) ? -3 :
		-4;
}

NS_INLINE float_t nextValue (float_t value) {
	return MAX(-1.0f, MIN(1.0f, (value + (0.06f * ((float)rand()/(float)RAND_MAX) - 0.03f))));
}

@interface MetalTimeSeriesView ()
+ (NSMutableSet *) timerTargets;
+ (void) setupDisplayLink;
- (void) tick:(const CVTimeStamp *)outputTime;
@property (nonatomic, readonly, assign) BOOL hasRendered;
@property (nonatomic, readonly, assign) float_t *values;
@property (nonatomic, readonly, assign) size_t numberOfValues;
@property (nonatomic, readonly, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, readonly, strong) id<MTLRenderPipelineState> renderPipeline;
@end

static CVReturn MetalTimeSeriesViewCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext) {
	static BOOL isRendering = NO;
	if (isRendering)
		return kCVReturnRetry;
	
	//	static CFTimeInterval lastRenderTime = 0;
	//	CFTimeInterval nowRenderTime = CACurrentMediaTime();
	//	if ((lastRenderTime >= 0) && ((nowRenderTime - lastRenderTime) < 1.0f/60.0f)) // cap to 60FPS, 30FPS, 20FPS, …
	//		return kCVReturnRetry;

	isRendering = YES;
	dispatch_async(dispatch_get_main_queue(), ^{
		NSArray *targets = [MetalTimeSeriesView.timerTargets copy];
		for (MetalTimeSeriesView *target in targets) {
			[target tick:outputTime];
			[target setNeedsDisplay:YES];
		}
		//	lastRenderTime = nowRenderTime;
		isRendering = NO;
	});
	
	return kCVReturnSuccess;
}

@implementation MetalTimeSeriesView

+ (NSMutableSet *) timerTargets {
	static NSMutableSet *timerTargets = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		timerTargets = [NSMutableSet set]; 
	});
	
	return timerTargets;
}

+ (void) setupDisplayLink {
	static CVDisplayLinkRef displayLink = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
		CVDisplayLinkSetOutputCallback(displayLink, &MetalTimeSeriesViewCallback, (__bridge void *)self);

 		CVDisplayLinkStart(displayLink);
		
		for (NSString *notificationName in @[
			NSWindowWillMoveNotification,
			NSWindowWillStartLiveResizeNotification,
			NSWindowWillEnterFullScreenNotification,
			NSWindowWillEnterVersionBrowserNotification
		]) {
			[NSNotificationCenter.defaultCenter addObserverForName:notificationName object:nil queue:nil usingBlock:^(NSNotification *note) { CVDisplayLinkStop(displayLink); }];
		};
		
		for (NSString *notificationName in @[
			NSWindowDidMoveNotification,
			NSWindowDidEndLiveResizeNotification,
			NSWindowDidExitFullScreenNotification,
			NSWindowDidExitVersionBrowserNotification
		]) {
			[NSNotificationCenter.defaultCenter addObserverForName:notificationName object:nil queue:nil usingBlock:^(NSNotification *note) { CVDisplayLinkStart(displayLink); }];
		};
						
		[NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidChangeOcclusionStateNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
			BOOL hasVisibleTargets = NO;
			for (NSView *view in self.timerTargets) {
				if (view.window.occlusionState & NSWindowOcclusionStateVisible) {
					hasVisibleTargets = YES;
					break;
				}
			}
			
			if (hasVisibleTargets) {
				CVDisplayLinkStart(displayLink);
			} else {
				CVDisplayLinkStop(displayLink);
			}
		}];
	});
}

- (void) tick:(const CVTimeStamp *)outputTime {
	for (size_t i = 0; i < (_numberOfValues - 1); i++) {
		_values[i] = _values[i+1];
	}
	_values[_numberOfValues - 1] = nextValue(_values[_numberOfValues - 2]); 
	[self updateVertexBuffer];
}

- (void) viewWillMoveToSuperview:(NSView *)newSuperview {
	_hasRendered = NO;
	[super viewWillMoveToSuperview:newSuperview];
	if (!newSuperview) {
		[self.class.timerTargets removeObject:self];
	}
}

- (id) initWithCoder:(NSCoder *)decoder {
	return [[super initWithCoder:decoder] commonInit];
}

- (id) initWithFrame:(CGRect)frame {
	return [[super initWithFrame:frame] commonInit];
}

+ (id <MTLDevice>) preferredDevice {
	NSArray <id <MTLDevice>> *devices = MTLCopyAllDevices();
	for (id <MTLDevice> device in devices) {
		if (device.lowPower) {
			return device;
		}
	}
	
	return MTLCreateSystemDefaultDevice();
}

+ (id <MTLCommandQueue>) preferredCommandQueue {
	static dispatch_once_t onceToken;
	static id<MTLCommandQueue> commandQueue;
	dispatch_once(&onceToken, ^{
		commandQueue = [[self preferredDevice] newCommandQueue]; // WithMaxCommandBufferCount:100
	});
	return commandQueue;
}

+ (id <MTLRenderPipelineState>) preferredRenderPipeline {
	static dispatch_once_t onceToken;
	static id <MTLRenderPipelineState> renderPipeline;
	dispatch_once(&onceToken, ^{
		id <MTLDevice> device = [self preferredDevice];
		id <MTLLibrary> library = [device newDefaultLibrary];
		MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
		pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"vertex_main"]; 
		pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"fragment_main"];
		pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;	
		renderPipeline = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor
error:NULL];
	});
	return renderPipeline;
}

- (void) updateVertexBuffer {
	[self updateVertexBufferFromIndex:0 toIndex:(_numberOfValues - 1)];
}

- (void) updateVertexBufferFromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
	MTSVertex *vertices = (MTSVertex *)_vertexBuffer.contents;
	float_t minX = -1.0f, maxX = 1.0f, minY = -1.0f, maxY = 1.0f;
	float_t stepX = (maxX - minX) / (float_t)_numberOfValues;
	
	NSCParameterAssert(fromIndex >= 0);
	NSCParameterAssert(toIndex > fromIndex);
	NSCParameterAssert(toIndex < _numberOfValues);
	
	for (size_t i = fromIndex; i <= toIndex; i++) {
		float_t const value = _values[i];
		
		BOOL const isOnBandBoundary = fmodf(fabsf(value), 0.25f) == 0.0f;
		BOOL const isPositive = (value > 0.0f);
		BOOL const isNegative = (value < 0.0f);
		
		float_t fromX = minX + (float_t)i * stepX;
		float_t toX = fromX + stepX;
		float_t midY = isOnBandBoundary ? 0.0f :
			isPositive ?
				(minY + (maxY - minY) * (fmodf(value, 0.25f) / 0.25f)) :
				(maxY - (maxY - minY) * (fmodf(fabsf(value), 0.25f) / 0.25f));
		
		int bandNumber = bandNumberForValue(value);
		int bandIndex = abs(bandNumber) - 1;
		NSCParameterAssert(minY <= midY && midY <= maxY);
		NSCParameterAssert(-4 <= bandNumber && bandNumber <= 4);
		NSCParameterAssert((!isPositive && !isNegative) || ((0 < abs(bandNumber) && abs(bandNumber) <= 4)));
		
		vector_short3 topColor = { 255, 255, 255 };
		vector_short3 bottomColor = { 255, 255, 255 };
		
		if (isPositive) {
			bottomColor = positiveColors[bandIndex];
			if (bandIndex) {
				topColor = isOnBandBoundary ? bottomColor : positiveColors[bandIndex - 1];
			}
		} else if (isNegative) {
			topColor = negativeColors[bandIndex];
			if (bandIndex) {
				bottomColor = isOnBandBoundary ? topColor : negativeColors[bandIndex - 1];
			}
		}
		
		size_t offset = 8 * i;
		vertices[offset + 0] = (MTSVertex){ (vector_float2){ toX, maxY }, topColor };
		vertices[offset + 1] = (MTSVertex){ (vector_float2){ toX, midY }, topColor };
		vertices[offset + 2] = (MTSVertex){ (vector_float2){ fromX, maxY }, topColor };
		vertices[offset + 3] = (MTSVertex){ (vector_float2){ fromX, midY }, topColor };
		vertices[offset + 4] = (MTSVertex){ (vector_float2){ toX, midY }, bottomColor };
		vertices[offset + 5] = (MTSVertex){ (vector_float2){ toX, minY }, bottomColor };
		vertices[offset + 6] = (MTSVertex){ (vector_float2){ fromX, midY }, bottomColor };
		vertices[offset + 7] = (MTSVertex){ (vector_float2){ fromX, minY }, bottomColor };
	}
}

- (id) commonInit {
	self.device = self.class.preferredDevice;
	self.paused = YES;
	self.enableSetNeedsDisplay = YES;
	self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
	
	_numberOfValues = 128;
	_values = malloc(_numberOfValues * sizeof(float_t));
	_values[0] = (2.0f * ((float_t)rand()/(float_t)RAND_MAX) - 1.0f);
	for (size_t i = 1; i < _numberOfValues; i++) {
		_values[i] = nextValue(_values[i - 1]); 
	}
	
	NSUInteger bufferSize = sizeof(MTSVertex) * 4 * 2 * _numberOfValues;
	_vertexBuffer = [self.device newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
	_renderPipeline = [self.class preferredRenderPipeline];
	
	[self.class setupDisplayLink];
	[self updateVertexBuffer];
	
	return self;
}

- (void) drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
	[self render];
	if (!_hasRendered) {
		_hasRendered = YES;
		[self.class.timerTargets addObject:self];
	}
}

- (void) render {
	MTLRenderPassDescriptor *currentRenderPassDescriptor = self.currentRenderPassDescriptor;
	if (!currentRenderPassDescriptor)
		return;
	
	id <MTLCommandBuffer> commandBuffer = [self.class.preferredCommandQueue commandBufferWithUnretainedReferences];
	id <MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:currentRenderPassDescriptor];
	
	[renderCommandEncoder setRenderPipelineState:_renderPipeline];
	[renderCommandEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
	for (size_t i = 0; i < _numberOfValues; i++) {
		[renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:(8 * i) vertexCount:4];
		[renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:(8 * i) + 4 vertexCount:4];
	}
	
	[renderCommandEncoder endEncoding];
	[commandBuffer presentDrawable:self.currentDrawable];
	[commandBuffer commit];
}

@end
