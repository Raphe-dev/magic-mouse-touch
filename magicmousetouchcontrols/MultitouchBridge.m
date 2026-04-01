// MultitouchBridge.m
#import "MultitouchBridge.h"
#import <dlfcn.h>
#import <QuartzCore/QuartzCore.h>   // CACurrentMediaTime

// ---------------------------------------------------------------------------
// Private framework function types (loaded via dlsym)
// ---------------------------------------------------------------------------

typedef CFArrayRef (*MTDeviceCreateListFunc)(void);
typedef void       (*MTRegisterCallbackRefconFunc)(MTDeviceRef, MTFrameCallbackFunction, void *);
typedef int32_t    (*MTDeviceStartFunc)(MTDeviceRef, int32_t);
typedef void       (*MTDeviceStopFunc)(MTDeviceRef);
typedef bool       (*MTDeviceIsBuiltInFunc)(MTDeviceRef);

// ---------------------------------------------------------------------------

@interface MultitouchBridge () {
    void             *_framework;
    MTDeviceStopFunc  _MTDeviceStop;
    NSMutableArray   *_deviceValues;        // NSValue-wrapped MTDeviceRef

    // Frame-throttling state (accessed only on the MT callback thread)
    NSInteger         _prevTouchCount;      // last dispatched touch count
    CFTimeInterval    _lastIntermediateT;   // wall time of last intermediate dispatch
}
@property (nonatomic, copy)   MTFrameBlock onFrame;
@property (nonatomic, assign, readwrite, getter=isRunning) BOOL running;

- (void)handleTouches:(const MTTouch *)touches
                count:(NSInteger)count
            timestamp:(double)timestamp;
@end

// ---------------------------------------------------------------------------
// Global C callback — must be after the @interface so the selector is visible.
// ---------------------------------------------------------------------------

static void frameworkCallback(MTDeviceRef device,
                               MTTouch    *touches,
                               size_t      numTouches,
                               double      timestamp,
                               size_t      frame,
                               void       *refCon) {
    MultitouchBridge *bridge = (__bridge MultitouchBridge *)refCon;
    [bridge handleTouches:touches count:(NSInteger)numTouches timestamp:timestamp];
}

// ---------------------------------------------------------------------------

@implementation MultitouchBridge

+ (instancetype)shared {
    static MultitouchBridge *instance = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ instance = [MultitouchBridge new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _deviceValues   = [NSMutableArray new];
        _prevTouchCount = -1;
    }
    return self;
}

- (BOOL)startWithCallback:(MTFrameBlock)callback {
    if (_running) return YES;

    _framework = dlopen(
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
        RTLD_NOW | RTLD_GLOBAL
    );
    if (!_framework) {
#if DEBUG
        NSLog(@"[MultitouchBridge] dlopen failed: %s", dlerror());
#endif
        return NO;
    }

    MTDeviceCreateListFunc    createList  = (MTDeviceCreateListFunc)dlsym(_framework, "MTDeviceCreateList");
    MTRegisterCallbackRefconFunc registerCB = (MTRegisterCallbackRefconFunc)dlsym(_framework, "MTRegisterContactFrameCallbackWithRefcon");
    MTDeviceStartFunc         startDevice = (MTDeviceStartFunc)dlsym(_framework, "MTDeviceStart");
    MTDeviceIsBuiltInFunc     isBuiltIn   = (MTDeviceIsBuiltInFunc)dlsym(_framework, "MTDeviceIsBuiltIn");
    _MTDeviceStop                         = (MTDeviceStopFunc)dlsym(_framework, "MTDeviceStop");

    if (!createList || !registerCB || !startDevice) {
#if DEBUG
        NSLog(@"[MultitouchBridge] Required symbols not found");
#endif
        dlclose(_framework); _framework = NULL;
        return NO;
    }

    CFArrayRef deviceList = createList();
    if (!deviceList) {
#if DEBUG
        NSLog(@"[MultitouchBridge] MTDeviceCreateList returned NULL");
#endif
        dlclose(_framework); _framework = NULL;
        return NO;
    }

    self.onFrame = callback;
    CFIndex count = CFArrayGetCount(deviceList);

    for (CFIndex i = 0; i < count; i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(deviceList, i);
        if (isBuiltIn && isBuiltIn(device)) continue;   // skip MacBook trackpad
        registerCB(device, frameworkCallback, (__bridge void *)self);
        startDevice(device, 0);
        [_deviceValues addObject:[NSValue valueWithPointer:device]];
#if DEBUG
        NSLog(@"[MultitouchBridge] Started external device %ld", (long)i);
#endif
    }

    CFRelease(deviceList);
    _running = YES;
    return YES;
}

- (void)stop {
    if (!_running) return;
    if (_MTDeviceStop) {
        for (NSValue *val in _deviceValues) {
            _MTDeviceStop((MTDeviceRef)val.pointerValue);
        }
    }
    [_deviceValues removeAllObjects];
    self.onFrame = nil;
    _running = NO;
}

// ---------------------------------------------------------------------------
// Called on the MT framework's internal high-priority thread at ~60 fps
// while finger(s) are on the mouse.
//
// Performance strategy — two tiers:
//  • Count-change frames (touch start / lift): always dispatch. These are
//    rare (2 per gesture) and carry the information we actually act on.
//  • Intermediate frames (fingers still down, same count): throttled to
//    ~20 fps (50 ms gate). We only need these to detect scroll movement;
//    20 fps is more than enough and reduces allocations ~3×.
// ---------------------------------------------------------------------------

#define INTERMEDIATE_INTERVAL 0.05   // seconds between intermediate dispatches (~20 fps)

- (void)handleTouches:(const MTTouch *)touches
                count:(NSInteger)count
            timestamp:(double)timestamp {
    MTFrameBlock block = self.onFrame;
    if (!block) return;

    BOOL countChanged = (count != _prevTouchCount);
    _prevTouchCount   = count;

    if (!countChanged && count > 0) {
        // Intermediate frame — throttle to ~20 fps.
        CFTimeInterval now = CACurrentMediaTime();
        if ((now - _lastIntermediateT) < INTERMEDIATE_INTERVAL) return;
        _lastIntermediateT = now;
    } else {
        _lastIntermediateT = CACurrentMediaTime();
    }

    // Copy touch structs to heap; the source pointer is only valid during
    // this callback invocation (stack memory on the MT framework thread).
    NSData *snapshot = (count > 0 && touches)
        ? [NSData dataWithBytes:touches length:(NSUInteger)(count * sizeof(MTTouch))]
        : nil;

    NSInteger capturedCount = count;
    double    capturedTime  = timestamp;

    dispatch_async(dispatch_get_main_queue(), ^{
        const MTTouch *ptr = snapshot ? (const MTTouch *)snapshot.bytes : NULL;
        block(ptr, capturedCount, capturedTime);
    });
}

@end
