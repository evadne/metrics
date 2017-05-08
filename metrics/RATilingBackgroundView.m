//
//  RATilingBackgroundView.m
//  RATilingBackgroundView
//
//  Created by Evadne Wu on 11/6/12.
//  Copyright (c) 2012 Radius. All rights reserved.
//

#import "RATilingBackgroundView.h"

typedef struct RATilePlacement {
	NSUInteger x;
	NSUInteger y;
	CGRect rect;
	__unsafe_unretained NSView *tile;
} RATilePlacement;

@interface RATilingBackgroundView ()
@property (nonatomic, readwrite, assign) RATilePlacement *previousTilePlacements;
@property (nonatomic, readwrite, assign) CGPoint offset;
@property (nonatomic, readonly, strong) NSMutableArray *visibleTiles;
@property (nonatomic, readonly, strong) NSMutableArray *dequeuedTiles;
- (void) reset;
- (void) setUpObservations;
- (void) tearDownObservations;
@end

@implementation RATilingBackgroundView

- (BOOL) isFlipped {
	return YES;
}

- (id) initWithCoder:(NSCoder *)decoder {
	self = [super initWithCoder:decoder];
	if (!self) {
		return nil;
	}
	
	[self commonInit];
	_horizontalStretchingEnabled = [decoder decodeBoolForKey:@"horizontalStretchingEnabled"];
	_verticalStretchingEnabled = [decoder decodeBoolForKey:@"verticalStretchingEnabled"];
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

- (BOOL) wantsDefaultClipping {
	return NO;
}

- (void) commonInit {
	_horizontalStretchingEnabled = YES;
	_verticalStretchingEnabled = NO;
	_offset = CGPointZero;
	_visibleTiles = [NSMutableArray array];
	_dequeuedTiles = [NSMutableArray array];
//	self.layer = [CALayer layer];
//	self.layer.shouldRasterize = YES;
//	self.wantsLayer = YES;
//	self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawNever;
}

- (void) encodeWithCoder:(NSCoder *)coder {
	[super encodeWithCoder:coder];
	[coder encodeBool:_horizontalStretchingEnabled forKey:@"horizontalStretchingEnabled"];
	[coder encodeBool:_verticalStretchingEnabled forKey:@"verticalStretchingEnabled"];
}

- (void) viewWillMoveToSuperview:(NSView *)newSuperview {
	[super viewWillMoveToSuperview:newSuperview];	
	if (self.superview) {
		[self tearDownObservations];
	}
}

- (void) viewDidMoveToSuperview {
	[super viewDidMoveToSuperview];
	[self reset];
	if (self.superview) {
		[self setUpObservations];
		if (!self.subviews.count) {
			[self resizeSubviewsWithOldSize:CGSizeZero];
		}
	}
}

- (void) setDelegate:(id<RATilingBackgroundViewDelegate>)delegate {
	if (_delegate != delegate) {
		_delegate = delegate;
		[self resizeSubviewsWithOldSize:self.frame.size];
	}
}

- (void) resizeSubviewsWithOldSize:(NSSize)oldSize {
	if (!self.delegate) {
		return;
	}
	
	NSCParameterAssert(self.delegate);
	[super resizeSubviewsWithOldSize:oldSize];
	
	if (!(CGRectGetWidth(self.bounds)))
		return;
	
	if (!(CGRectGetHeight(self.bounds)))
		return;
	
	NSPointerArray *unusedVisibleTiles = [NSPointerArray weakObjectsPointerArray];
	for (NSView *visibleTile in self.visibleTiles) {
		[unusedVisibleTiles addPointer:(void *)visibleTile];
	}
	
	NSUInteger tileRectsCount = 0;
	[self getPrimitiveTilingRects:NULL count:&tileRectsCount];
	CGRect * const tileRects = malloc(tileRectsCount * sizeof(CGRect));
	memset(tileRects, 0, tileRectsCount * sizeof(CGRect));
	[self getPrimitiveTilingRects:tileRects count:&tileRectsCount];
	
	NSUInteger const unusedVisibleTilesCount = [unusedVisibleTiles count];
	
	for (NSUInteger tileRectIndex = 0; tileRectIndex < tileRectsCount; tileRectIndex++) {
		CGRect rect = tileRects[tileRectIndex];
		NSCParameterAssert(rect.size.width > 0);
		NSCParameterAssert(rect.size.height > 0);
		NSView *tile = nil;
		
		if (!!unusedVisibleTilesCount && (tileRectIndex <= (unusedVisibleTilesCount - 1))) {
			tile = (NSView *)[unusedVisibleTiles pointerAtIndex:tileRectIndex];
			[unusedVisibleTiles replacePointerAtIndex:tileRectIndex withPointer:NULL];				
		} else {
			tile = [self newTile];
			[self addSubview:tile];
			[self.visibleTiles addObject:tile];			
		}
		tile.frame = rect;
	}
	
	free(tileRects);
	NSArray *leftoverTiles = [unusedVisibleTiles allObjects];
	
	[self.visibleTiles removeObjectsInArray:leftoverTiles];
	[self.dequeuedTiles addObjectsFromArray:leftoverTiles];
	
	for (NSView *unusedVisibleTile in leftoverTiles) {
		[unusedVisibleTile removeFromSuperview];
	}
}

- (CGSize) tileSize {
	CGSize requestedTileSize = [self.delegate sizeForTilesInTilingBackgroundView:self];
	return (CGSize){
		.width = self.horizontalStretchingEnabled ?
			CGRectGetWidth(self.bounds) :
			requestedTileSize.width,
		.height = self.verticalStretchingEnabled ?
			CGRectGetHeight(self.bounds) :
			requestedTileSize.height
	};
}

- (void) getPrimitiveTilingRects:(CGRect *)outRects count:(NSUInteger *)outCount {
	NSCParameterAssert(outCount);
	
	CGSize const tileSize = self.tileSize;
	CGSize const boundsSize = (CGSize){
		.width = CGRectGetWidth(self.bounds),
		.height = CGRectGetHeight(self.bounds)
	};
	
	CGFloat const stepX = tileSize.width;
	CGFloat const fromX = fmodf(self.offset.x, stepX);
	CGFloat const toX = boundsSize.width;
	CGFloat const stepY = tileSize.height;
	CGFloat const fromY = fmodf(self.offset.y, stepY);
	CGFloat const toY = boundsSize.height;
	
	NSUInteger const numberOfTilesX = (NSUInteger)(ceilf(toX / stepX) - floorf(fromX / stepX));
	NSUInteger const numberOfTilesY = (NSUInteger)(ceilf(toY / stepY) - floorf(fromY / stepY));
	NSUInteger const numberOfTiles = numberOfTilesX * numberOfTilesY;
	
	if (outCount) {
		*outCount = numberOfTiles;
	}

	if (!outRects) {
		return;
	}
	
	NSUInteger rectIndex = 0;
	for (NSUInteger indexX = 0; indexX < numberOfTilesX; indexX++) {
		for (NSUInteger indexY = 0; indexY < numberOfTilesY; indexY++) { 
			NSCParameterAssert(rectIndex < numberOfTiles);
			outRects[rectIndex] = (CGRect){
				.origin.x = fromX + indexX * stepX,
				.origin.y = fromY + indexY * stepY,
				.size = tileSize
			};
			rectIndex++;
		}
	}	
}

- (NSView *) newTile {
	NSMutableArray *dequeuedTiles = self.dequeuedTiles;
	NSView *tile = [dequeuedTiles count] ?
		[dequeuedTiles objectAtIndex:0] :
		nil;
	
	if (tile) {
		[dequeuedTiles removeObject:tile];
		return tile;
	} else {
		NSView *newTile = [self.delegate newTileForTilingBackgroundView:self];
		newTile.autoresizingMask = NSViewNotSizable;
		return newTile;
	}
}

- (void) reset {
	self.offset = CGPointZero;
	if (self.delegate) {
		[self resizeSubviewsWithOldSize:self.frame.size];
	}
}

- (void) setUpObservations {
	NSView * const target = self.superview;
	NSKeyValueObservingOptions const options = NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew;
	void * const context = (__bridge void *)self;
	
	NSCParameterAssert(target);
	
	if ([target respondsToSelector:NSSelectorFromString(@"contentOffset")]) {
		[target addObserver:self forKeyPath:@"contentOffset" options:options context:context];	
	}
	
	[target addObserver:self forKeyPath:@"bounds" options:options context:context];
	[target addObserver:self forKeyPath:@"frame" options:options context:context];
}

- (void) tearDownObservations {
	void * const context = (__bridge void *)self;
	NSView * const target = self.superview;
	
	NSCParameterAssert(target);	
	
	if ([target respondsToSelector:NSSelectorFromString(@"contentOffset")]) {
		[target removeObserver:self forKeyPath:@"contentOffset" context:context];
	}
	
	[target removeObserver:self forKeyPath:@"bounds" context:context];
	[target removeObserver:self forKeyPath:@"frame" context:context];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	[self setNeedsLayout:YES];
	if (object == self.superview) {
		if ([keyPath isEqualToString:@"contentOffset"]) {
			CGPoint toContentOffset = [change[NSKeyValueChangeNewKey] CGPointValue];
			CGSize tileSize = [self tileSize];
			self.offset = (CGPoint){
				fmodf(-1 * toContentOffset.x, tileSize.width) -
					(self.horizontalStretchingEnabled ?
						0.0f :
						ceilf(CGRectGetWidth(self.bounds) / tileSize.width) * tileSize.width),
				fmodf(-1 * toContentOffset.y, tileSize.height) -
					(self.verticalStretchingEnabled ?
						0.0f :
						ceilf(CGRectGetHeight(self.bounds) / tileSize.height) * tileSize.height)
			};
		} else {
			self.frame = self.superview.bounds;
		}
	}
}

@end
