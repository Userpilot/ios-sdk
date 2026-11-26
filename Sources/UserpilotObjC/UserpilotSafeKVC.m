//
//  UserpilotSafeKVC.m
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Guards native key-value reads against Objective-C exceptions before returning results to Swift.
//

#import "UserpilotSafeKVC.h"
#import <objc/runtime.h>

@implementation UserpilotSafeKVC

+ (nullable id)valueForKey:(NSString *)key onObject:(id)obj {
    if (obj == nil || key.length == 0) return nil;

    // Precheck: does this object actually have the property?
    // Avoids raising NSUnknownKeyException for missing keys.
    if (![self object:obj respondsToKey:key]) return nil;

    id result = nil;
    @try {
        result = [obj valueForKey:key];
    } @catch (NSException *exception) {
        // Swallow the exception here at the Obj-C boundary so it can't
        // propagate into Swift (which would crash).
        return nil;
    } @catch (...) {
        return nil;
    }
    return result;
}

+ (BOOL)object:(id)obj respondsToKey:(NSString *)key {
    if (obj == nil || key.length == 0) return NO;

    SEL getter = NSSelectorFromString(key);
    if ([obj respondsToSelector:getter]) return YES;

    // KVC also accepts `is<Key>` and `_<key>` patterns, but we deliberately
    // do NOT support those — they tend to be private accessors, exactly
    // the surface that tends to throw.
    return NO;
}

@end
