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
        @{@"key": @"DYYYNoUpdates", @"title": @"拦截版本更新", @"desc": @"屏蔽抖音版本更新流程"}
    ];
}

static inline BOOL DYYYGetBool(NSString *key) {
    if (!key || key.length == 0) return NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id value = [defaults objectForKey:key];
    if (value == nil) return YES;
    return [defaults boolForKey:key];
}

static inline void DYYYSetBool(NSString *key, BOOL enabled) {
    if (!key || key.length == 0) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enabled forKey:key];
    [defaults synchronize];
}

// ========== 顶层 VC 查找：用于弹出设置面板 ==========
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
        if (!fallback && window.rootViewController) fallback = window;
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
            if (vc.presentedViewController) { vc = vc.presentedViewController; changed = YES; continue; }
            if ([vc isKindOfClass:[UINavigationController class]]) {
                UIViewController *visibleVC = ((UINavigationController *)vc).visibleViewController;
                if (visibleVC) { vc = visibleVC; changed = YES; continue; }
            }
            if ([vc isKindOfClass:[UITabBarController class]]) {
                UIViewController *selectedVC = ((UITabBarController *)vc).selectedViewController;
                if (selectedVC) { vc = selectedVC; changed = YES; continue; }
            }
        }
    } @catch (NSException *e) {}
    return vc;
}

// ========== 液态玻璃风格设置面板 ==========
static inline UIColor *DYYYPrimaryTextColor(void) {
    if (@available(iOS 13.0, *)) return UIColor.labelColor;
    return UIColor.blackColor;
}

static inline UIColor *DYYYSecondaryTextColor(void) {
    if (@available(iOS 13.0, *)) return UIColor.secondaryLabelColor;
    return UIColor.darkGrayColor;
}

static inline UIBlurEffect *DYYYLiquidBlurEffect(void) {
    if (@available(iOS 13.0, *)) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
}

@interface DYYYSettingsViewController : UITableViewController
@property (nonatomic, strong) NSArray<NSDictionary *> *items;
@property (nonatomic, weak) UIVisualEffectView *backgroundBlurView;
@end

@implementation DYYYSettingsViewController

