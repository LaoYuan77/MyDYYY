#import <UIKit/UIKit.h>
#import <objc/runtime.h> 

// ========== 设置开关：NSUserDefaults 持久化，首次默认全部开启 ==========
static NSString *const DYYYSettingDefaultEnabledKey = @"__DYYYDefaultEnabled";

static inline NSArray<NSDictionary *> *DYYYSettingItems(void) {
    return @[
        @{@"key": @"DYYYHideFeedTabJumpGuide", @"title": @"隐藏双列箭头", @"desc": @"隐藏首页双列/跳转引导箭头"},
        @{@"key": @"DYYYHideTopTabLine", @"title": @"隐藏顶栏横线", @"desc": @"隐藏顶栏选中横线/容器"},
        @{@"key": @"DYYYDisablePullRefresh", @"title": @"禁用下拉刷新", @"desc": @"阻止首页下拉刷新视频"},
        @{@"key": @"DYYYDisableLivePCDN", @"title": @"禁用直播 PCDN", @"desc": @"阻止直播 PCDN 相关启动任务"},
        @{@"key": @"DYYYChangeHomeTabText", @"title": @"首页改成 𝑳𝒐𝒗𝒆", @"desc": @"把底栏首页文字替换为 𝑳𝒐𝒗𝒆"},
        @{@"key": @"DYYYDisableHomeRefresh", @"title": @"禁用点击首页刷新", @"desc": @"再次点击首页时不刷新推荐流"},
        @{@"key": @"DYYYHideCommentViews", @"title": @"隐藏搜索词模型", @"desc": @"隐藏相关搜索/观看历史搜索词"},
        @{@"key": @"DYYYHideInteractionSearch", @"title": @"隐藏视频页搜索锚点", @"desc": @"隐藏播放页相关搜索入口"},
        @{@"key": @"DYYYHideHotSearch", @"title": @"隐藏弹出热搜框", @"desc": @"隐藏底部弹出的热搜/搜索框"},
        @{@"key": @"DYYYHideHotspot", @"title": @"隐藏热点提示", @"desc": @"隐藏热点列表/热点提示文案"},
        @{@"key": @"DYYYHideMessageTabRedPacket", @"title": @"隐藏消息页红包", @"desc": @"隐藏消息顶栏红包入口"},
        @{@"key": @"DYYYHideQishuiMusicAnchor", @"title": @"隐藏汽水音乐入口", @"desc": @"隐藏去汽水听按钮/音乐锚点"},
        @{@"key": @"DYYYSkipQishuiMusicVideo", @"title": @"跳过汽水音乐视频", @"desc": @"刷到带汽水音乐锚点的视频时直接过滤"},
        @{@"key": @"DYYYNoUpdates", @"title": @"拦截版本更新", @"desc": @"屏蔽抖音更新弹窗和 App Store 跳转"}
    ];
}

static inline BOOL DYYYGetBool(NSString *key) {
    if (!key || key.length == 0) return NO;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id value = [defaults objectForKey:key];

    // 兼容你之前“全部默认生效”的逻辑：没有保存过设置时默认开启。
    if (value == nil) return YES;

    return [defaults boolForKey:key];
}

static inline void DYYYSetBool(NSString *key, BOOL enabled) {
    if (!key || key.length == 0) return;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enabled forKey:key];
    [defaults synchronize];
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

    // 避免把本插件设置/记录文本误判成更新弹窗
    if ([text containsString:@"DYYY 更新拦截状态"] ||
        [text containsString:@"DYYY 设置"] ||
        [text containsString:@"更新拦截记录"] ||
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


// ========== 更新拦截记录：静默保存，设置页查看 ==========
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

// ========== 设置 UI：双指长按打开，更新拦截记录在这里查看 ==========
static inline void DYYYClearUpdateBlockHistory(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:DYYYUpdateBlockCountKey];
    [defaults removeObjectForKey:DYYYUpdateBlockLastTimeKey];
    [defaults removeObjectForKey:DYYYUpdateBlockLastSourceKey];
    [defaults removeObjectForKey:DYYYUpdateBlockLastTextKey];
    [defaults removeObjectForKey:DYYYUpdateBlockHistoryKey];
    [defaults synchronize];
}

static inline NSString *DYYYUpdateBlockSummaryText(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger count = [defaults integerForKey:DYYYUpdateBlockCountKey];
    NSString *time = [defaults stringForKey:DYYYUpdateBlockLastTimeKey] ?: @"暂无";
    NSString *source = [defaults stringForKey:DYYYUpdateBlockLastSourceKey] ?: @"暂无";
    NSString *lastText = [defaults stringForKey:DYYYUpdateBlockLastTextKey] ?: @"暂无";

    if (lastText.length > 260) {
        lastText = [[lastText substringToIndex:260] stringByAppendingString:@"..."];
    }

    return [NSString stringWithFormat:@"拦截次数：%ld\n最近时间：%@\n最近来源：%@\n最近文案：%@",
            (long)count, time, source, lastText];
}

