#import <UIKit/UIKit.h>

// ========== 工具函数：替代缺失的 DYYYGetBool ==========
static inline BOOL DYYYGetBool(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

// ========== 身份声明（防止编译报错） ==========
@interface AWEFeedTabJumpGuideView : UIView @end
@interface AWEFeedMultiTabSelectedContainerView : UIView @end
@interface AWENormalModeTabBarTextView : UIView @end
@interface AWENormalModeTabBarGeneralButton : UIButton
@property (nonatomic, assign) NSInteger status;
@end
@interface AWESearchAnchorListModel : NSObject @end
@interface AWEPlayInteractionSearchAnchorView : UIView @end
@interface AWEHotSearchInnerBottomView : UIView @end
@interface AWEHotSpotListModel : NSObject @end
@interface AWEIMMessageTabSideBarView : UIView @end
@interface AWEAwemeModel : NSObject @end
@interface AWERelatedMusicAnchorModel : NSObject @end
@interface AWEMusicExtraModel : NSObject @end
@interface AWEIMMessageTabOptPushBannerView : UIView @end
@interface AWEIMChatListViewController : UIViewController @end
// ============================================

// ==========================================
// 功能 1：隐藏双列箭头（✅）
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
// 功能 2：隐藏顶栏横线（✅）
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
// 功能 3：禁用下拉刷新视频（✅）
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
// 功能 4：禁用直播 PCDN（✅）
// ==========================================
%hook HTSLiveStreamPcdnManager
+ (void)start {}
+ (void)configAndStartLiveIO {}
%end

%hook IESLiveLaunchTaskPcdn
- (void)excute {}
%end

// ==========================================
// 功能 5：将底栏“首页”文字修改为“𝑳𝒐𝒗𝒆”（🔥 新增）
// ==========================================
%hook AWENormalModeTabBarTextView
- (void)layoutSubviews {
    %orig;
    @try {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                if ([label.text isEqualToString:@"首页"]) {
                    label.text = @"𝑳𝒐𝒗𝒆";
                }
            }
        }
    } @catch(NSException *e) {}
}
%end

// ==========================================
// 功能 6：禁用点击首页刷新（🔥 实时物理拦截，修复卡死 Bug）
// ==========================================
%hook AWENormalModeTabBarGeneralButton
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    @try {
        NSString *label = [self performSelector:@selector(accessibilityLabel)];
        if ([label containsString:@"首页"] || [label containsString:@"𝑳𝒐𝒗𝒆"]) {
            NSNumber *statusObj = [self valueForKey:@"status"];
            if (statusObj && [statusObj integerValue] == 2) {
                return NO;
            }
        }
    } @catch(NSException *e) {}
    
    return %orig(point, event);
}

- (BOOL)enableRefresh {
    @try {
        NSString *label = [self performSelector:@selector(accessibilityLabel)];
        if ([label containsString:@"首页"] || [label containsString:@"𝑳𝒐𝒗𝒆"]) {
            return NO;
        }
    } @catch(NSException *e) {}
    return %orig;
}
%end

// ==========================================
// 功能 7：隐藏相关搜索 / 观看历史搜索
// ==========================================
%hook AWESearchAnchorListModel
- (BOOL)hideWords {
    return DYYYGetBool(@"DYYYHideCommentViews");
}
%end

%hook AWEPlayInteractionSearchAnchorView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideInteractionSearch")) {
        [self removeFromSuperview];
        return;
    }
    %orig;
}
%end

// ==========================================
// 功能 8：隐藏弹出热搜 / 热点框
// ==========================================
%hook AWEHotSearchInnerBottomView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideHotSearch")) {
        [self removeFromSuperview];
        return;
    }
    %orig;
}
%end

%hook AWEHotSpotListModel
- (BOOL)disableDisplay {
    if (DYYYGetBool(@"DYYYHideHotspot")) return YES;
    return %orig;
}
- (BOOL)disableDisplayInner {
    if (DYYYGetBool(@"DYYYHideHotspot")) return YES;
    return %orig;
}
- (NSString *)hotSpotTipTitleHeader {
    if (DYYYGetBool(@"DYYYHideHotspot")) return @"";
    return %orig;
}
- (NSString *)hotSpotTipTitle {
    if (DYYYGetBool(@"DYYYHideHotspot")) return @"";
    return %orig;
}
%end

// ==========================================
// 功能 9：隐藏消息顶栏红包
// ==========================================
%hook AWEIMMessageTabSideBarView
- (void)layoutSubviews {
    %orig;
    if (!DYYYGetBool(@"DYYYHideMessageTabRedPacket")) return;

    UIView *parentView = self.superview;
    if (!parentView) return;

    NSArray<UIView *> *siblings = [parentView.subviews copy];
    if (siblings.count <= 1) return;

    for (UIView *subview in siblings) {
        if (subview != self) {
            [subview removeFromSuperview];
        }
    }
}
%end

// ==========================================
// 功能 10：隐藏去汽水听
// ==========================================
%hook AWEAwemeModel
- (id)relatedMusicAnchor {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) return nil;
    return %orig;
}
- (void)setRelatedMusicAnchor:(id)anchor {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) { %orig(nil); return; }
    %orig;
}
%end

%hook AWERelatedMusicAnchorModel
- (instancetype)init {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) return nil;
    return %orig;
}
- (instancetype)initWithDictionary:(id)dict error:(NSError **)error {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) return nil;
    return %orig;
}
%end

%hook AWEMusicExtraModel
- (id)commentTopBarInfo {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) return nil;
    return %orig;
}
- (void)setCommentTopBarInfo:(id)info {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) { %orig(nil); return; }
    %orig;
}
%end

// ==========================================
// 功能 11：隐藏消息页打开提醒的横幅 (控制器欺骗版，彻底消除留白)
// ==========================================
// 1. 拦截横幅本身的渲染
%hook AWEIMMessageTabOptPushBannerView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHidePushBanner")) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.frame = CGRectZero;
    }
}
- (CGSize)intrinsicContentSize {
    if (DYYYGetBool(@"DYYYHidePushBanner")) return CGSizeZero;
    return %orig;
}
%end

// 2. 欺骗控制器：拦截所有询问“横幅是否显示”的方法，返回 NO 或 0
%hook AWEIMChatListViewController
- (BOOL)shouldShowPushBanner {
    if (DYYYGetBool(@"DYYYHidePushBanner")) return NO;
    return %orig;
}
- (BOOL)isPushBannerShowing {
    if (DYYYGetBool(@"DYYYHidePushBanner")) return NO;
    return %orig;
}
- (BOOL)pushBannerIsShowing {
    if (DYYYGetBool(@"DYYYHidePushBanner")) return NO;
    return %orig;
}
- (id)pushBannerView {
    if (DYYYGetBool(@"DYYYHidePushBanner")) return nil;
    return %orig;
}
- (double)pushBannerHeight {
    if (DYYYGetBool(@"DYYYHidePushBanner")) return 0.0;
    return %orig;
}
%end
