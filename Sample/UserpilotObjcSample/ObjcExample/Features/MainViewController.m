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

- (void)viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *debuggerButton = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"ladybug"]
        style:UIBarButtonItemStylePlain target:self action:@selector(debugTapped:)];
    debuggerButton.accessibilityLabel = @"Open debugger";
    self.navigationItem.rightBarButtonItem = debuggerButton;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[Userpilot shared] screen:@"main"];
}

- (void)debugTapped:(id)sender {
    // Host singleton from Userpilot+Shared, not the SDK registry default.
    [[Userpilot shared] debug];
}

@end
