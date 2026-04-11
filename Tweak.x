#import <UIKit/UIKit.h>

// ========== 身份声明 ==========
@interface AWEFeedTabJumpGuideView : UIView
@end

@interface AWEFeedMultiTabSelectedContainerView : UIView
@end

@interface AWEFeedTableView : UIScrollView
@end
// ==============================

// 功能 1：隐藏双列箭头（暴力拔除 + 透明度双保险）
%hook AWEFeedTabJumpGuideView
- (void)layoutSubviews {
    %orig;
    self.alpha = 0.0;
    self.hidden = YES;
    [self removeFromSuperview];
}
// 拦截任何试图让它显示的操作
- (void)setHidden:(BOOL)hidden {
    %orig(YES);
}
- (void)setAlpha:(CGFloat)alpha {
    %orig(0.0);
}
%end

// 功能 2：隐藏顶栏横线（强制透明 + 隐藏）
%hook AWEFeedMultiTabSelectedContainerView
- (void)layoutSubviews {
    %orig;
    self.alpha = 0.0;
    self.hidden = YES;
}
- (void)setHidden:(BOOL)hidden {
    %orig(YES);
}
- (void)setAlpha:(CGFloat)alpha {
    %orig(0.0);
}
%end

// 功能 3：禁用顶部下拉刷新视频（直接关闭边缘回弹，干脆利落）
%hook AWEFeedTableView
- (BOOL)bounces {
    return NO;
}
- (void)setBounces:(BOOL)bounces {
    %orig(NO); // 强制拒绝任何开启回弹的请求
}
%end
