//
//  VLCPlaybackService.m
//  CloudreveVLCPlayer
//
//  Created by nongyun.cao on 2023/11/16.
//

#import "VLCPlaybackService.h"
#import <MobileVLCKit/VLCMediaList.h>
#import <MobileVLCKit/VLCMediaListPlayer.h>
#import <MobileVLCKit/VLCMediaPlayer.h>
#import <MobileVLCKit/VLCMedia.h>
#import "VLCPlayerDisplayController.h"


NSString *const VLCPlaybackServicePlaybackDidStart = @"VLCPlaybackServicePlaybackDidStart";
NSString *const VLCPlaybackServicePlaybackDidPause = @"VLCPlaybackServicePlaybackDidPause";
NSString *const VLCPlaybackServicePlaybackDidResume = @"VLCPlaybackServicePlaybackDidResume";
NSString *const VLCPlaybackServicePlaybackDidStop = @"VLCPlaybackServicePlaybackDidStop";
NSString *const VLCPlaybackServicePlaybackMetadataDidChange = @"VLCPlaybackServicePlaybackMetadataDidChange";
NSString *const VLCPlaybackServicePlaybackDidFail = @"VLCPlaybackServicePlaybackDidFail";
NSString *const VLCPlaybackServicePlaybackPositionUpdated = @"VLCPlaybackServicePlaybackPositionUpdated";
NSString *const VLCPlaybackServicePlaybackModeUpdated = @"VLCPlaybackServicePlaybackModeUpdated";
NSString *const VLCPlaybackServicePlaybackDidMoveOnToNextItem = @"VLCPlaybackServicePlaybackDidMoveOnToNextItem";

@interface VLCPlaybackService ()<VLCMediaListPlayerDelegate,VLCMediaPlayerDelegate>
{
    NSLock *_playbackSessionManagementLock;
    UIView *_actualVideoOutputView;
    UIView *_videoOutputViewWrapper;
    VLCMediaListPlayer *_listPlayer;
    VLCMediaPlayer *_mediaPlayer;
    BOOL _mediaWasJustStarted;
    NSMutableArray *_openedLocalURLs;
    VLCPlayerDisplayController *_playerDisplayController;
}

@property (nonatomic, strong) VLCMediaList *mediaList;
@property (nonatomic, copy) void (^playbackCompletion)(BOOL success);

@property (nonatomic, assign) NSInteger itemInMediaListToBePlayedFirst;
@property (nonatomic, copy) NSString *pathToExternalSubtitlesFile;
@property (nonatomic, assign) BOOL playerIsSetup;
@property (nonatomic, assign) BOOL sessionWillRestart;


@end

@implementation VLCPlaybackService

+ (VLCPlaybackService *)sharedInstance
{
    static VLCPlaybackService *sharedInstance = nil;
    static dispatch_once_t pred;

    dispatch_once(&pred, ^{
        sharedInstance = [VLCPlaybackService new];
    });

    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _playbackSessionManagementLock = [[NSLock alloc] init];
        _mediaList = [[VLCMediaList alloc] init];

        _openedLocalURLs = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)playMediaList:(VLCMediaList *)mediaList firstIndex:(NSInteger)index subtitlesFilePath:(NSString * _Nullable)subsFilePath
{
    [self playMediaList: mediaList firstIndex: index subtitlesFilePath: subsFilePath completion: nil];
}

- (void)playMediaList:(VLCMediaList *)mediaList firstIndex:(NSInteger)index subtitlesFilePath:(NSString * _Nullable)subsFilePath completion:(void (^ __nullable)(BOOL success))completion
{
    _playbackCompletion = completion;
    self.mediaList = mediaList;
    _itemInMediaListToBePlayedFirst = (int)index;
    _pathToExternalSubtitlesFile = subsFilePath;

    _sessionWillRestart = _playerIsSetup;
    _playerIsSetup ? [self stopPlayback] : [self startPlayback];
}

- (void)startPlayback {
    if (_playerIsSetup) {
        NSLog(@"%s: player is already setup, bailing out", __PRETTY_FUNCTION__);
        return;
    }

    BOOL ret = [_playbackSessionManagementLock tryLock];
    if (!ret) {
        NSLog(@"%s: locking failed", __PRETTY_FUNCTION__);
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (!self.mediaList) {
        NSLog(@"%s: no URL and no media list set, stopping playback", __PRETTY_FUNCTION__);
        [_playbackSessionManagementLock unlock];
        [self stopPlayback];
        return;
    }
    /* video decoding permanently fails if we don't provide a UIView to draw into on init
     * hence we provide one which is not attached to any view controller for off-screen drawing
     * and disable video decoding once playback started */
    _actualVideoOutputView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _actualVideoOutputView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _actualVideoOutputView.autoresizesSubviews = YES;
    
    _listPlayer = [[VLCMediaListPlayer alloc] initWithDrawable:_actualVideoOutputView];
    _listPlayer.delegate = self;
    
    _mediaPlayer = _listPlayer.mediaPlayer;

    [_mediaPlayer setDelegate:self];
    
    [_listPlayer setMediaList:self.mediaList];

    [_playbackSessionManagementLock unlock];
    
    [self _playNewMedia];
}

- (void)_playNewMedia {
    BOOL ret = [_playbackSessionManagementLock tryLock];
    if (!ret) {
        NSLog(@"%s: locking failed", __PRETTY_FUNCTION__);
        return;
    }
    
    _mediaWasJustStarted = YES;

    [_mediaPlayer addObserver:self forKeyPath:@"time" options:0 context:nil];
    [_mediaPlayer addObserver:self forKeyPath:@"remainingTime" options:0 context:nil];
    
    [_listPlayer playItemAtNumber:@(_itemInMediaListToBePlayedFirst)];
    
    _mediaPlayer.videoAspectRatio = NULL;

    _playerIsSetup = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:VLCPlaybackServicePlaybackDidStart object:self];
    [_playbackSessionManagementLock unlock];
}

