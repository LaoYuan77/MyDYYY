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

    // 避免把摇一摇调试框误判成更新弹窗
    if ([text containsString:@"DYYY 更新拦截状态"] ||
        [text containsString:@"拦截次数"] ||
        [text containsString:@"最近文案"]) {
        return NO;
    }

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


// ========== 更新拦截记录：静默记录 + 摇一摇查看 ==========
static NSString *const DYYYUpdateBlockCountKey = @"DYYYUpdateBlockCount";
static NSString *const DYYYUpdateBlockLastTimeKey = @"DYYYUpdateBlockLastTime";
static NSString *const DYYYUpdateBlockLastSourceKey = @"DYYYUpdateBlockLastSource";
static NSString *const DYYYUpdateBlockLastTextKey = @"DYYYUpdateBlockLastText";
static NSString *const DYYYUpdateBlockHistoryKey = @"DYYYUpdateBlockHistory";

static inline NSString *DYYYCurrentTimeString(void) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [formatter stringFromDate:[NSDate date]];
}

static inline NSString *DYYYSafeRecordText(NSString *text) {
    if (!text || text.length == 0) return @"";

    NSString *result = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    result = [result stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    while ([result containsString:@"  "]) {
        result = [result stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }

    if (result.length > 700) {
        result = [[result substringToIndex:700] stringByAppendingString:@"..."];
    }

    return result;
}

static inline void DYYYRecordUpdateBlock(NSString *source, NSString *text) {
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSInteger count = [defaults integerForKey:DYYYUpdateBlockCountKey];

        NSString *timeString = DYYYCurrentTimeString();
        NSString *safeSource = DYYYSafeRecordText(source ?: @"未知来源");
        NSString *safeText = DYYYSafeRecordText(text ?: @"");

        [defaults setInteger:(count + 1) forKey:DYYYUpdateBlockCountKey];
        [defaults setObject:timeString forKey:DYYYUpdateBlockLastTimeKey];
        [defaults setObject:safeSource forKey:DYYYUpdateBlockLastSourceKey];
        [defaults setObject:safeText forKey:DYYYUpdateBlockLastTextKey];

        // 额外保存最近 20 条历史，避免只看“最近一次”不够用。
        NSArray *oldHistory = [defaults arrayForKey:DYYYUpdateBlockHistoryKey];
        NSMutableArray *history = oldHistory ? [oldHistory mutableCopy] : [NSMutableArray array];
        NSDictionary *record = @{
            @"time": timeString ?: @"",
            @"source": safeSource ?: @"",
            @"text": safeText ?: @""
        };

        [history insertObject:record atIndex:0];
        while (history.count > 20) {
            [history removeLastObject];
        }

        [defaults setObject:history forKey:DYYYUpdateBlockHistoryKey];
        [defaults synchronize];
    } @catch (NSException *e) {}
}

static NSArray<UIWindow *> *DYYYAllWindows(void) {
    NSMutableArray<UIWindow *> *result = [NSMutableArray array];

    @try {
        UIApplication *app = [UIApplication sharedApplication];

        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in app.connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;

                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window && ![result containsObject:window]) {
                        [result addObject:window];
                    }
                }
            }
        }

        // 用 KVC 兜底，避免直接调用 UIApplication.windows / keyWindow 触发 deprecated 编译错误
        NSArray *windows = [app valueForKey:@"windows"];
        for (id obj in windows) {
            if ([obj isKindOfClass:[UIWindow class]] && ![result containsObject:obj]) {
                [result addObject:obj];
            }
        }
    } @catch (NSException *e) {}

    return result;
}

static UIWindow *DYYYFindActiveWindow(void) {
    UIWindow *fallback = nil;

    for (UIWindow *window in DYYYAllWindows()) {
        if (window.hidden || window.alpha <= 0.01) continue;

        if (window.isKeyWindow) return window;

        if (!fallback && window.rootViewController) {
            fallback = window;
        }
    }

    return fallback;
}

