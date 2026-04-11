#import <UIKit/UIKit.h>

// ========== 身份声明（防止编译报错） ==========
@interface AWEFeedTabJumpGuideView : UIView
@end

@interface AWEFeedMultiTabSelectedContainerView : UIView
@end

// 声明底部按钮，告诉编译器它有个叫 status 的属性
@interface AWENormalModeTabBarGeneralButton : UIButton
@property (nonatomic, assign) NSInteger status;
@end

@interface AWENormalModeTabBar : UIView
@end
// ============================================


// ==========================================
// 功能 1：隐藏双列箭头（✅ 已成功）
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
// 功能 2：隐藏顶栏横线（✅ 已成功）
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
// 功能 3：禁用下拉刷新视频（✅ 已成功）
// ==========================================
%hook AWEFeedTableViewController
- (BOOL)canRefresh { return NO; }
- (void)setCanRefresh:(BOOL)arg { %orig(NO); }
- (void)refreshData {}
- (void)handlePullToRefresh {}
- (void)pulldownToRefresh {}
%end

%hook AWEFeedContainerViewController
- (BOOL)canRefresh { return NO; }
- (void)setCanRefresh:(BOOL)arg { %orig(NO); }
%end

// ==========================================
// 功能 4：禁用直播 PCDN（后台静默生效）
// ==========================================
%hook HTSLiveStreamPcdnManager
+ (void)start {}
+ (void)configAndStartLiveIO {}
%end

%hook IESLiveLaunchTaskPcdn
- (void)excute {}
%end

// ==========================================
// 功能 5：禁用点击首页刷新（1:1 原汁原味复刻 DYYY）
// ==========================================
%hook AWENormalModeTabBar
- (void)layoutSubviews {
    %orig;
    // 遍历底部的所有按钮
    Class generalButtonClass = NSClassFromString(@"AWENormalModeTabBarGeneralButton");
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:generalButtonClass]) {
            AWENormalModeTabBarGeneralButton *button = (AWENormalModeTabBarGeneralButton *)subview;
            if ([button.accessibilityLabel isEqualToString:@"首页"]) {
                // 原版精髓：如果 status == 2（代表正处于首页），直接冻结交互！
                button.userInteractionEnabled = (button.status != 2);
            }
        }
    }
}
%end

// 双重保险：拦截刷新许可
%hook AWENormalModeTabBarGeneralButton
- (BOOL)enableRefresh {
    if ([self.accessibilityLabel isEqualToString:@"首页"]) {
        return NO;
    }
    return %orig;
}
%end