- (void)stopPlayback {
    BOOL ret = [_playbackSessionManagementLock tryLock];
    if (!ret) {
        NSLog(@"%s: locking failed", __PRETTY_FUNCTION__);
        return;
    }

    if (_mediaPlayer) {
        @try {
            [_mediaPlayer removeObserver:self forKeyPath:@"time"];
            [_mediaPlayer removeObserver:self forKeyPath:@"remainingTime"];
        }
        @catch (NSException *exception) {
            NSLog(@"we weren't an observer yet");
        }

        if (_mediaPlayer.media) {
            [_mediaPlayer pause];
            [_mediaPlayer stop];
        }

        if (_playbackCompletion) {
            BOOL finishedPlaybackWithError = false;
            if (_mediaPlayer.state == VLCMediaPlayerStateStopped && _mediaPlayer.media != nil) {
                // Since VLCMediaPlayerStateError is sometimes not matched with a valid media.
                // This checks for decoded Audio & Video blocks.
                VLCMediaStats stats = _mediaPlayer.media.statistics;
                finishedPlaybackWithError = (stats.decodedAudio == 0) && (stats.decodedVideo == 0);
            } else {
                finishedPlaybackWithError = _mediaPlayer.state == VLCMediaPlayerStateError;
            }
            finishedPlaybackWithError = finishedPlaybackWithError && !_sessionWillRestart;

            _playbackCompletion(!finishedPlaybackWithError);
        }

        _mediaPlayer = nil;
        _listPlayer = nil;
    }

    for (NSURL *url in _openedLocalURLs) {
        [url stopAccessingSecurityScopedResource];
    }
    _openedLocalURLs = nil;
    _openedLocalURLs = [[NSMutableArray alloc] init];

    if (!_sessionWillRestart) {
        _mediaList = nil;
        _mediaList = [[VLCMediaList alloc] init];
    }
    _playerIsSetup = NO;

    [_playbackSessionManagementLock unlock];
    [[NSNotificationCenter defaultCenter] postNotificationName:VLCPlaybackServicePlaybackDidStop object:self];
    if (_sessionWillRestart) {
        _sessionWillRestart = NO;
        [self startPlayback];
    }
}

- (void)setVideoOutputView:(UIView *)videoOutputView
{
    if (videoOutputView) {
        if ([_actualVideoOutputView superview] != nil)
            [_actualVideoOutputView removeFromSuperview];

        _actualVideoOutputView.frame = (CGRect){CGPointZero, videoOutputView.frame.size};

        [self setVideoTrackEnabled:true];

        [videoOutputView addSubview:_actualVideoOutputView];
        [_actualVideoOutputView layoutSubviews];
        [_actualVideoOutputView updateConstraints];
        [_actualVideoOutputView setNeedsLayout];
    } else
        [_actualVideoOutputView removeFromSuperview];

    _videoOutputViewWrapper = videoOutputView;
}

- (UIView *)videoOutputView
{
    return _videoOutputViewWrapper;
}

- (void)setVideoTrackEnabled:(BOOL)enabled
{
    if (!enabled)
        _mediaPlayer.currentVideoTrackIndex = -1;
    else if (_mediaPlayer.currentVideoTrackIndex == -1) {
        for (NSNumber *trackId in _mediaPlayer.videoTrackIndexes) {
            if ([trackId intValue] != -1) {
                _mediaPlayer.currentVideoTrackIndex = [trackId intValue];
                break;
            }
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [[NSNotificationCenter defaultCenter] postNotificationName:VLCPlaybackServicePlaybackPositionUpdated
                                                        object:self];
}

- (VLCMedia *)currentlyPlayingMedia
{
    return _mediaPlayer.media;
}

/**
 * Sent when VLCMediaListPlayer has finished playing.
 */
- (void)mediaListPlayerFinishedPlayback:(VLCMediaListPlayer *)player {
    
}

/**
 * Sent when VLCMediaListPlayer going to play next media
 */
- (void)mediaListPlayer:(VLCMediaListPlayer *)player
              nextMedia:(VLCMedia *)media {
    
}

/**
 * Sent when VLCMediaListPlayer is stopped.
 * Internally or by using the stop()
 * \see stop
 */
- (void)mediaListPlayerStopped:(VLCMediaListPlayer *)player {
    
}

/**
 * Sent by the default notification center whenever the player's state has changed.
 * \details Discussion The value of aNotification is always an VLCMediaPlayerStateChanged notification. You can retrieve
 * the VLCMediaPlayer object in question by sending object to aNotification.
 */
- (void)mediaPlayerStateChanged:(NSNotification *)aNotification {
    
}

- (void)setPlayerDisplayController:(VLCPlayerDisplayController *)playerDisplayController
{
    _playerDisplayController = playerDisplayController;
}

@end
