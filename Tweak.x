#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ========== 工具函数：强制所有开关默认生效 ==========
static inline BOOL DYYYGetBool(NSString *key) {
    // 既然没有 UI 设置面板，直接让所有开关判断永远返回 YES
    return YES;
}

// ========== 更新弹窗文本判断 ==========
static inline BOOL DYYYTextContainsAny(NSString *text, NSArray<NSString *> *keywords) {
    if (!text || text.length == 0) return NO;

    for (NSString *keyword in keywords) {
        if ([text containsString:keyword]) {
            return YES;
        }
    }

    return NO;
}

static inline BOOL DYYYIsUpdateAlertText(NSString *text) {
    if (!text || text.length == 0) return NO;

    // 很明确的更新弹窗关键词
    if (DYYYTextContainsAny(text, @[
        @"版本过低",
        @"版本太低",
        @"低版本",
        @"立即更新",
        @"马上更新",
        @"前往 App Store",
        @"App Store",
        @"发现新版本",
        @"检测到新版本",
        @"升级到最新版本",
        @"更新到最新版本"
    ])) {
        return YES;
    }

    // 普通组合判断，避免误拦“更新资料”这类普通弹窗
    BOOL hasVersionWord = DYYYTextContainsAny(text, @[
        @"版本",
        @"升级",
        @"更新"
    ]);

    BOOL hasUpdateActionWord = DYYYTextContainsAny(text, @[
        @"新版本",
        @"最新版本",
        @"立即体验",
        @"立即升级",
        @"重新安装",
        @"为了更好的体验",
        @"为了获得更好的体验"
    ]);

    return hasVersionWord && hasUpdateActionWord;
}

// ========== 自定义更新弹窗文本收集 / 判断 ==========
static inline void DYYYAppendText(NSMutableString *result, id value) {
    if (!value) return;

    @try {
        if ([value isKindOfClass:[NSString class]]) {
            NSString *str = (NSString *)value;
            if (str.length > 0) {
                [result appendString:str];
                [result appendString:@" "];
            }
        } else if ([value respondsToSelector:@selector(string)]) {
            NSString *str = [value string];
            if (str.length > 0) {
                [result appendString:str];
                [result appendString:@" "];
            }
        }
    } @catch (NSException *e) {}
}

static NSString *DYYYCollectViewText(UIView *view, NSInteger depth) {
    if (!view || depth > 8) return @"";

    NSMutableString *result = [NSMutableString string];

    @try {
        DYYYAppendText(result, view.accessibilityLabel);
        DYYYAppendText(result, view.accessibilityValue);
        DYYYAppendText(result, view.accessibilityHint);

        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            DYYYAppendText(result, label.text);
            DYYYAppendText(result, label.attributedText);
        }

        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)view;

            NSArray *states = @[
                @(UIControlStateNormal),
                @(UIControlStateHighlighted),
                @(UIControlStateSelected),
                @(UIControlStateDisabled)
            ];

            for (NSNumber *stateObj in states) {
                UIControlState state = [stateObj unsignedIntegerValue];
                DYYYAppendText(result, [button titleForState:state]);
                DYYYAppendText(result, [button attributedTitleForState:state]);
            }

            DYYYAppendText(result, button.titleLabel.text);
            DYYYAppendText(result, button.titleLabel.attributedText);
        }

        if ([view isKindOfClass:[UITextView class]]) {
            UITextView *textView = (UITextView *)view;
            DYYYAppendText(result, textView.text);
            DYYYAppendText(result, textView.attributedText);
        }

        if ([view isKindOfClass:[UITextField class]]) {
            UITextField *textField = (UITextField *)view;
            DYYYAppendText(result, textField.text);
            DYYYAppendText(result, textField.attributedText);
            DYYYAppendText(result, textField.placeholder);
        }

        // 兼容抖音自定义 Label / Button，很多不是 UILabel/UIButton
        for (NSString *key in @[@"text", @"title", @"subtitle", @"message", @"attributedText", @"attributedTitle"]) {
            @try {
                id value = [view valueForKey:key];
                DYYYAppendText(result, value);
            } @catch (NSException *e) {}
        }

        NSArray<UIView *> *subviews = [view.subviews copy];
        for (UIView *subview in subviews) {
            NSString *subText = DYYYCollectViewText(subview, depth + 1);
            DYYYAppendText(result, subText);
        }
    } @catch (NSException *e) {}

    return result;
}