- (instancetype)init {
    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) style = UITableViewStyleInsetGrouped;
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

    // 全屏液态背景：渐变彩色 + 毛玻璃
    UIView *gradientHost = [[UIView alloc] initWithFrame:self.view.bounds];
    gradientHost.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = gradientHost.bounds;
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.62 green:0.78 blue:1.00 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.85 green:0.70 blue:1.00 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:1.00 green:0.78 blue:0.88 alpha:1.0].CGColor
    ];
    gradient.startPoint = CGPointMake(0.0, 0.0);
    gradient.endPoint = CGPointMake(1.0, 1.0);
    [gradientHost.layer addSublayer:gradient];

    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:DYYYLiquidBlurEffect()];
    blur.frame = self.view.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIView *backgroundContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    backgroundContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [backgroundContainer addSubview:gradientHost];
    [backgroundContainer addSubview:blur];

    self.tableView.backgroundView = backgroundContainer;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.backgroundBlurView = blur;

    [gradientHost.layer setNeedsLayout];

    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithTitle:@"完成"
                                                                  style:UIBarButtonItemStyleDone
                                                                 target:self
                                                                 action:@selector(dyyy_close)];
    self.navigationItem.rightBarButtonItem = closeItem;

    // 导航栏也做成毛玻璃透明
    UINavigationBar *bar = self.navigationController.navigationBar;
    if (bar) {
        if (@available(iOS 13.0, *)) {
            UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
            [appearance configureWithTransparentBackground];
            appearance.backgroundEffect = DYYYLiquidBlurEffect();
            appearance.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
            appearance.titleTextAttributes = @{ NSForegroundColorAttributeName: DYYYPrimaryTextColor() };
            bar.standardAppearance = appearance;
            bar.scrollEdgeAppearance = appearance;
            if (@available(iOS 15.0, *)) bar.compactScrollEdgeAppearance = appearance;
        } else {
            [bar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
            bar.shadowImage = [UIImage new];
            bar.translucent = YES;
        }
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIView *bg = self.tableView.backgroundView;
    if (bg.subviews.count > 0) {
        UIView *gradientHost = bg.subviews.firstObject;
        for (CALayer *layer in gradientHost.layer.sublayers) {
            if ([layer isKindOfClass:[CAGradientLayer class]]) layer.frame = gradientHost.bounds;
        }
    }
}

- (void)dyyy_close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"功能开关";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"所有开关默认开启。关闭某项后立即保存，部分界面类功能可能需要重新进入页面或重启抖音才完全恢复。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DYYYSwitchCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DYYYSwitchCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.numberOfLines = 1;
        cell.detailTextLabel.numberOfLines = 2;

        // 液态玻璃 cell：毛玻璃 + 圆角 + 微高光
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = UIColor.clearColor;

        UIVisualEffectView *cellBlur = [[UIVisualEffectView alloc] initWithEffect:DYYYLiquidBlurEffect()];
        cellBlur.layer.cornerRadius = 14.0;
        cellBlur.layer.masksToBounds = YES;
        cellBlur.layer.borderWidth = 0.5;
        cellBlur.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
        cell.backgroundView = cellBlur;

        UIVisualEffectView *selBlur = [[UIVisualEffectView alloc] initWithEffect:DYYYLiquidBlurEffect()];
        selBlur.contentView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
        selBlur.layer.cornerRadius = 14.0;
        selBlur.layer.masksToBounds = YES;
        cell.selectedBackgroundView = selBlur;

        cell.textLabel.textColor = DYYYPrimaryTextColor();
        cell.detailTextLabel.textColor = DYYYSecondaryTextColor();
    }

    NSDictionary *item = self.items[indexPath.row];
    NSString *key = item[@"key"] ?: @"";

    cell.textLabel.text = item[@"title"] ?: key;
    cell.detailTextLabel.text = item[@"desc"] ?: @"";

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = DYYYGetBool(key);
    toggle.onTintColor = [UIColor colorWithRed:0.40 green:0.55 blue:1.0 alpha:1.0];
    objc_setAssociatedObject(toggle, @selector(dyyy_switchChanged:), key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [toggle addTarget:self action:@selector(dyyy_switchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;

    return cell;
}

- (void)dyyy_switchChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, @selector(dyyy_switchChanged:));
    if (key.length == 0) return;
    DYYYSetBool(key, sender.isOn);
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
        header.contentView.backgroundColor = UIColor.clearColor;
        header.backgroundView = [UIView new];
        header.backgroundView.backgroundColor = UIColor.clearColor;
        header.textLabel.textColor = DYYYSecondaryTextColor();
    }
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)view;
        footer.contentView.backgroundColor = UIColor.clearColor;
        footer.backgroundView = [UIView new];
        footer.backgroundView.backgroundColor = UIColor.clearColor;
        footer.textLabel.textColor = DYYYSecondaryTextColor();
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
            nav.view.backgroundColor = UIColor.clearColor;
            nav.modalPresentationCapturesStatusBarAppearance = YES;

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

// ========== 身份声明 ==========
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
    if (DYYYGetBool(@"DYYYHideFeedTabJumpGuide")) { %orig(YES); return; }
    %orig(hidden);
}
- (void)setAlpha:(CGFloat)alpha {
    if (DYYYGetBool(@"DYYYHideFeedTabJumpGuide")) { %orig(0.0); return; }
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
    if (DYYYGetBool(@"DYYYHideTopTabLine")) { %orig(YES); return; }
    %orig(hidden);
}
- (void)setAlpha:(CGFloat)alpha {
    if (DYYYGetBool(@"DYYYHideTopTabLine")) { %orig(0.0); return; }
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
    if (DYYYGetBool(@"DYYYDisablePullRefresh")) { %orig(NO); return; }
    %orig(arg);
}
- (void)refreshData { if (DYYYGetBool(@"DYYYDisablePullRefresh")) return; %orig; }
- (void)handlePullToRefresh { if (DYYYGetBool(@"DYYYDisablePullRefresh")) return; %orig; }
- (void)pulldownToRefresh { if (DYYYGetBool(@"DYYYDisablePullRefresh")) return; %orig; }
%end

%hook AWEFeedContainerViewController
- (BOOL)canRefresh {
    if (DYYYGetBool(@"DYYYDisablePullRefresh")) return NO;
    return %orig;
}
- (void)setCanRefresh:(BOOL)arg {
    if (DYYYGetBool(@"DYYYDisablePullRefresh")) { %orig(NO); return; }
    %orig(arg);
}
%end

// ==========================================
// 功能 4：禁用直播 PCDN
// ==========================================
%hook HTSLiveStreamPcdnManager
+ (void)start { if (DYYYGetBool(@"DYYYDisableLivePCDN")) return; %orig; }
+ (void)configAndStartLiveIO { if (DYYYGetBool(@"DYYYDisableLivePCDN")) return; %orig; }
%end

