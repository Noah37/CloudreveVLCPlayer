//
//  VLCViewController.m
//  CloudreveVLCPlayer
//
//  Created by nongyun.cao on 11/16/2023.
//  Copyright (c) 2023 nongyun.cao. All rights reserved.
//

#import "VLCViewController.h"
#import "VLCPlayerDisplayController.h"
#import <CloudreveVLCPlayer/VLCPlaybackService.h>
#import <MobileVLCKit/VLCMedia.h>
#import <MobileVLCKit/VLCMediaList.h>

@interface VLCViewController ()
@property (weak, nonatomic) IBOutlet UITextField *URLTextField;

@end

@implementation VLCViewController

- (IBAction)play:(id)sender {

    NSString *url = self.URLTextField.text;
    VLCMedia *media = [VLCMedia mediaWithURL:[NSURL URLWithString:url]];
    VLCMediaList *medialist = [[VLCMediaList alloc] init];
    [medialist addMedia:media];
    [[VLCPlaybackService sharedInstance] playMediaList:medialist firstIndex:0 subtitlesFilePath:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    VLCPlayerDisplayController *displayVC = [[VLCPlayerDisplayController alloc] init];
    displayVC.view.layoutMargins = UIEdgeInsetsMake(0, 0, 0, 0);
    [self.view addSubview:displayVC.view];
    [displayVC didMoveToParentViewController:self];
    
    self.URLTextField.text = @"http://192.168.101.5:4778/api/v3/file/download/KkHUWNB7MXrZT1nD?sign=AkloyHxHfYRjlmVZVA3ffwVj0hFaa_-KmobnA1BSr4Q%3D%3A1700108758";
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
