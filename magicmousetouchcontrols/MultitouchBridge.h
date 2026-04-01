// MultitouchBridge.h
// Objective-C wrapper that loads Apple's private MultitouchSupport.framework
// at runtime via dlopen and registers touch callbacks for all external devices
// (i.e. Magic Mouse, excluding the built-in MacBook trackpad when present).

#pragma once
#import <Foundation/Foundation.h>
#import "MultitouchSupport.h"

NS_ASSUME_NONNULL_BEGIN

// Block called on the main thread once per display frame.
// `touches` may be NULL when count == 0 (all fingers lifted).
typedef void (^MTFrameBlock)(const MTTouch * _Nullable touches, NSInteger count, double timestamp);

@interface MultitouchBridge : NSObject

+ (instancetype)shared;

/// Load the private framework and register callbacks on all external MT devices.
/// Returns YES if at least one device was found and started.
- (BOOL)startWithCallback:(MTFrameBlock)callback;

/// Unregister callbacks and stop processing. Can be restarted.
- (void)stop;

@property (nonatomic, readonly, getter=isRunning) BOOL running;

@end

NS_ASSUME_NONNULL_END