static UIViewController *DYYYTopViewController(void) {
    UIWindow *window = DYYYFindActiveWindow();
    if (!window) return nil;

    UIViewController *vc = window.rootViewController;

    @try {
        BOOL changed = YES;
        while (changed && vc) {
            changed = NO;

            if (vc.presentedViewController) {
                vc = vc.presentedViewController;
                changed = YES;
                continue;
            }

            if ([vc isKindOfClass:[UINavigationController class]]) {
                UIViewController *visibleVC = ((UINavigationController *)vc).visibleViewController;
                if (visibleVC) {
                    vc = visibleVC;
                    changed = YES;
                    continue;
                }
            }

            if ([vc isKindOfClass:[UITabBarController class]]) {
                UIViewController *selectedVC = ((UITabBarController *)vc).selectedViewController;
                if (selectedVC) {
                    vc = selectedVC;
                    changed = YES;
                    continue;
                }
            }
        }
    } @catch (NSException *e) {}

    return vc;
}

static inline void DYYYAppendLimitedText(NSMutableString *result, id value) {
    if (!result || !value || result.length > 3000) return;

    @try {
        NSString *text = nil;

        if ([value isKindOfClass:[NSString class]]) {
            text = (NSString *)value;
        } else if ([value respondsToSelector:@selector(string)]) {
            text = [value string];
        }

        if (text.length > 0) {
            [result appendString:text];
            [result appendString:@" "];
        }
    } @catch (NSException *e) {}
}

static NSString *DYYYCollectVisibleViewText(UIView *view, NSInteger depth) {
    if (!view || depth > 7) return @"";
    if (view.hidden || view.alpha <= 0.01) return @"";

    NSMutableString *result = [NSMutableString string];

    @try {
        DYYYAppendLimitedText(result, view.accessibilityLabel);
        DYYYAppendLimitedText(result, view.accessibilityValue);
        DYYYAppendLimitedText(result, view.accessibilityHint);

        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            DYYYAppendLimitedText(result, label.text);
            DYYYAppendLimitedText(result, label.attributedText);
        } else if ([view isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)view;
            UIControlState states[] = {UIControlStateNormal, UIControlStateHighlighted, UIControlStateSelected, UIControlStateDisabled};

            for (int i = 0; i < 4; i++) {
                DYYYAppendLimitedText(result, [button titleForState:states[i]]);
                DYYYAppendLimitedText(result, [button attributedTitleForState:states[i]]);
            }

            DYYYAppendLimitedText(result, button.titleLabel.text);
            DYYYAppendLimitedText(result, button.titleLabel.attributedText);
        } else if ([view isKindOfClass:[UITextView class]]) {
            UITextView *textView = (UITextView *)view;
            DYYYAppendLimitedText(result, textView.text);
            DYYYAppendLimitedText(result, textView.attributedText);
        } else if ([view isKindOfClass:[UITextField class]]) {
            UITextField *textField = (UITextField *)view;
            DYYYAppendLimitedText(result, textField.text);
            DYYYAppendLimitedText(result, textField.attributedText);
            DYYYAppendLimitedText(result, textField.placeholder);
        }

        NSArray<UIView *> *subviews = [view.subviews copy];
        for (UIView *subview in subviews) {
            if (result.length > 3000) break;
            DYYYAppendLimitedText(result, DYYYCollectVisibleViewText(subview, depth + 1));
        }
    } @catch (NSException *e) {}

    return result;
}

