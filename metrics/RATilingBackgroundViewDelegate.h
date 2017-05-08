//
//  RATilingBackgroundViewDelegate.h
//  RATilingBackgroundView
//
//  Created by Evadne Wu on 11/6/12.
//  Copyright (c) 2012 Radius. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RATilingBackgroundView;
@protocol RATilingBackgroundViewDelegate <NSObject>

- (CGSize) sizeForTilesInTilingBackgroundView:(RATilingBackgroundView *)tilingBackgroundView;
- (NSView *) newTileForTilingBackgroundView:(RATilingBackgroundView *)tilingBackgroundView;

@end
