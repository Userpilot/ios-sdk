//
//  MainViewController.m
//  UserpilotObjcSample
//
//  Created by Motasem Hamed on 17/07/2025.
//

#import "MainViewController.h"
#import "Userpilot+Shared.h"

@interface MainViewController ()

@end

@implementation MainViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[Userpilot shared] screen:@"main"];
}

- (IBAction)debugTapped:(UIButton *)sender {
    // Host singleton from Userpilot+Shared, not the SDK registry default.
    [[Userpilot shared] debug];
}

@end
