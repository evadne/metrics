//
//  RATilingBackgroundView.h
//  RATilingBackgroundView
//
//  Created by Evadne Wu on 11/6/12.
//  Copyright (c) 2012 Radius. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RATilingBackgroundViewDelegate.h"

@interface RATilingBackgroundView : NSView

@property (nonatomic, readwrite, assign) BOOL horizontalStretchingEnabled;	//	YES
@property (nonatomic, readwrite, assign) BOOL verticalStretchingEnabled;	//	NO
@property (nonatomic, readwrite, weak) IBOutlet id<RATilingBackgroundViewDelegate> delegate;

@end
