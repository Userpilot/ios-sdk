//
//  UserpilotSafeAccessibility.h
//  UserpilotObjC
//
//  Exception-guarded wrappers around the PUBLIC UIAccessibility API
//  (the UIAccessibilityContainer informal protocol and the standard
//  element attributes).
//
//  Everything called here is documented, App Store-safe API — no
//  private selectors, no NSInvocation tricks, no dlopen/dlsym. The
//  guards exist because accessibility getters on recycled or
//  transient elements (list cells mid-reuse, detached SwiftUI nodes)
//  can raise ObjC exceptions, and an ObjC exception crossing into
//  Swift frames is undefined behavior. Every accessor:
//    1. prechecks `respondsToSelector:`,
//    2. wraps the call in @try/@catch,
//    3. soft-fails to a neutral value (nil / 0 / CGRectNull).
//
//  Named with the full `Userpilot` prefix (not a generic `UP`) because
//  Objective-C classes share a single flat process-wide namespace: a
//  shorter prefix risks a duplicate-symbol link error in client apps.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UserpilotSafeAccessibility : NSObject

/// `[object isAccessibilityElement]`, guarded. NO on failure.
+ (BOOL)isAccessibilityElementOnObject:(id)object
    NS_SWIFT_NAME(isAccessibilityElement(on:));

/// `[object accessibilityElementCount]`, guarded. 0 on failure.
+ (NSInteger)elementCountOnObject:(id)object
    NS_SWIFT_NAME(elementCount(on:));

/// `[object accessibilityElementAtIndex:index]`, guarded.
+ (nullable id)elementAtIndex:(NSInteger)index onObject:(id)object
    NS_SWIFT_NAME(element(at:on:));

/// `[object accessibilityElements]`, guarded.
+ (nullable NSArray *)accessibilityElementsOfObject:(id)object
    NS_SWIFT_NAME(accessibilityElements(of:));

/// `[object accessibilityFrame]` (screen coordinates), guarded.
/// CGRectNull on failure.
+ (CGRect)accessibilityFrameOfObject:(id)object
    NS_SWIFT_NAME(accessibilityFrame(of:));

/// `[object accessibilityTraits]`, guarded. 0 (no traits) on failure.
+ (UIAccessibilityTraits)accessibilityTraitsOfObject:(id)object
    NS_SWIFT_NAME(accessibilityTraits(of:));

/// `[object accessibilityLabel]`, guarded.
+ (nullable NSString *)accessibilityLabelOfObject:(id)object
    NS_SWIFT_NAME(accessibilityLabel(of:));

/// `[object accessibilityValue]`, guarded.
+ (nullable NSString *)accessibilityValueOfObject:(id)object
    NS_SWIFT_NAME(accessibilityValue(of:));

/// `[object accessibilityHint]`, guarded.
+ (nullable NSString *)accessibilityHintOfObject:(id)object
    NS_SWIFT_NAME(accessibilityHint(of:));

/// `[object accessibilityIdentifier]` (UIAccessibilityIdentification),
/// guarded.
+ (nullable NSString *)accessibilityIdentifierOfObject:(id)object
    NS_SWIFT_NAME(accessibilityIdentifier(of:));

@end

NS_ASSUME_NONNULL_END
