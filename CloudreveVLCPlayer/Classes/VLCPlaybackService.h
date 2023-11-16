//
//  VLCPlaybackService.h
//  CloudreveVLCPlayer
//
//  Created by nongyun.cao on 2023/11/16.
//

#import <Foundation/Foundation.h>

@class VLCMediaList, VLCMedia, VLCPlayerDisplayController;
NS_ASSUME_NONNULL_BEGIN

extern NSString *const VLCPlaybackServicePlaybackDidStart;
extern NSString *const VLCPlaybackServicePlaybackDidPause;
extern NSString *const VLCPlaybackServicePlaybackDidResume;
extern NSString *const VLCPlaybackServicePlaybackDidStop;
extern NSString *const VLCPlaybackServicePlaybackDidFail;
extern NSString *const VLCPlaybackServicePlaybackMetadataDidChange;
extern NSString *const VLCPlaybackServicePlaybackPositionUpdated;
extern NSString *const VLCPlaybackServicePlaybackModeUpdated;
extern NSString *const VLCPlaybackServicePlaybackDidMoveOnToNextItem;

@interface VLCPlaybackService : NSObject

@property (nonatomic, strong, nullable) UIView *videoOutputView;

+ (VLCPlaybackService *)sharedInstance;

- (void)stopPlayback;

- (void)playMediaList:(VLCMediaList *)mediaList
           firstIndex:(NSInteger)index
    subtitlesFilePath:(NSString * _Nullable)subsFilePath;

- (void)playMediaList:(VLCMediaList *)mediaList 
           firstIndex:(NSInteger)index
    subtitlesFilePath:(NSString * _Nullable)subsFilePath
           completion:(void (^ __nullable)(BOOL success))completion;

- (VLCMedia *)currentlyPlayingMedia;

- (void)setPlayerDisplayController:(VLCPlayerDisplayController *)playerDisplayController;

@end

NS_ASSUME_NONNULL_END
