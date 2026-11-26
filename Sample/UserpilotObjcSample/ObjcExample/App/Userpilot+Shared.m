//
//  Userpilot+Shared.m
//  UserpilotObjcExample
//
//  Created by Motasem Hamed on 17/07/2025.
//

#import "Userpilot+Shared.h"

static Userpilot *sharedInstance = nil;

@implementation Userpilot (Shared)

+ (Userpilot *)shared
{
    if (sharedInstance == nil) {
        Config *config = [[Config alloc] initWithToken:@"<#TOKEN#>"];
        [config loggingWithEnabled:YES];
        // Native SwiftUI hosts may opt in with YES before initialization. Default remains NO.
        [config enableScreenClassIdentity:NO];

        sharedInstance = [[Userpilot alloc] initWithConfig:config];
    }

    return sharedInstance;
}
@end
