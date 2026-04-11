#import <UIKit/UIKit.h>

// ========== 身份声明：告诉编译器这些类是视图，不要报错 ==========
@interface AWEFeedTabJumpGuideView : UIView
@end

@interface AWEFeedMultiTabSelectedContainerView : UIView
@end

@interface AWEFeedTableView : UIScrollView
@end
// =========================================================

// 功能 1：隐藏双列箭头
%hook AWEFeedTabJumpGuideView
- (void)layoutSubviews {
    %orig;
    self.hidden = YES;
}
%end

// 功能 2：隐藏顶栏横线
%hook AWEFeedMultiTabSelectedContainerView
- (void)layoutSubviews {
    %orig;
    self.hidden = YES;
}
%end

// 功能 3：禁用顶部下拉刷新视频
%hook AWEFeedTableView
- (void)setContentOffset:(CGPoint)offset {
    if (offset.y < 0) {
        offset.y = 0;
    }
    %orig(offset);
}
%end
