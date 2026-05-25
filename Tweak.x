#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 强制开启该功能
#define DYYYGetBool(key) YES

%hook AWEFeedTableViewController

- (BOOL)canRefresh { return NO; }
- (void)setCanRefresh:(BOOL)arg { %orig(NO); }
- (void)refreshData { return; }
- (void)handlePullToRefresh { return; }
- (void)pulldownToRefresh { return; }

%end

%hook AWEFeedContainerViewController

- (BOOL)canRefresh { return NO; }
- (void)setCanRefresh:(BOOL)arg { %orig(NO); }

%end
