#import <UIKit/UIKit.h>
#import <objc/runtime.h> // <-- 新增：支持 Ivar 运行时函数，防止编译报错

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
@interface AWERelatedMusicAnchorModel : NSObject @end
@interface AWEMusicExtraModel : NSObject @end

// 修复 contentFilter 编译报错
@interface AWEAwemeModel : NSObject 
- (BOOL)contentFilter;
@end
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
// 功能 6：禁用点击首页刷新（实时物理拦截）
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
// 功能 10 & 12：隐藏去汽水听按钮 / 刷到带汽水音乐的视频直接跳过
// ==========================================
// 1. 拦截 AWEAwemeModel，实现数据过滤与 UI 隐藏
%hook AWEAwemeModel

// 拦截视频数据的初始化过程（这是源码中用于过滤信息流的核心入口）
- (instancetype)initWithDictionary:(id)dict error:(NSError **)error {
    id orig = %orig;
    
    // 如果解析出了视频数据，并且命中过滤规则，就直接返回 nil（把这条视频丢弃）
    if (orig && [orig contentFilter]) {
        return nil;
    }
    
    return orig;
}

// 新增一个方法，专门用来判断这个视频要不要被过滤
%new
- (BOOL)contentFilter {
    // 读取开关
    BOOL skipMusic = DYYYGetBool(@"DYYYHideQuqishuiting");
    
    // 注意：为了不被下面返回 nil 的 Hook 影响，这里使用 Ivar (实例变量) 绕过 Getter 方法直接读取底层数据
    id realAnchor = nil;
    Ivar anchorIvar = class_getInstanceVariable([self class], "_relatedMusicAnchor");
    if (anchorIvar) {
        realAnchor = object_getIvar(self, anchorIvar);
    }
    
    // 如果开关打开，并且底层确实存在汽水音乐的锚点数据，就标记为需要过滤
    BOOL shouldFilterQishui = skipMusic && realAnchor != nil;
    
    return shouldFilterQishui;
}

// 隐藏汽水音乐锚点 (UI 层面：防止某些没被过滤掉的场景下依然露馅)
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
// 功能 11：屏蔽版本更新
// ==========================================
%hook AWEVersionUpdateManager

- (void)startVersionUpdateWorkflow:(id)arg1 completion:(id)arg2 {
    if (DYYYGetBool(@"DYYYNoUpdates")) {
        // 直接执行完成回调，假装处理完毕
        if (arg2) {
            void (^completionBlock)(void) = arg2;
            completionBlock();
        }
    } else {
        %orig;
    }
}

- (id)workflow {
    return DYYYGetBool(@"DYYYNoUpdates") ? nil : %orig;
}

- (id)badgeModule {
    return DYYYGetBool(@"DYYYNoUpdates") ? nil : %orig;
}

%end
