#import <UIKit/UIKit.h>

// ========== 身份声明 ==========
@interface AWEFeedTabJumpGuideView : UIView
@end
@interface AWEFeedMultiTabSelectedContainerView : UIView
@end
@interface AWENormalModeTabBarTextView : UIView
@end
@interface AWENormalModeTabBarGeneralButton : UIButton
@property (nonatomic, assign) NSInteger status;
@end

// ========== 工具宏与内联函数 ==========

// 宏：快捷屏蔽 Model 的 Getter/Setter
#define DYYY_HOOK_MODEL_ANCHOR(ClassName, Getter, Setter, SwitchKey) \
%hook ClassName \
- (id)Getter { if (DYYYGetBool(SwitchKey)) return nil; return %orig; } \
- (void)Setter:(id)arg { if (DYYYGetBool(SwitchKey)) { %orig(nil); return; } %orig; } \
%end

// 内联函数：判断是否为底栏首页按钮
static inline BOOL isHomeButton(id btn) {
    @try {
        NSString *label = [btn performSelector:@selector(accessibilityLabel)];
        return [label containsString:@"首页"] || [label containsString:@"𝑳𝒐𝒗𝒆"];
    } @catch(NSException *e) {}
    return NO;
}
// ============================================

// ==========================================
// 功能 1：隐藏双列箭头
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
// 功能 2：隐藏顶栏横线
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
// 功能 3：禁用下拉刷新视频
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
// 功能 4：禁用直播 PCDN
// ==========================================
%hook HTSLiveStreamPcdnManager
+ (void)start {}
+ (void)configAndStartLiveIO {}
%end

%hook IESLiveLaunchTaskPcdn
- (void)excute {}
%end

// ==========================================
// 功能 5：将底栏“首页”文字修改为“𝑳𝒐𝒗𝒆”
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
// 功能 6：禁用点击首页刷新（实时物理拦截）
// ==========================================
%hook AWENormalModeTabBarGeneralButton
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (isHomeButton(self)) {
        NSNumber *statusObj = [self valueForKey:@"status"];
        // 状态2代表当前正处于被选中状态，拦截触摸
        if (statusObj && [statusObj integerValue] == 2) return NO;
    }
    return %orig(point, event);
}

- (BOOL)enableRefresh {
    if (isHomeButton(self)) return NO;
    return %orig;
}
%end

// ==========================================
// 功能 7：隐藏相关搜索 / 观看历史搜索
// ==========================================
%hook AWESearchAnchorListModel
- (BOOL)hideWords { return DYYYGetBool(@"DYYYHideCommentViews"); }
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
// 功能 8：隐藏弹出热搜 / 热点框 (使用宏大幅精简)
// ==========================================
%hook AWEHotSearchInnerBottomView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideHotSearch")) { [self removeFromSuperview]; return; }
    %orig;
}
%end

%hook AWEHotSpotListModel
#define DYYY_HOTSPOT_BOOL(Method) - (BOOL)Method { if (DYYYGetBool(@"DYYYHideHotspot")) return YES; return %orig; }
#define DYYY_HOTSPOT_STR(Method)  - (NSString *)Method { if (DYYYGetBool(@"DYYYHideHotspot")) return @""; return %orig; }

DYYY_HOTSPOT_BOOL(disableDisplay)
DYYY_HOTSPOT_BOOL(disableDisplayInner)
DYYY_HOTSPOT_STR(hotSpotTipTitleHeader)
DYYY_HOTSPOT_STR(hotSpotTipTitle)
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
// 功能 10：隐藏去汽水听 (使用宏一键生成)
// ==========================================
DYYY_HOOK_MODEL_ANCHOR(AWEAwemeModel, relatedMusicAnchor, setRelatedMusicAnchor, @"DYYYHideQuqishuiting")
DYYY_HOOK_MODEL_ANCHOR(AWEMusicExtraModel, commentTopBarInfo, setCommentTopBarInfo, @"DYYYHideQuqishuiting")

// 特殊的 init Hook
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

// ==========================================
// 功能 11：隐藏消息页打开提醒的横幅
// ==========================================
%hook AWEIMMessageTabOptPushBannerView
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHidePushBanner")) {
        self.hidden = YES;
        self.alpha = 0.0;
        CGRect frame = self.frame;
        if (frame.size.height > 0) {
            frame.size.height = 0;
            self.frame = frame;
        }
    }
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (DYYYGetBool(@"DYYYHidePushBanner")) {
        return %orig(CGRectMake(frame.origin.x, frame.origin.y, 0, 0));
    }
    return %orig;
}
%end
