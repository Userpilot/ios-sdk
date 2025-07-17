//
//  AppDelegate.m
//  ObjcExample
//
//  Created by Motasem Hamed on 17/07/2025.
//

#import "AppDelegate.h"
@import Userpilot;

@interface AppDelegate ()

@property (strong, nonatomic) Userpilot *userpilot;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


#pragma mark - UserpilotExperienceDelegate

- (void)onExperienceStateChangedWithExperienceType:(UserpilotExperienceType)experienceType
                                      experienceId:(NSNumber *)experienceId
                                   experienceState:(UserpilotExperienceState)experienceState {
    NSLog(@"Experience [%@] type: %ld changed state to: %ld",
          experienceId, (long)experienceType, (long)experienceState);
}

- (void)onExperienceStepStateChangedWithExperienceType:(UserpilotExperienceType)experienceType
                                          experienceId:(NSNumber *)experienceId
                                               stepId:(NSNumber *)stepId
                                            stepState:(UserpilotExperienceState)stepState
                                                 step:(NSNumber *)step
                                           totalSteps:(NSNumber *)totalSteps {
    NSLog(@"Step [%@] of experience [%@] (type: %ld) changed state to: %ld - step %d/%d",
          stepId, experienceId, (long)experienceType, (long)stepState,
          step.intValue, totalSteps.intValue);
}

#pragma mark - UserpilotNavigationDelegate

- (void)navigateTo:(NSURL *)url {
    NSLog(@"Userpilot requested navigation to URL: %@", url.absoluteString);

    // Example: open the URL externally in Safari
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }

    // Or if you want to handle specific URLs in-app, use conditionals here
    // e.g., check url.host or pathComponents
}

#pragma mark - UserpilotAnalyticsDelegate

- (void)didTrackWithAnalytic:(UserpilotAnalytic)analytic
                       value:(NSString *)value
                  properties:(NSDictionary<NSString *, id> *)properties {
    NSLog(@"Tracked event - type: %ld, value: %@, properties: %@", (long)analytic, value, properties);
}


@end
