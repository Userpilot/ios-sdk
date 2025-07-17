//
//  SignInViewController.m
//  UserpilotObjcExample
//
//  Created by Motasem Hamed on 17/07/2025.
//

#import "IdentifyViewController.h"
#import "Userpilot+Shared.h"

@interface IdentifyViewController ()
@property (weak, nonatomic) IBOutlet UITextField *userIDTextField;
@property (weak, nonatomic) IBOutlet UITextField *userKeyTextField;
@property (weak, nonatomic) IBOutlet UITextField *userKeyValueTextField;

@property (weak, nonatomic) IBOutlet UITextField *companyIDTextField;
@property (weak, nonatomic) IBOutlet UITextField *companyKeyTextField;
@property (weak, nonatomic) IBOutlet UITextField *companyKeyValueTextField;

@end

@implementation IdentifyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[Userpilot shared] screen:@"identify"];
}

- (IBAction)identifyTapped:(UIButton *)sender {
    if (_userIDTextField.text == nil || _userIDTextField.text.length == 0) return;
    NSString *userID = _userIDTextField.text;

    NSMutableDictionary<NSString *, NSString *> *properties = [NSMutableDictionary dictionary];
    if (_userKeyTextField.text != nil && _userKeyTextField.text.length != 0 &&
        _userKeyValueTextField.text != nil && _userKeyValueTextField.text.length != 0){
        properties[_userKeyTextField.text] = _userKeyValueTextField.text;
    }

    NSMutableDictionary<NSString *, NSString *> *company = [NSMutableDictionary dictionary];
    
    if (_companyIDTextField.text != nil && _companyIDTextField.text.length != 0) {
        NSString *companyID = _companyIDTextField.text;
        company[@"id"] = companyID;
        if (_companyKeyTextField.text != nil && _companyKeyTextField.text.length != 0 &&
            _companyKeyValueTextField.text != nil && _companyKeyValueTextField.text.length != 0){
            company[_companyKeyTextField.text] = _companyKeyValueTextField.text;
        }
    }

    [[Userpilot shared] identifyWithUserId:userID properties:properties  company:company];

    _userIDTextField.text = nil;
    _userKeyTextField.text = nil;
    _userKeyValueTextField.text = nil;
    _companyIDTextField.text = nil;
    _companyKeyTextField.text = nil;
    _companyKeyValueTextField.text = nil;
}

- (IBAction)signOutTapped:(UIStoryboardSegue *)unwindSegue {
    // Unwind to Sign Out
    [[Userpilot shared] logout];
}

- (IBAction)anonymousUserTapped:(UIButton *)sender {
    [[Userpilot shared] anonymous];
}

@end
