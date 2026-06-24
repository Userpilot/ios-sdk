//
//  UserpilotSafeKVC.h
//  UserpilotObjC
//
//  Reading some accessibility-related keys via `valueForKey:` can raise
//  an Obj-C exception (e.g. recycled list cells whose private getters
//  throw). Exceptions propagating through Swift frames trigger an
//  immediate crash in Swift code.
//
//  This bridge wraps `valueForKey:` in @try/@catch at the Obj-C level so
//  the exception cannot leak into Swift. Callers must restrict probing to
//  PUBLIC getter names only (e.g. `text`, `title`, `currentTitle`) — never
//  underscored / private keys.
//
//  Named with the full `Userpilot` prefix (not a generic `UP`) because
//  Objective-C classes share a single flat process-wide namespace: a
//  shorter prefix risks a duplicate-symbol link error in client apps that
//  (or whose other SDKs) define a same-named class.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UserpilotSafeKVC : NSObject

/// Returns `[obj valueForKey:key]` if the call succeeds, or nil if it raises.
/// Exceptions are caught and silently dropped. Probe PUBLIC getter names only.
+ (nullable id)valueForKey:(NSString *)key onObject:(id)obj;

/// Returns YES if `obj` responds to the selector matching `key` (i.e. the
/// property/method actually exists). Cheap precheck so we don't even
/// attempt valueForKey: on missing keys.
+ (BOOL)object:(id)obj respondsToKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
