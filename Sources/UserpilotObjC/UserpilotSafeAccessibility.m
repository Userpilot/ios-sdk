//
//  UserpilotSafeAccessibility.m
//  UserpilotObjC
//

#import "UserpilotSafeAccessibility.h"

@implementation UserpilotSafeAccessibility

+ (BOOL)isAccessibilityElementOnObject:(id)object {
    if (object == nil) return NO;
    if (![object respondsToSelector:@selector(isAccessibilityElement)]) return NO;
    @try {
        return [object isAccessibilityElement];
    } @catch (NSException *e) {
        return NO;
    } @catch (...) {
        return NO;
    }
}

+ (NSInteger)elementCountOnObject:(id)object {
    if (object == nil) return 0;
    if (![object respondsToSelector:@selector(accessibilityElementCount)]) return 0;
    @try {
        return [object accessibilityElementCount];
    } @catch (NSException *e) {
        return 0;
    } @catch (...) {
        return 0;
    }
}

+ (nullable id)elementAtIndex:(NSInteger)index onObject:(id)object {
    if (object == nil || index < 0) return nil;
    if (![object respondsToSelector:@selector(accessibilityElementAtIndex:)]) return nil;
    @try {
        return [object accessibilityElementAtIndex:index];
    } @catch (NSException *e) {
        return nil;
    } @catch (...) {
        return nil;
    }
}

+ (nullable NSArray *)accessibilityElementsOfObject:(id)object {
    if (object == nil) return nil;
    if (![object respondsToSelector:@selector(accessibilityElements)]) return nil;
    @try {
        id raw = [object accessibilityElements];
        return [raw isKindOfClass:[NSArray class]] ? raw : nil;
    } @catch (NSException *e) {
        return nil;
    } @catch (...) {
        return nil;
    }
}

+ (CGRect)accessibilityFrameOfObject:(id)object {
    if (object == nil) return CGRectNull;
    if (![object respondsToSelector:@selector(accessibilityFrame)]) return CGRectNull;
    @try {
        return [object accessibilityFrame];
    } @catch (NSException *e) {
        return CGRectNull;
    } @catch (...) {
        return CGRectNull;
    }
}

+ (UIAccessibilityTraits)accessibilityTraitsOfObject:(id)object {
    if (object == nil) return UIAccessibilityTraitNone;
    if (![object respondsToSelector:@selector(accessibilityTraits)]) return UIAccessibilityTraitNone;
    @try {
        return [object accessibilityTraits];
    } @catch (NSException *e) {
        return UIAccessibilityTraitNone;
    } @catch (...) {
        return UIAccessibilityTraitNone;
    }
}

+ (nullable NSString *)accessibilityLabelOfObject:(id)object {
    return [self up_stringFromSelector:@selector(accessibilityLabel) onObject:object];
}

+ (nullable NSString *)accessibilityValueOfObject:(id)object {
    return [self up_stringFromSelector:@selector(accessibilityValue) onObject:object];
}

+ (nullable NSString *)accessibilityHintOfObject:(id)object {
    return [self up_stringFromSelector:@selector(accessibilityHint) onObject:object];
}

+ (nullable NSString *)accessibilityIdentifierOfObject:(id)object {
    return [self up_stringFromSelector:@selector(accessibilityIdentifier) onObject:object];
}

#pragma mark - Private

+ (nullable NSString *)up_stringFromSelector:(SEL)selector onObject:(id)object {
    if (object == nil) return nil;
    if (![object respondsToSelector:selector]) return nil;
    @try {
        IMP imp = [object methodForSelector:selector];
        id (*getter)(id, SEL) = (id (*)(id, SEL))imp;
        id raw = getter(object, selector);
        return [raw isKindOfClass:[NSString class]] ? raw : nil;
    } @catch (NSException *e) {
        return nil;
    } @catch (...) {
        return nil;
    }
}

@end