static inline BOOL DYYYIsCustomUpdateText(NSString *text) {
    if (!text || text.length == 0) return NO;

    // 复用原来的更新文本判断
    if (DYYYIsUpdateAlertText(text)) return YES;

    BOOL hasDouyinUpdateTitle =
        [text containsString:@"抖音有新版本"] ||
        [text containsString:@"有新版本啦"];

    BOOL hasUpdateButton =
        [text containsString:@"立即升级"] ||
        [text containsString:@"立即更新"] ||
        [text containsString:@"马上升级"] ||
        [text containsString:@"马上更新"];

    BOOL hasLaterButton =
        [text containsString:@"以后再说"] ||
        [text containsString:@"稍后再说"] ||
        [text containsString:@"下次再说"];

    BOOL hasAppStoreText =
        [text containsString:@"App Store"] ||
        [text containsString:@"前往 App Store"];

    BOOL hasFeatureText =
        [text containsString:@"新功能"] ||
        [text containsString:@"更流畅"] ||
        [text containsString:@"更稳定"];

    return
        (hasDouyinUpdateTitle && (hasUpdateButton || hasAppStoreText || hasFeatureText)) ||
        (hasUpdateButton && hasLaterButton) ||
        (hasAppStoreText && ([text containsString:@"升级"] || [text containsString:@"更新"]));
}

static inline BOOL DYYYLooksLikeCardView(UIView *view) {
    if (!view || !view.window) return NO;

    CGSize screenSize = UIScreen.mainScreen.bounds.size;
    CGFloat screenW = screenSize.width;
    CGFloat screenH = screenSize.height;

    CGFloat w = view.bounds.size.width;
    CGFloat h = view.bounds.size.height;

    if (w <= 0 || h <= 0) return NO;

    // 白色弹窗卡片：不是全屏，但尺寸明显大于普通按钮/Label
    return
        w >= 160 &&
        h >= 120 &&
        w <= screenW * 0.96 &&
        h <= screenH * 0.86;
}

static inline BOOL DYYYLooksLikeFullOverlay(UIView *view) {
    if (!view || !view.window) return NO;

    CGSize screenSize = UIScreen.mainScreen.bounds.size;
    CGFloat screenW = screenSize.width;
    CGFloat screenH = screenSize.height;

    CGFloat w = view.bounds.size.width;
    CGFloat h = view.bounds.size.height;

    return
        w >= screenW * 0.85 &&
        h >= screenH * 0.70;
}

static UIView *DYYYFindUpdatePopupTarget(UIView *fromView) {
    if (!fromView || !fromView.window) return nil;

    UIView *view = fromView;
    UIView *card = nil;

    // 先找包含更新文案的弹窗卡片
    while (view && ![view isKindOfClass:[UIWindow class]]) {
        NSString *text = DYYYCollectViewText(view, 0);

        if (DYYYIsCustomUpdateText(text) && DYYYLooksLikeCardView(view)) {
            card = view;
            break;
        }

        view = view.superview;
    }

    if (!card) {
        // 如果传进来的就是整层蒙版，直接判断它本身
        NSString *text = DYYYCollectViewText(fromView, 0);
        if (DYYYIsCustomUpdateText(text) && DYYYLooksLikeFullOverlay(fromView)) {
            return fromView;
        }

        return nil;
    }

    UIView *target = card;
    UIView *parent = card.superview;
    NSInteger upCount = 0;

    // 如果卡片外面包着全屏灰黑蒙版，把蒙版一起删掉，避免只删白框后页面还被遮住
    while (parent && ![parent isKindOfClass:[UIWindow class]] && upCount < 4) {
        if (DYYYLooksLikeFullOverlay(parent) && parent.subviews.count <= 8) {
            target = parent;
        }

        parent = parent.superview;
        upCount++;
    }

    return target;
}

