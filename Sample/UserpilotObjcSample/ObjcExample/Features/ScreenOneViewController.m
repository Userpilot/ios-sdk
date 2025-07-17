//
//  ProfileViewController.m
//  UserpilotObjcExample
//
//  Created by Motasem Hamed on 17/07/2025.
//

#import "ScreenOneViewController.h"
#import "Userpilot+Shared.h"
#import "IdentifyViewController.h"

@interface ScreenOneViewController ()
@property (weak, nonatomic) IBOutlet UITextField *givenNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *familyNameTextField;

@end

@implementation ScreenOneViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [[Userpilot shared] screen:@"screen one"];
}

@end
