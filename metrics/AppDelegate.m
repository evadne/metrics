//
//  AppDelegate.m
//  metrics
//
//  Created by Evadne Wu on 21/12/2016.
//  Copyright © 2016 Radius Development. All rights reserved.
//

#import "AppDelegate.h"
#import "DrawRectTimeSeriesView.h"
#import "DoubleLayerTimeSeriesView.h"
#import "DisplayLinkTimeSeriesView.h"
#import "MetalTimeSeriesView.h"
#import "MultiLayerTimeSeriesView.h"
#import "DummyView.h"
#import "RATilingBackgroundView.h"

@interface AppDelegate () <RATilingBackgroundViewDelegate>
@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (CGSize) sizeForTilesInTilingBackgroundView:(RATilingBackgroundView *)tilingBackgroundView {
	return (CGSize) { 128, 30 };
}

- (NSView *) newTileForTilingBackgroundView:(RATilingBackgroundView *)tilingBackgroundView {
#if 1
	return [[MetalTimeSeriesView alloc] initWithFrame:(CGRect){ 0, 0, 128, 30 }];
#endif

#if 0
	return [[MultiLayerTimeSeriesView alloc] initWithFrame:(CGRect){ 0, 0, 120, 30 }];
#endif

#if 0
	return [[DoubleLayerTimeSeriesView alloc] initWithFrame:(CGRect){ 0, 0, 120, 30 }];
#endif

#if 0
	return [[DisplayLinkTimeSeriesView alloc] initWithFrame:(CGRect){ 0, 0, 128, 32 }];
#endif

#if 0
	return [[DrawRectTimeSeriesView alloc] initWithFrame:(CGRect){ 0, 0, 128, 32 }];
#endif

#if 0
	DummyView *newView = [[DummyView alloc] initWithFrame:(CGRect){ 0, 0, 128, 32 }];
	CGFloat red = ((float_t)rand() / (float_t)RAND_MAX);
	CGFloat green = ((float_t)rand() / (float_t)RAND_MAX);
	CGFloat blue = ((float_t)rand() / (float_t)RAND_MAX);	
	newView.backgroundColor = [NSColor colorWithSRGBRed:red green:green blue:blue alpha:1.0f];
	return newView;
#endif

#if 0
	DummyView *newView = [[DummyView alloc] initWithFrame:(CGRect){ 0, 0, 128, 32 }];
	newView.wantsLayer = YES;
	CGFloat red = ((float_t)rand() / (float_t)RAND_MAX);
	CGFloat green = ((float_t)rand() / (float_t)RAND_MAX);
	CGFloat blue = ((float_t)rand() / (float_t)RAND_MAX);	
	newView.layer.backgroundColor = [NSColor colorWithSRGBRed:red green:green blue:blue alpha:1.0f].CGColor;
	return newView;
#endif
}

@end