static inline void DYYYTryRemoveCustomUpdatePopup(UIView *view) {
    if (!DYYYGetBool(@"DYYYNoUpdates")) return;
    if (!view || !view.window) return;

    @try {
        UIView *target = DYYYFindUpdatePopupTarget(view);

        if (target && ![target isKindOfClass:[UIWindow class]]) {
            NSString *text = DYYYCollectViewText(target, 0);
            NSLog(@"[DYYY UpdateBlock] remove custom update view: %@ text: %@",
                  NSStringFromClass([target class]),
                  text);

            target.hidden = YES;
            target.alpha = 0.0;
            [target removeFromSuperview];
        }
    } @catch (NSException *e) {
        NSLog(@"[DYYY UpdateBlock] custom view block exception: %@", e);
    }
}

static inline BOOL DYYYShouldBlockUpdateURL(NSURL *url) {
    if (!url) return NO;

    NSString *scheme = url.scheme.lowercaseString ?: @"";
    NSString *host = url.host.lowercaseString ?: @"";
    NSString *absolute = url.absoluteString.lowercaseString ?: @"";

    if ([scheme hasPrefix:@"itms"]) return YES;
    if ([host containsString:@"apps.apple.com"]) return YES;
    if ([host containsString:@"itunes.apple.com"]) return YES;
    if ([absolute containsString:@"appstore"]) return YES;

    return NO;
}

// ========== 身份声明，防止编译报错 ==========
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

- (void)setHidden:(BOOL)hidden {
    %orig(YES);
}

- (void)setAlpha:(CGFloat)alpha {
    %orig(0.0);
}

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

- (void)setHidden:(BOOL)hidden {
    %orig(YES);
}

- (void)setAlpha:(CGFloat)alpha {
    %orig(0.0);
}

%end

// ==========================================
// 功能 3：禁用下拉刷新视频
// ==========================================
%hook AWEFeedTableViewController

- (BOOL)canRefresh {
    return NO;
}

- (void)setCanRefresh:(BOOL)arg {
    %orig(NO);
}

- (void)refreshData {
    return;
}

- (void)handlePullToRefresh {
    return;
}

- (void)pulldownToRefresh {
    return;
}

%end

%hook AWEFeedContainerViewController

- (BOOL)canRefresh {
    return NO;
}

- (void)setCanRefresh:(BOOL)arg {
    %orig(NO);
}

%end

// ==========================================
// 功能 4：禁用直播 PCDN
// ==========================================
%hook HTSLiveStreamPcdnManager

+ (void)start {
    return;
}

+ (void)configAndStartLiveIO {
    return;
}

%end

%hook IESLiveLaunchTaskPcdn

- (void)excute {
    return;
}

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
    } @catch (NSException *e) {}
}

%end

// ==========================================
// 功能 6：禁用点击首页刷新
// ==========================================
%hook AWENormalModeTabBarGeneralButton

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    @try {
        NSString *label = self.accessibilityLabel ?: @"";

        if ([label containsString:@"首页"] || [label containsString:@"𝑳𝒐𝒗𝒆"]) {
            NSNumber *statusObj = [self valueForKey:@"status"];

            if (statusObj && [statusObj integerValue] == 2) {
                return NO;
            }
        }
    } @catch (NSException *e) {}

    return %orig(point, event);
}

- (BOOL)enableRefresh {
    @try {
        NSString *label = self.accessibilityLabel ?: @"";

        if ([label containsString:@"首页"] || [label containsString:@"𝑳𝒐𝒗𝒆"]) {
            return NO;
        }
    } @catch (NSException *e) {}

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
// 功能 10 & 12：隐藏去汽水听按钮 / 刷到带汽水音乐的视频直接跳过
// ==========================================
%hook AWEAwemeModel

- (instancetype)initWithDictionary:(id)dict error:(NSError **)error {
    id orig = %orig;

    if (orig && [orig contentFilter]) {
        return nil;
    }

    return orig;
}

%new
- (BOOL)contentFilter {
    BOOL skipMusic = DYYYGetBool(@"DYYYHideQuqishuiting");

    id realAnchor = nil;
    Ivar anchorIvar = class_getInstanceVariable([self class], "_relatedMusicAnchor");

    if (anchorIvar) {
        realAnchor = object_getIvar(self, anchorIvar);
    }

    return skipMusic && realAnchor != nil;
}

- (id)relatedMusicAnchor {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) {
        return nil;
    }

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

%hook AWERelatedMusicAnchorModel

- (instancetype)init {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) {
        return nil;
    }

    return %orig;
}

