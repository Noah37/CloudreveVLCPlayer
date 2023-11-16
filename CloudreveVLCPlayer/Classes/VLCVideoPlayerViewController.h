//
//  VLCVideoPlayerViewController.h
//  CloudreveVLCPlayer
//
//  Created by nongyun.cao on 2023/11/16.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VLCVideoPlayerViewControllerDelegate <NSObject>


@end

@interface VLCVideoPlayerViewController : UIViewController

@property (nonatomic, weak) id<VLCVideoPlayerViewControllerDelegate>delegate;

@end

NS_ASSUME_NONNULL_END
