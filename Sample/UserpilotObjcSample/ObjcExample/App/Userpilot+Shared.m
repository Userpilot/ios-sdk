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

        sharedInstance = [[Userpilot alloc] initWithConfig:config];
    }

    return sharedInstance;
}
@end