static inline BOOL DYYYIsCustomUpdateText(NSString *text) {
    if (!text || text.length == 0) return NO;
    if (DYYYIsUpdateAlertText(text)) return YES;

    BOOL hasDouyinUpdateTitle =
        [text containsString:@"抖音有新版本"] ||
        [text containsString:@"有新版本啦"] ||
        [text containsString:@"发现新版本"];

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

static inline BOOL DYYYLooksLikePopupCard(UIView *view) {
    if (!view) return NO;

    CGSize screenSize = UIScreen.mainScreen.bounds.size;
    CGFloat screenW = screenSize.width;
    CGFloat screenH = screenSize.height;
    CGFloat w = view.bounds.size.width;
    CGFloat h = view.bounds.size.height;

    if (w <= 0 || h <= 0) return NO;

    return w >= 160 && h >= 110 && w <= screenW * 0.98 && h <= screenH * 0.88;
}

static inline BOOL DYYYLooksLikeOverlay(UIView *view) {
    if (!view) return NO;

    CGSize screenSize = UIScreen.mainScreen.bounds.size;
    CGFloat screenW = screenSize.width;
    CGFloat screenH = screenSize.height;
    CGFloat w = view.bounds.size.width;
    CGFloat h = view.bounds.size.height;

    return w >= screenW * 0.85 && h >= screenH * 0.70;
}

static UIView *DYYYBestPopupRemoveTarget(UIView *card) {
    if (!card) return nil;

    UIView *target = card;
    UIView *parent = card.superview;
    NSInteger upCount = 0;

    while (parent && ![parent isKindOfClass:[UIWindow class]] && upCount < 4) {
        if (DYYYLooksLikeOverlay(parent) && parent.subviews.count <= 10) {
            target = parent;
        }

        parent = parent.superview;
        upCount++;
    }

    return target;
}

static UIView *DYYYFindCustomUpdatePopupTarget(UIView *view, NSInteger depth) {
    if (!view || depth > 8) return nil;
    if (view.hidden || view.alpha <= 0.01) return nil;

    @try {
        if (![view isKindOfClass:[UIWindow class]] && DYYYLooksLikePopupCard(view)) {
            NSString *text = DYYYCollectVisibleViewText(view, 0);
            if (DYYYIsCustomUpdateText(text)) {
                return DYYYBestPopupRemoveTarget(view);
            }
        }

        NSArray<UIView *> *subviews = [view.subviews copy];
        for (UIView *subview in subviews) {
            UIView *target = DYYYFindCustomUpdatePopupTarget(subview, depth + 1);
            if (target) return target;
        }
    } @catch (NSException *e) {}

    return nil;
}

static BOOL DYYYScanAndRemoveCustomUpdatePopup(NSString *source) {
    if (!DYYYGetBool(@"DYYYNoUpdates")) return NO;

    __block BOOL removed = NO;

    void (^scanBlock)(void) = ^{
        @try {
            for (UIWindow *window in DYYYAllWindows()) {
                if (!window || window.hidden || window.alpha <= 0.01) continue;

                UIView *target = DYYYFindCustomUpdatePopupTarget(window, 0);
                if (!target || [target isKindOfClass:[UIWindow class]]) continue;

                NSString *text = DYYYCollectVisibleViewText(target, 0);
                DYYYRecordUpdateBlock(source ?: @"自定义 UIView 更新弹窗", text);
                NSLog(@"[DYYY UpdateBlock] remove custom update view: %@ text: %@", NSStringFromClass([target class]), text);

                target.hidden = YES;
                target.alpha = 0.0;
                [target removeFromSuperview];
                removed = YES;
                break;
            }
        } @catch (NSException *e) {
            NSLog(@"[DYYY UpdateBlock] safe scan exception: %@", e);
        }
    };

    if ([NSThread isMainThread]) {
        scanBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), scanBlock);
    }

    return removed;
}