%hook IESLiveLaunchTaskPcdn
- (void)excute { if (DYYYGetBool(@"DYYYDisableLivePCDN")) return; %orig; }
%end

// ==========================================
// 功能 5：底栏"首页"改成 𝑳𝒐𝒗𝒆
// ==========================================
%hook AWENormalModeTabBarTextView
- (void)layoutSubviews {
    %orig;
    if (!DYYYGetBool(@"DYYYChangeHomeTabText")) return;
    @try {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                if ([label.text isEqualToString:@"首页"]) label.text = @"𝑳𝒐𝒗𝒆";
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
                if (statusObj && [statusObj integerValue] == 2) return NO;
            }
        } @catch (NSException *e) {}
    }
    return %orig(point, event);
}
- (BOOL)enableRefresh {
    if (DYYYGetBool(@"DYYYDisableHomeRefresh")) {
        @try {
            NSString *label = self.accessibilityLabel ?: @"";
            if ([label containsString:@"首页"] || [label containsString:@"𝑳𝒐𝒗𝒆"]) return NO;
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
    if (DYYYGetBool(@"DYYYHideInteractionSearch")) { [self removeFromSuperview]; return; }
    %orig;
}
%end

// ==========================================
// 功能 8：隐藏弹出热搜 / 热点框
// ==========================================
%hook AWEHotSearchInnerBottomView
- (void)layoutSubviews {
    if (DYYYGetBool(@"DYYYHideHotSearch")) { [self removeFromSuperview]; return; }
    %orig;
}
%end

%hook AWEHotSpotListModel
- (BOOL)disableDisplay { if (DYYYGetBool(@"DYYYHideHotspot")) return YES; return %orig; }
- (BOOL)disableDisplayInner { if (DYYYGetBool(@"DYYYHideHotspot")) return YES; return %orig; }
- (NSString *)hotSpotTipTitleHeader { if (DYYYGetBool(@"DYYYHideHotspot")) return @""; return %orig; }
- (NSString *)hotSpotTipTitle { if (DYYYGetBool(@"DYYYHideHotspot")) return @""; return %orig; }
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
        if (subview != self) [subview removeFromSuperview];
    }
}
%end

// ==========================================
// 功能 10 & 12：隐藏汽水音乐入口 / 跳过相关视频
// ==========================================
%hook AWEAwemeModel
- (instancetype)initWithDictionary:(id)dict error:(NSError **)error {
    id orig = %orig;
    if (orig && DYYYGetBool(@"DYYYSkipQishuiMusicVideo") && [orig contentFilter]) return nil;
    return orig;
}

%new
- (BOOL)contentFilter {
    BOOL skipMusic = DYYYGetBool(@"DYYYSkipQishuiMusicVideo");
    id realAnchor = nil;
    Ivar anchorIvar = class_getInstanceVariable([self class], "_relatedMusicAnchor");
    if (anchorIvar) realAnchor = object_getIvar(self, anchorIvar);
    return skipMusic && realAnchor != nil;
}

- (id)relatedMusicAnchor {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) return nil;
    return %orig;
}
- (void)setRelatedMusicAnchor:(id)anchor {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) { %orig(nil); return; }
    %orig;
}
%end

%hook AWERelatedMusicAnchorModel
- (instancetype)init {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) return nil;
    return %orig;
}
- (instancetype)initWithDictionary:(id)dict error:(NSError **)error {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) return nil;
    return %orig;
}
%end

%hook AWEMusicExtraModel
- (id)commentTopBarInfo {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) return nil;
    return %orig;
}
- (void)setCommentTopBarInfo:(id)info {
    if (DYYYGetBool(@"DYYYHideQishuiMusicAnchor")) { %orig(nil); return; }
    %orig;
}
%end

// ==========================================
// 功能 11：屏蔽版本更新
// ==========================================
%hook AWEVersionUpdateManager

- (void)startVersionUpdateWorkflow:(id)arg1 completion:(id)arg2 {
    if (DYYYGetBool(@"DYYYNoUpdates")) {
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

// ==========================================
// 全局：给可见 VC 装上双指长按手势打开设置
// ==========================================
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    @try {
        NSString *className = NSStringFromClass([self class]);
        if ([className containsString:@"DYYYSettingsViewController"]) return;
        DYYYAttachSettingsGestureToView(self.view);
    } @catch (NSException *e) {}
}
%end
