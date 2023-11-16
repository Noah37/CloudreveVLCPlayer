//
//  VLCPlayerDisplayController.m
//  CloudreveVLCPlayer
//
//  Created by nongyun.cao on 2023/11/16.
//

#import "VLCPlayerDisplayController.h"
#import "VLCPlaybackService.h"
#import <MobileVLCKit/VLCMedia.h>
#import <VLCMediaLibraryKit/VLCMLMedia.h>
#import "VLCPlaybackNavigationController.h"
#import "VLCVideoPlayerViewController.h"

@interface VLCUntouchableView: UIView
@end

@implementation VLCUntouchableView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *result = [super hitTest:point withEvent:event];
    return result == self ? nil : result;
}

@end

@interface VLCPlayerDisplayController ()<VLCVideoPlayerViewControllerDelegate>

@property (nonatomic, weak, nullable) VLCPlaybackService *playbackController;
@property (nonatomic, strong) UIViewController *movieViewController;
@property (nonatomic, strong) UIViewController *videoPlayerViewController;

@end

@implementation VLCPlayerDisplayController

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(playbackDidStart:) name:VLCPlaybackServicePlaybackDidStart object:nil];
        [notificationCenter addObserver:self selector:@selector(playbackDidFail:) name:VLCPlaybackServicePlaybackDidFail object:nil];
        [notificationCenter addObserver:self selector:@selector(playbackDidStop:) name:VLCPlaybackServicePlaybackDidStop object:nil];
    }
    return self;
}

- (void)viewDidLoad {
    
    self.view = [[VLCUntouchableView alloc] initWithFrame:self.view.frame];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [[VLCPlaybackService sharedInstance] setPlayerDisplayController:self];
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _videoPlayerViewController = [[VLCVideoPlayerViewController alloc]
                                  init];
}

- (void)playbackDidStart:(NSNotification *)notification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    

    VLCMedia *currentMedia = _playbackController.currentlyPlayingMedia;

    [self _presentFullscreenPlaybackViewIfNeeded];
}

- (void)playbackDidStop:(NSNotification *)notification
{
    [self dismissPlaybackView];
}

- (void)playbackDidFail:(NSNotification *)notification
{
    [self showPlaybackError];
}

- (void)_presentFullscreenPlaybackViewIfNeeded
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.movieViewController.presentingViewController) {
            [self _presentMovieViewControllerAnimated:[self shouldAnimate]];
        }
    });
}

- (void)_presentMovieViewControllerAnimated:(BOOL)animated
{
    UIViewController *movieViewController = self.movieViewController;
    UINavigationController *navCon = [[VLCPlaybackNavigationController alloc] initWithRootViewController:movieViewController];
    navCon.modalPresentationStyle = UIModalPresentationOverFullScreen;
    navCon.modalPresentationCapturesStatusBarAppearance = YES;

    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    [window.rootViewController presentViewController:navCon animated:animated completion:^{

    }];
}

- (void)dismissPlaybackView
{
    [self _closeFullscreenPlayback];
}

- (void)_closeFullscreenPlayback
{
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL animated = [self shouldAnimate];
        [self.movieViewController dismissViewControllerAnimated:animated completion:nil];
    });
}

- (void)showPlaybackError
{
    NSString *failedString = NSLocalizedString(@"PLAYBACK_FAILED", nil);
    if ([self.movieViewController respondsToSelector:@selector(showStatusMessage:)]) {
        [self.movieViewController performSelector:@selector(showStatusMessage:) withObject:failedString];
    }
}

- (BOOL)shouldAnimate
{
    return [[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground;
}

- (UIViewController *)movieViewController
{
    if (!_movieViewController) {
#if TARGET_OS_IOS
            _movieViewController = _videoPlayerViewController;
            ((VLCVideoPlayerViewController *)_movieViewController).delegate = self;
#endif
    } else {
#if TARGET_OS_IOS
        _movieViewController = _videoPlayerViewController;
#endif
    }
    return _movieViewController;
}

- (VLCPlaybackService *)playbackController {
    if (_playbackController == nil) {
        _playbackController = [VLCPlaybackService sharedInstance];
    }
    return _playbackController;
}

@end
