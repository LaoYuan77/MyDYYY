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
// 功能 4：禁用直播 PCDN（✅ 后台静默生效）
// ==========================================
%hook HTSLiveStreamPcdnManager
+ (void)start {}
+ (void)configAndStartLiveIO {}
%end

%hook IESLiveLaunchTaskPcdn
- (void)excute {}
%end

// ==========================================
// 功能 5：禁用点击首页刷新（🔥 终极物理触控盲区法）
// 原理：在 iOS 系统判断手指触摸归属时，直接拒绝认领该触摸事件！
// 连触摸信号都不产生，彻底无视一切手势和其他插件的冲突。
// ==========================================
%hook AWENormalModeTabBarGeneralButton

// 拦截系统触控判定
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    @try {
        NSString *label = [self performSelector:@selector(accessibilityLabel)];
        if ([label isEqualToString:@"首页"]) {
            // 获取按钮当前状态，2 代表正处于选中（当前在首页）
            NSNumber *statusObj = [self valueForKey:@"status"];
            if (statusObj && [statusObj integerValue] == 2) {
                // 🔥 核心杀招：直接返回 NO！
                // 告诉 iOS 系统：我这里是空气，别把点击事件发给我！
                return NO;
            }
        }
    } @catch (NSException *e) {
        // 防止意外报错
    }
    
    // 如果不是首页按钮，或者当前没在首页，正常放行触摸
    return %orig(point, event);
}

// 附赠 DYYY 原汁原味的属性拦截（双重保险）
- (BOOL)enableRefresh {
    @try {
        NSString *label = [self performSelector:@selector(accessibilityLabel)];
        if ([label isEqualToString:@"首页"]) {
            return NO;
        }
    } @catch (NSException *e) {}
    return %orig;
}
%end
