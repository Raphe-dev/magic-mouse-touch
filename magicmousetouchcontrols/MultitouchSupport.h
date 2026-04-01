// MultitouchSupport.h
// C type definitions matching Apple's private MultitouchSupport.framework.
// These struct layouts are based on reverse engineering and community documentation,
// verified against macOS 11+. The double field causes 4 bytes of implicit padding
// after `frame` due to 8-byte alignment requirements.

#pragma once
#include <stdint.h>
#include <stddef.h>
#include <CoreFoundation/CoreFoundation.h>

typedef void *MTDeviceRef;

typedef struct {
    float x;
    float y;
} MTPoint;

typedef struct {
    MTPoint position;
    MTPoint velocity;
} MTVector;

// Touch lifecycle stage. Key values: 4 = actively touching, 7 = finger lifted.
typedef int32_t MTPathStage;

typedef struct {
    int32_t    frame;
    double     timestamp;        // 8-byte aligned → 4 bytes implicit padding before this
    int32_t    pathIndex;
    MTPathStage stage;
    int32_t    fingerID;
    int32_t    handID;
    MTVector   normalizedVector; // position + velocity, both in 0..1 range
    float      zTotal;
    float      zPressure;
    float      angle;
    float      majorAxis;
    float      minorAxis;
    MTVector   absoluteVector;   // position + velocity in mm
    int32_t    field14;
    int32_t    field15;
    float      zDensity;
} MTTouch;

// Callback invoked once per display frame with all current touches.
// refCon is the value passed to MTRegisterContactFrameCallbackWithRefcon.
typedef void (*MTFrameCallbackFunction)(
    MTDeviceRef device,
    MTTouch    *touches,
    size_t      numTouches,
    double      timestamp,
    size_t      frame,
    void       *refCon
);
