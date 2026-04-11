#import <UIKit/UIKit.h>

// ==========================================
// 功能 1：隐藏双列箭头（已成功）
// ==========================================
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

// ==========================================
// 功能 2：隐藏顶栏横线（已成功）
// ==========================================
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
// 功能 3：禁用直播 PCDN（纯净提取自 DYYY 源码）
// ==========================================
%hook HTSLiveStreamPcdnManager
+ (void)start {
    // 掏空内部，什么都不做，直接拦截
}
+ (void)configAndStartLiveIO {
    // 掏空内部，什么都不做，直接拦截
}
%end

%hook IESLiveLaunchTaskPcdn
- (void)excute {
    // 掏空内部，什么都不做，直接拦截
}
%end

// ==========================================
// 功能 4：禁用点击首页刷新（纯净提取自 DYYY 源码）
// ==========================================
%hook AWENormalModeTabBarGeneralButton
- (BOOL)enableRefresh {
    if ([self.accessibilityLabel isEqualToString:@"首页"]) {
        return NO; // 只要是首页按钮，强制返回 NO，禁止刷新
    }
    return %orig;
}
%end

// ==========================================
// 功能 5：禁用下拉刷新视频（借鉴你的思路：魔法打败魔法）
// 原理：不再死磕“拉不动”，而是直接把控制器的“允许刷新”属性给干掉。
// 让你拉，但是拉了不触发刷新数据！
// ==========================================
%hook AWEFeedTableViewController
// 强行把可刷新的属性返回 NO
- (BOOL)canRefresh { return NO; }
- (void)setCanRefresh:(BOOL)arg { %orig(NO); }

// 拦截已知的抖音刷新动作函数，让它变空壳
- (void)refreshData {}
- (void)handlePullToRefresh {}
- (void)pulldownToRefresh {}
%end

%hook AWEFeedContainerViewController
// 双重保险，把外部容器的刷新权限也干掉
- (BOOL)canRefresh { return NO; }
- (void)setCanRefresh:(BOOL)arg { %orig(NO); }
%end