@interface DYYYSettingsViewController : UITableViewController
@property (nonatomic, strong) NSArray<NSDictionary *> *items;
@end

static inline UIColor *DYYYPrimaryTextColor(void) {
    if (@available(iOS 13.0, *)) {
        return UIColor.labelColor;
    }

    return UIColor.blackColor;
}

static inline UIColor *DYYYSecondaryTextColor(void) {
    if (@available(iOS 13.0, *)) {
        return UIColor.secondaryLabelColor;
    }

    return UIColor.darkGrayColor;
}

@implementation DYYYSettingsViewController

- (instancetype)init {
    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) {
        style = UITableViewStyleInsetGrouped;
    }

    self = [super initWithStyle:style];
    if (self) {
        self.items = DYYYSettingItems();
        self.title = @"DYYY 设置";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64.0;

    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithTitle:@"完成"
                                                                  style:UIBarButtonItemStyleDone
                                                                 target:self
                                                                 action:@selector(dyyy_close)];
    self.navigationItem.rightBarButtonItem = closeItem;
}

- (void)dyyy_close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.items.count;

    NSArray *history = [[NSUserDefaults standardUserDefaults] arrayForKey:DYYYUpdateBlockHistoryKey];
    NSInteger historyCount = MIN((NSInteger)history.count, 20);

    // 0 = 摘要，1 = 手动扫描，2 = 清空记录，3... = 历史
    return 3 + historyCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"功能开关" : @"更新拦截记录";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"所有开关默认开启。关闭某项后立即保存，部分界面类功能可能需要重新进入页面或重启抖音才完全恢复。";
    }

    return @"这里显示的是静默拦截历史，不再使用摇一摇弹窗，避免记录窗口一闪而过。";
}

- (UITableViewCell *)dyyy_switchCellForTableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DYYYSwitchCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DYYYSwitchCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.numberOfLines = 1;
        cell.detailTextLabel.numberOfLines = 2;
    }

    NSDictionary *item = self.items[indexPath.row];
    NSString *key = item[@"key"] ?: @"";

    cell.textLabel.text = item[@"title"] ?: key;
    cell.detailTextLabel.text = item[@"desc"] ?: @"";

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = DYYYGetBool(key);
    objc_setAssociatedObject(toggle, @selector(dyyy_switchChanged:), key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [toggle addTarget:self action:@selector(dyyy_switchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;

    return cell;
}

- (UITableViewCell *)dyyy_recordCellForTableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DYYYRecordCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DYYYRecordCell"];
        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.numberOfLines = 0;
    }

    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.textColor = DYYYPrimaryTextColor();
    cell.detailTextLabel.textColor = DYYYSecondaryTextColor();

    if (indexPath.row == 0) {
        cell.textLabel.text = @"最近状态";
        cell.detailTextLabel.text = DYYYUpdateBlockSummaryText();
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    if (indexPath.row == 1) {
        cell.textLabel.text = @"手动扫描当前更新弹窗";
        cell.detailTextLabel.text = @"如果弹窗正在屏幕上，点这里会扫描并尝试移除，同时写入历史记录。";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    if (indexPath.row == 2) {
        cell.textLabel.text = @"清空拦截记录";
        cell.detailTextLabel.text = @"只清空本页历史，不影响功能开关。";
        cell.textLabel.textColor = UIColor.systemRedColor;
        return cell;
    }

    NSArray *history = [[NSUserDefaults standardUserDefaults] arrayForKey:DYYYUpdateBlockHistoryKey];
    NSInteger historyIndex = indexPath.row - 3;

    if (historyIndex >= 0 && historyIndex < (NSInteger)history.count) {
        id obj = history[historyIndex];
        if ([obj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *record = (NSDictionary *)obj;
            NSString *time = record[@"time"] ?: @"";
            NSString *source = record[@"source"] ?: @"";
            NSString *text = record[@"text"] ?: @"";

            cell.textLabel.text = [NSString stringWithFormat:@"%ld. %@", (long)(historyIndex + 1), time.length ? time : @"无时间"];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@", source.length ? source : @"未知来源", text.length ? text : @"无文案"];
        }
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return [self dyyy_switchCellForTableView:tableView indexPath:indexPath];
    }

    return [self dyyy_recordCellForTableView:tableView indexPath:indexPath];
}

- (void)dyyy_switchChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, @selector(dyyy_switchChanged:));
    if (key.length == 0) return;

    DYYYSetBool(key, sender.isOn);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section != 1) return;

    if (indexPath.row == 1) {
        BOOL removed = DYYYScanAndRemoveCustomUpdatePopup(@"设置页手动扫描");
        NSString *message = removed ? @"发现并移除了疑似更新弹窗，已写入记录。" : @"当前没有发现正在显示的更新弹窗。";

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"扫描完成"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        return;
    }

    if (indexPath.row == 2) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空拦截记录？"
                                                                       message:@"这只会清空历史记录，不会关闭更新拦截。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            DYYYClearUpdateBlockHistory();
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

@end

static void DYYYShowSettingsPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIViewController *vc = DYYYTopViewController();
            if (!vc) return;

            NSString *className = NSStringFromClass([vc class]);
            if ([className containsString:@"DYYYSettingsViewController"]) return;
            if ([vc isKindOfClass:[UIAlertController class]]) return;

            DYYYSettingsViewController *settingsVC = [[DYYYSettingsViewController alloc] init];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
            nav.modalPresentationStyle = UIModalPresentationFullScreen;

            [vc presentViewController:nav animated:YES completion:nil];
        } @catch (NSException *e) {
            NSLog(@"[DYYY Settings] present exception: %@", e);
        }
    });
}

