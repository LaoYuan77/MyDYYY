#import <UIKit/UIKit.h>

// ========== 身份声明 ==========
@interface AWEFeedTabJumpGuideView : UIView
@end

@interface AWEFeedMultiTabSelectedContainerView : UIView
@end

@interface AWEFeedTableViewController : UIViewController
- (void)disableBouncesForView:(UIView *)view;
@end
// ==============================

// 功能 1：隐藏双列箭头（保持成功逻辑）
%hook AWEFeedTabJumpGuideView
- (void)layoutSubviews {
    %orig;
    self.alpha = 0.0;
    self.hidden = YES;
    [self removeFromSuperview];
}
- (void)setHidden:(BOOL)hidden { %orig(YES); }
- (void)setAlpha:(CGFloat)alpha { %orig(0.0); }
%end

// 功能 2：隐藏顶栏横线（保持成功逻辑）
%hook AWEFeedMultiTabSelectedContainerView
- (void)layoutSubviews {
    %orig;
    self.alpha = 0.0;
    self.hidden = YES;
}
- (void)setHidden:(BOOL)hidden { %orig(YES); }
- (void)setAlpha:(CGFloat)alpha { %orig(0.0); }
%end

// ==========================================
// 功能 3：终极杀手锏 3.0 - 控制器级暴力封杀
// ==========================================

%hook AWEFeedTableViewController

// 每次页面显示，查水表关闭所有滚动视图的弹性
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self disableBouncesForView:self.view];
}

// 递归遍历所有子视图，宁可错杀一千不放过一个
%new
- (void)disableBouncesForView:(UIView *)view {
    if ([view isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scrollView = (UIScrollView *)view;
        scrollView.bounces = NO;
        scrollView.alwaysBounceVertical = NO;
    }
    // 遍历下层视图
    for (UIView *subview in view.subviews) {
        [self disableBouncesForView:subview];
    }
}

// 拦截各种已知的抖音刷新动作，直接没收执行权限（让刷新函数变成空壳）
- (void)_refreshData {}
- (void)refreshData {}
- (void)headerRefreshing {}
- (void)pulldownToRefresh {}
- (void)handlePullDownToRefresh {}

%end
