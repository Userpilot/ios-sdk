//
//  EventsViewController.m
//  UserpilotObjcExample
//
//  Created by Motasem Hamed on 17/07/2025.
//

#import "EventsViewController.h"
#import "Userpilot+Shared.h"

@interface EventsViewController ()

@end

@implementation EventsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [[Userpilot shared] screen:@"events"];
}

- (IBAction)buttonOneTapped:(UIButton *)sender {
    [[Userpilot shared] trackWithEventName:@"event1" properties:@{
        @"demo_key": @"event value"
    }];
}

- (IBAction)buttonTwoTapped:(UIButton *)sender {
    [[Userpilot shared] trackWithEventName:@"event2" properties:nil];
}

@end
