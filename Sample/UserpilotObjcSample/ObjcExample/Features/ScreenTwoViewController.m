//
//  ScreenTwoViewController.m
//  UserpilotObjcSample
//
//  Created by Motasem Hamed on 17/07/2025.
//

#import "ScreenTwoViewController.h"
#import "Userpilot+Shared.h"

@interface ScreenTwoViewController ()

@end

@implementation ScreenTwoViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[Userpilot shared] screen:@"Screen two"];
}

@end
