#import <UIKit/UIKit.h>

// ========== 身份声明（防止编译报错） ==========
@interface AWEFeedTabJumpGuideView : UIView
@end
@interface AWEFeedMultiTabSelectedContainerView : UIView
@end
@interface AWENormalModeTabBarGeneralButton : UIButton
@property (nonatomic, assign) NSInteger status;
- (void)swallowedTap_dyyy:(UITapGestureRecognizer *)gesture; // 声明我们的护盾手势
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
// 功能 5：禁用点击首页刷新（🔥 物理防爆盾战术，无视一切插件冲突）
// ==========================================
%hook AWENormalModeTabBarGeneralButton

- (void)layoutSubviews {
    %orig;
    @try {
        // 使用 containsString 防止新版抖音名称微调（如"首页，按钮"）
        NSString *label = [self performSelector:@selector(accessibilityLabel)];
        if ([label containsString:@"首页"]) {
            
            NSNumber *statusObj = [self valueForKey:@"status"];
            UIView *shield = [self viewWithTag:88888]; // 寻找我们的护盾
            
            if (statusObj && [statusObj integerValue] == 2) {
                // 当前在首页：升起护盾！
                if (!shield) {
                    // 凭空制造一块透明玻璃，大小和按钮一模一样
                    shield = [[UIView alloc] initWithFrame:self.bounds];
                    shield.tag = 88888;
                    shield.backgroundColor = [UIColor clearColor]; // 必须透明
                    shield.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                    
                    // 给玻璃绑上化解手势
                    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(swallowedTap_dyyy:)];
                    [shield addGestureRecognizer:tap];
                    
                    [self addSubview:shield];
                }
                shield.hidden = NO;
                [self bringSubviewToFront:shield]; // 确保玻璃永远在最上层！无视其他插件！
                
            } else {
                // 不在首页：撤下护盾，允许你点击切回首页
                if (shield) {
                    shield.hidden = YES;
                }
            }
        }
    } @catch (NSException *e) {}
}

// 吸收触摸事件的黑洞函数
%new
- (void)swallowedTap_dyyy:(UITapGestureRecognizer *)gesture {
    // 触摸被护盾吸收，不执行任何代码，直接化解点击！
}

// 原汁原味的底层许可拦截（兜底保平安）
- (BOOL)enableRefresh {
    @try {
        NSString *label = [self performSelector:@selector(accessibilityLabel)];
        if ([label containsString:@"首页"]) {
            return NO;
        }
    } @catch (NSException *e) {}
    return %orig;
}

%end
