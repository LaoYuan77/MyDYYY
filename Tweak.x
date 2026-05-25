#import <UIKit/UIKit.h>

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