static void DYYYShowUpdateBlockDebugPanel(BOOL removedThisTime) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIViewController *vc = DYYYTopViewController();
            if (!vc || [vc isKindOfClass:[UIAlertController class]]) return;

            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSInteger count = [defaults integerForKey:DYYYUpdateBlockCountKey];
            NSString *time = [defaults stringForKey:DYYYUpdateBlockLastTimeKey] ?: @"暂无";
            NSString *source = [defaults stringForKey:DYYYUpdateBlockLastSourceKey] ?: @"暂无";
            NSString *lastText = [defaults stringForKey:DYYYUpdateBlockLastTextKey] ?: @"暂无";
            NSString *scanStatus = removedThisTime ? @"本次摇一摇扫描：发现并移除了疑似更新弹窗" : @"本次摇一摇扫描：未发现正在显示的更新弹窗";

            NSMutableString *historyText = [NSMutableString string];
            NSArray *history = [defaults arrayForKey:DYYYUpdateBlockHistoryKey];
            NSInteger maxCount = MIN((NSInteger)history.count, 5);

            for (NSInteger i = 0; i < maxCount; i++) {
                id item = history[i];
                if (![item isKindOfClass:[NSDictionary class]]) continue;

                NSDictionary *record = (NSDictionary *)item;
                NSString *hTime = [record objectForKey:@"time"] ?: @"";
                NSString *hSource = [record objectForKey:@"source"] ?: @"";
                NSString *hText = [record objectForKey:@"text"] ?: @"";

                if (hText.length > 120) {
                    hText = [[hText substringToIndex:120] stringByAppendingString:@"..."];
                }

                [historyText appendFormat:@"\n%ld. %@\n%@\n%@\n", (long)(i + 1), hTime, hSource, hText];
            }

            if (historyText.length == 0) {
                [historyText appendString:@"\n暂无历史记录"];
            }

            NSString *message = [NSString stringWithFormat:
                @"%@\n\n拦截次数：%ld\n最近时间：%@\n最近来源：%@\n\n最近文案：\n%@\n\n最近 5 条历史：%@",
                scanStatus,
                (long)count,
                time,
                source,
                lastText,
                historyText
            ];

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DYYY 更新拦截状态"
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];

            // 只保留关闭按钮，避免误点清空记录。
            [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];

            [vc presentViewController:alert animated:YES completion:nil];
        } @catch (NSException *e) {}
    });
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
        DYYYRecordUpdateBlock(@"AWEVersionUpdateManager startVersionUpdateWorkflow", @"已阻止版本更新流程");

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
// 更新弹窗兜底：拦截 UIAlertController 类型的版本更新弹窗
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
                DYYYRecordUpdateBlock(@"UIAlertController 更新弹窗", alertText);

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
// 更新跳转兜底：防止点“立即升级”后跳 App Store
// ==========================================
%hook UIApplication

- (BOOL)openURL:(NSURL *)url {
    if (DYYYGetBool(@"DYYYNoUpdates") && DYYYShouldBlockUpdateURL(url)) {
        NSLog(@"[DYYY UpdateBlock] blocked openURL: %@", url);
        DYYYRecordUpdateBlock(@"App Store 跳转 openURL", url.absoluteString ?: @"");
        return NO;
    }

    return %orig(url);
}

- (void)openURL:(NSURL *)url
        options:(NSDictionary *)options
completionHandler:(void (^)(BOOL success))completion {

    if (DYYYGetBool(@"DYYYNoUpdates") && DYYYShouldBlockUpdateURL(url)) {
        NSLog(@"[DYYY UpdateBlock] blocked openURL options: %@", url);
        DYYYRecordUpdateBlock(@"App Store 跳转 openURL options", url.absoluteString ?: @"");

        if (completion) {
            completion(NO);
        }

        return;
    }

    %orig(url, options, completion);
}

%end

// ==========================================
// 调试入口：摇一摇查看更新拦截记录
// 说明：这一版不再 hook 全局 UIView，避免开屏卡死/闪退。
// 如果更新弹窗刚好出现，可以摇一摇，代码会先扫描并尝试移除，再显示记录。
// ==========================================
%hook UIResponder

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig;

    if (motion != UIEventSubtypeMotionShake) return;
    if (!DYYYGetBool(@"DYYYNoUpdates")) return;

    static NSTimeInterval lastShowTime = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - lastShowTime < 1.5) return;
    lastShowTime = now;

    BOOL removed = DYYYScanAndRemoveCustomUpdatePopup(@"摇一摇手动扫描");
    DYYYShowUpdateBlockDebugPanel(removed);
}

%end

// ==========================================
// 启动 / 回到前台后延迟扫描：不 hook 全局 UIView，避免开屏卡死/闪退
// ==========================================
static void DYYYScheduleUpdateBlockScans(NSString *source) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray<NSNumber *> *delays = @[@0.3, @0.8, @1.5, @2.5, @4.0, @6.0, @9.0, @13.0, @18.0, @25.0];

        for (NSNumber *delayNumber in delays) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayNumber.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                DYYYScanAndRemoveCustomUpdatePopup(source ?: @"延迟扫描");
            });
        }
    });
}

%ctor {
    DYYYScheduleUpdateBlockScans(@"启动延迟扫描");

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        DYYYScheduleUpdateBlockScans(@"进入前台延迟扫描");
    }];
}
