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
            // 找到底栏的文字标签
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                if ([label.text isEqualToString:@"首页"]) {
                    // 强行改名！
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

// 在手指碰到屏幕的瞬间进行实时判断，不依赖页面布局
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    @try {
        NSString *label = [self performSelector:@selector(accessibilityLabel)];
        // 兼容原名“首页”和我们改的新名字“𝑳𝒐𝒗𝒆”
        if ([label containsString:@"首页"] || [label containsString:@"𝑳𝒐𝒗𝒆"]) {
            NSNumber *statusObj = [self valueForKey:@"status"];
            if (statusObj && [statusObj integerValue] == 2) {
                // 如果当前已经在 𝑳𝒐𝒗𝒆 页，直接拒绝触摸，点不动！
                return NO;
            }
        }
    } @catch(NSException *e) {}
    
    // 如果在消息页等其他页面，正常放行触摸，允许切回 𝑳𝒐𝒗𝒆 页
    return %orig(point, event);
}

// 附赠双重保险
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
// 去除隐藏大家都在搜后的留白
%hook AWESearchAnchorListModel
- (BOOL)hideWords {
    return DYYYGetBool(@"DYYYHideCommentViews");
}
%end

// 隐藏观看历史搜索 / 互动区搜索锚点
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
// 隐藏内部弹出热搜视图
%hook AWEHotSearchInnerBottomView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideHotSearch")) {
        [self removeFromSuperview];
        return;
    }
    %orig;
}
%end

// 隐藏下面底部热点框数据模型
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

    if (!DYYYGetBool(@"DYYYHideMessageTabRedPacket")) {
        return;
    }

    UIView *parentView = self.superview;
    if (!parentView) {
        return;
    }

    NSArray<UIView *> *siblings = [parentView.subviews copy];
    if (siblings.count <= 1) {
        return;
    }

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
// 1. 在 AWEAwemeModel 中屏蔽汽水音乐锚点
%hook AWEAwemeModel
- (id)relatedMusicAnchor {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) return nil;
    return %orig;
}
- (void)setRelatedMusicAnchor:(id)anchor {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) {
        %orig(nil);
        return;
    }
    %orig;
}
%end

// 2. 屏蔽汽水音乐锚点对象本身
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

// 3. 屏蔽音乐外带模型中的汽水顶部栏信息
%hook AWEMusicExtraModel
- (id)commentTopBarInfo {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) return nil;
    return %orig;
}
- (void)setCommentTopBarInfo:(id)info {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) {
        %orig(nil);
        return;
    }
    %orig;
}
%end

// ==========================================
// 功能 11：隐藏消息页打开提醒的横幅 (核弹强化版)
// ==========================================
%hook AWEIMMessageTabOptPushBannerView

// 1. 只要被加到屏幕上，立刻自我销毁
- (void)didMoveToSuperview {
    %orig;
    if (DYYYGetBool(@"DYYYHidePushBanner")) {
        self.hidden = YES;
        [self removeFromSuperview];
    }
}

// 2. 如果父视图强行排版，再次销毁并透明化
- (void)layoutSubviews {
    %orig;
    if (DYYYGetBool(@"DYYYHidePushBanner")) {
        self.hidden = YES;
        self.alpha = 0.0;
        [self removeFromSuperview];
    }
}

// 3. 告诉自动布局（AutoLayout）：我的尺寸是 0x0
- (CGSize)intrinsicContentSize {
    if (DYYYGetBool(@"DYYYHidePushBanner")) {
        return CGSizeZero;
    }
    return %orig;
}

// 4. 拦截所有的 Frame 赋值，强行锁死为 0
- (void)setFrame:(CGRect)frame {
    if (DYYYGetBool(@"DYYYHidePushBanner")) {
        %orig(CGRectZero);
    } else {
        %orig(frame);
    }
}

%end