- (instancetype)initWithDictionary:(id)dict error:(NSError **)error {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) {
        return nil;
    }

    return %orig;
}

%end

%hook AWEMusicExtraModel

- (id)commentTopBarInfo {
    if (DYYYGetBool(@"DYYYHideQuqishuiting")) {
        return nil;
    }

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
// 功能 11：屏蔽版本更新，稳定版
// 逻辑：作者原版 AWEVersionUpdateManager 拦截 + 系统弹窗兜底
// ==========================================
%hook AWEVersionUpdateManager

- (void)startVersionUpdateWorkflow:(id)arg1 completion:(id)arg2 {
    if (DYYYGetBool(@"DYYYNoUpdates")) {
        NSLog(@"[DYYY UpdateBlock] block startVersionUpdateWorkflow");

        // 保持作者原版逻辑：
        // 不走 %orig，但执行 completion，避免启动流程卡住。
        if (arg2) {
            void (^completionBlock)(void) = arg2;
            completionBlock();
        }

        return;
    }

    %orig;
}

- (id)workflow {
    if (DYYYGetBool(@"DYYYNoUpdates")) {
        NSLog(@"[DYYY UpdateBlock] block workflow");
        return nil;
    }

    return %orig;
}

- (id)badgeModule {
    if (DYYYGetBool(@"DYYYNoUpdates")) {
        NSLog(@"[DYYY UpdateBlock] block badgeModule");
        return nil;
    }

    return %orig;
}

%end

// ==========================================
// 更新弹窗兜底 1：拦截 UIAlertController 类型的版本更新弹窗
// ==========================================
%hook UIViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {

    @try {
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent;

            NSMutableString *alertText = [NSMutableString string];

            if (alert.title.length > 0) {
                [alertText appendString:alert.title];
                [alertText appendString:@" "];
            }

            if (alert.message.length > 0) {
                [alertText appendString:alert.message];
                [alertText appendString:@" "];
            }

            for (UIAlertAction *action in alert.actions) {
                if (action.title.length > 0) {
                    [alertText appendString:action.title];
                    [alertText appendString:@" "];
                }
            }

            if (DYYYIsUpdateAlertText(alertText)) {
                NSLog(@"[DYYY UpdateBlock] blocked update UIAlertController: %@", alertText);

                if (completion) {
                    completion();
                }

                return;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[DYYY UpdateBlock] UIAlertController block exception: %@", e);
    }

    %orig(viewControllerToPresent, flag, completion);
}

%end

// ==========================================
// 更新弹窗兜底 2：拦截抖音自定义 UIView 更新弹窗
// 适配“抖音有新版本啦 / 立即升级 / 以后再说”
// ==========================================
%hook UIView

- (void)didMoveToWindow {
    %orig;

    if (!self.window) return;

    DYYYTryRemoveCustomUpdatePopup(self);

    UIView *view = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DYYYTryRemoveCustomUpdatePopup(view);
    });
}

- (void)addSubview:(UIView *)view {
    %orig(view);

    DYYYTryRemoveCustomUpdatePopup(view);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DYYYTryRemoveCustomUpdatePopup(view);
    });
}

%end

// ==========================================
// 更新跳转兜底：防止点“立即升级”后跳 App Store
// ==========================================
%hook UIApplication

- (BOOL)openURL:(NSURL *)url {
    if (DYYYGetBool(@"DYYYNoUpdates") && DYYYShouldBlockUpdateURL(url)) {
        NSLog(@"[DYYY UpdateBlock] blocked openURL: %@", url);
        return NO;
    }

    return %orig(url);
}

- (void)openURL:(NSURL *)url
        options:(NSDictionary *)options
completionHandler:(void (^)(BOOL success))completion {

    if (DYYYGetBool(@"DYYYNoUpdates") && DYYYShouldBlockUpdateURL(url)) {
        NSLog(@"[DYYY UpdateBlock] blocked openURL options: %@", url);

        if (completion) {
            completion(NO);
        }

        return;
    }

    %orig(url, options, completion);
}

%end