@interface DYYYGestureHandler : NSObject
+ (instancetype)sharedHandler;
- (void)handleTwoFingerLongPress:(UILongPressGestureRecognizer *)gesture;
@end

@implementation DYYYGestureHandler

+ (instancetype)sharedHandler {
    static DYYYGestureHandler *handler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[DYYYGestureHandler alloc] init];
    });
    return handler;
}

- (void)handleTwoFingerLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    static NSTimeInterval lastShowTime = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - lastShowTime < 1.5) return;
    lastShowTime = now;

    DYYYShowSettingsPanel();
}

@end

static void DYYYAttachSettingsGestureToView(UIView *view) {
    if (!view) return;

    @try {
        static const void *DYYYSettingsGestureInstalledKey = &DYYYSettingsGestureInstalledKey;
        NSNumber *installed = objc_getAssociatedObject(view, DYYYSettingsGestureInstalledKey);
        if (installed.boolValue) return;

        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:[DYYYGestureHandler sharedHandler]
                                                                                              action:@selector(handleTwoFingerLongPress:)];
        gesture.numberOfTouchesRequired = 2;
        gesture.minimumPressDuration = 0.75;
        gesture.cancelsTouchesInView = NO;
        gesture.delaysTouchesBegan = NO;
        gesture.delaysTouchesEnded = NO;

        [view addGestureRecognizer:gesture];
        objc_setAssociatedObject(view, DYYYSettingsGestureInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch (NSException *e) {
        NSLog(@"[DYYY Settings] attach gesture exception: %@", e);
    }
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

    if (DYYYGetBool(@"DYYYHideFeedTabJumpGuide")) {
        self.alpha = 0.0;
        self.hidden = YES;
        [self removeFromSuperview];
    }
}

- (void)setHidden:(BOOL)hidden {
    if (DYYYGetBool(@"DYYYHideFeedTabJumpGuide")) {
        %orig(YES);
        return;
    }

    %orig(hidden);
}

- (void)setAlpha:(CGFloat)alpha {
    if (DYYYGetBool(@"DYYYHideFeedTabJumpGuide")) {
        %orig(0.0);
        return;
    }

    %orig(alpha);
}

%end

// ==========================================
// 功能 2：隐藏顶栏横线
// ==========================================
%hook AWEFeedMultiTabSelectedContainerView

- (void)layoutSubviews {
    %orig;

    if (DYYYGetBool(@"DYYYHideTopTabLine")) {
        self.alpha = 0.0;
        self.hidden = YES;
    }
}

- (void)setHidden:(BOOL)hidden {
    if (DYYYGetBool(@"DYYYHideTopTabLine")) {
        %orig(YES);
        return;
    }

    %orig(hidden);
}

- (void)setAlpha:(CGFloat)alpha {
    if (DYYYGetBool(@"DYYYHideTopTabLine")) {
        %orig(0.0);
        return;
    }

    %orig(alpha);
}

%end

// ==========================================
// 功能 3：禁用下拉刷新视频
// ==========================================
%hook AWEFeedTableViewController

- (BOOL)canRefresh {
    if (DYYYGetBool(@"DYYYDisablePullRefresh")) return NO;
    return %orig;
}

- (void)setCanRefresh:(BOOL)arg {
    if (DYYYGetBool(@"DYYYDisablePullRefresh")) {
        %orig(NO);
        return;
    }

    %orig(arg);
}

- (void)refreshData {
    if (DYYYGetBool(@"DYYYDisablePullRefresh")) return;
    %orig;
}

- (void)handlePullToRefresh {
    if (DYYYGetBool(@"DYYYDisablePullRefresh")) return;
    %orig;
}

- (void)pulldownToRefresh {
    if (DYYYGetBool(@"DYYYDisablePullRefresh")) return;
    %orig;
}

%end

%hook AWEFeedContainerViewController

- (BOOL)canRefresh {
    if (DYYYGetBool(@"DYYYDisablePullRefresh")) return NO;
    return %orig;
}

- (void)setCanRefresh:(BOOL)arg {
    if (DYYYGetBool(@"DYYYDisablePullRefresh")) {
        %orig(NO);
        return;
    }

    %orig(arg);
}

%end

// ==========================================
// 功能 4：禁用直播 PCDN
// ==========================================
%hook HTSLiveStreamPcdnManager

+ (void)start {
    if (DYYYGetBool(@"DYYYDisableLivePCDN")) return;
    %orig;
}

+ (void)configAndStartLiveIO {
    if (DYYYGetBool(@"DYYYDisableLivePCDN")) return;
    %orig;
}

%end

%hook IESLiveLaunchTaskPcdn

- (void)excute {
    if (DYYYGetBool(@"DYYYDisableLivePCDN")) return;
    %orig;
}

%end

// ==========================================
// 功能 5：将底栏“首页”文字修改为“𝑳𝒐𝒗𝒆”
// ==========================================
%hook AWENormalModeTabBarTextView

- (void)layoutSubviews {
    %orig;

    if (!DYYYGetBool(@"DYYYChangeHomeTabText")) return;

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
    if (DYYYGetBool(@"DYYYDisableHomeRefresh")) {
        @try {
            NSString *label = self.accessibilityLabel ?: @"";

            if ([label containsString:@"首页"] || [label containsString:@"𝑳𝒐𝒗𝒆"]) {
                NSNumber *statusObj = [self valueForKey:@"status"];

                if (statusObj && [statusObj integerValue] == 2) {
                    return NO;
                }
            }
        } @catch (NSException *e) {}
    }

    return %orig(point, event);
}

- (BOOL)enableRefresh {
    if (DYYYGetBool(@"DYYYDisableHomeRefresh")) {
        @try {
            NSString *label = self.accessibilityLabel ?: @"";

            if ([label containsString:@"首页"] || [label containsString:@"𝑳𝒐𝒗𝒆"]) {
                return NO;
            }
        } @catch (NSException *e) {}
    }

    return %orig;
}

%end

// ==========================================
// 功能 7：隐藏相关搜索 / 观看历史搜索
// ==========================================
%hook AWESearchAnchorListModel

- (BOOL)hideWords {
    if (DYYYGetBool(@"DYYYHideCommentViews")) return YES;
    return %orig;
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

    if (orig && DYYYGetBool(@"DYYYSkipQishuiMusicVideo") && [orig contentFilter]) {
        return nil;
    }

    return orig;
}

%new
- (BOOL)contentFilter {
    BOOL skipMusic = DYYYGetBool(@"DYYYSkipQishuiMusicVideo");

    id realAnchor = nil;
    Ivar anchorIvar = class_getInstanceVariable([self class], "_relatedMusicAnchor");

    if (anchorIvar) {
        realAnchor = object_getIvar(self, anchorIvar);
    }

    return skipMusic && realAnchor != nil;
}

- (id)relatedMusicAnchor {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) {
        return nil;
    }

    return %orig;
}

- (void)setRelatedMusicAnchor:(id)anchor {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) {
        %orig(nil);
        return;
    }

    %orig;
}

%end

%hook AWERelatedMusicAnchorModel

- (instancetype)init {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) {
        return nil;
    }

    return %orig;
}

- (instancetype)initWithDictionary:(id)dict error:(NSError **)error {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) {
        return nil;
    }

    return %orig;
}

%end

%hook AWEMusicExtraModel

- (id)commentTopBarInfo {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) {
        return nil;
    }

    return %orig;
}

- (void)setCommentTopBarInfo:(id)info {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) {
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

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);

    @try {
        // 不在设置页自身重复安装，避免长按时反复打开。
        NSString *className = NSStringFromClass([self class]);
        if ([className containsString:@"DYYYSettingsViewController"]) return;

        DYYYAttachSettingsGestureToView(self.view);
    } @catch (NSException *e) {}
}

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
// 设置入口已改为双指长按；不再使用摇一摇弹出拦截记录
// ==========================================

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
