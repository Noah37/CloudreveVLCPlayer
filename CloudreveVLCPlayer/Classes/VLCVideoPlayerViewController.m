//
//  VLCVideoPlayerViewController.m
//  CloudreveVLCPlayer
//
//  Created by nongyun.cao on 2023/11/16.
//

#import "VLCVideoPlayerViewController.h"
#import "VLCPlaybackService.h"
#import <Masonry/Masonry.h>

@interface VLCVideoPlayerViewController ()

@property (nonatomic, strong) UIView *videoOutputView;
@property (nonatomic, strong) VLCPlaybackService *playbackService;

@end

@implementation VLCVideoPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view addSubview:self.videoOutputView];
    [self.videoOutputView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.videoOutputView.superview);
    }];
    self.view.backgroundColor = [UIColor blackColor];
    
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"back" style:(UIBarButtonItemStylePlain) target:self action:@selector(dismiss)];
    self.navigationItem.leftBarButtonItem = backItem;
}

- (void)dismiss {
    [self.playbackService stopPlayback];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // The video output view is not initialized when the play as audio option was chosen
    self.playbackService.videoOutputView = self.videoOutputView;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (self.playbackService.videoOutputView == self.videoOutputView) {
        self.playbackService.videoOutputView = nil;
    }
}

- (VLCPlaybackService *)playbackService {
    return [VLCPlaybackService sharedInstance];
}

- (UIView *)videoOutputView {
    if (!_videoOutputView) {
        _videoOutputView = [[UIView alloc] init];
        _videoOutputView.backgroundColor = [UIColor blackColor];
        _videoOutputView.userInteractionEnabled = NO;
        _videoOutputView.translatesAutoresizingMaskIntoConstraints = NO;
        if (@available(iOS 11.0, *)) {
            _videoOutputView.accessibilityIgnoresInvertColors = NO;
        }
        _videoOutputView.accessibilityIdentifier = @"Video Player Title";
        _videoOutputView.accessibilityLabel = NSLocalizedString(@"VO_VIDEOPLAYER_TITLE", comment: @"");
        _videoOutputView.accessibilityHint = NSLocalizedString(@"VO_VIDEOPLAYER_DOUBLETAP",    comment: @"");
    }
    return _videoOutputView;
}

@end
