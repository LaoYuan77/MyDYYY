// DYYY (精简版)
// 与原版 DYYY 屏蔽弹窗逻辑一致，保留所有功能

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - 设置读写

static inline BOOL DYYYGetBool(NSString *key) {
    NSNumber *v = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return v ? [v boolValue] : YES;   // 默认全部开启
}

static inline void DYYYSetBool(NSString *key, BOOL value) {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - 设置项配置

static NSArray<NSDictionary *> *DYYYSettingItems(void) {
    return @[
        @{@"key": @"DYYYHideFeedTabJumpGuide",     @"title": @"隐藏首页跳转引导"},
        @{@"key": @"DYYYHideTopTabLine",           @"title": @"隐藏顶栏分割线"},
        @{@"key": @"DYYYDisablePullRefresh",       @"title": @"禁用下拉刷新"},
        @{@"key": @"DYYYDisableLivePCDN",          @"title": @"禁用直播 PCDN"},
        @{@"key": @"DYYYChangeHomeTabText",        @"title": @"首页标签改为 𝑳𝒐𝒗𝒆"},
        @{@"key": @"DYYYDisableHomeRefresh",       @"title": @"禁用首页二次点击刷新"},
        @{@"key": @"DYYYHideCommentViews",         @"title": @"隐藏评论搜索浮层"},
        @{@"key": @"DYYYHideInteractionSearch",    @"title": @"隐藏播放页搜索锚点"},
        @{@"key": @"DYYYHideHotSearch",            @"title": @"隐藏热搜底部"},
        @{@"key": @"DYYYHideHotspot",              @"title": @"隐藏热点"},
        @{@"key": @"DYYYHideMessageTabRedPacket",  @"title": @"隐藏消息红包入口"},
        @{@"key": @"DYYYHideQishuiMusicAnchor",    @"title": @"隐藏汽水音乐锚点"},
        @{@"key": @"DYYYSkipQishuiMusicVideo",     @"title": @"跳过汽水音乐视频"},
        @{@"key": @"DYYYNoUpdates",                @"title": @"屏蔽更新提示"},
    ];
}

#pragma mark - 设置界面

@interface DYYYSettingsViewController : UITableViewController
@end

@implementation DYYYSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DYYY 设置";
    self.tableView.tableFooterView = [UIView new];
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                              target:self
                                                                              action:@selector(closeTapped)];
    self.navigationItem.rightBarButtonItem = closeBtn;
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return DYYYSettingItems().count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *ID = @"DYYYCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ID];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ID];

    NSDictionary *item = DYYYSettingItems()[indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UISwitch *sw = [UISwitch new];
    sw.on = DYYYGetBool(item[@"key"]);
    objc_setAssociatedObject(sw, "DYYYKey", item[@"key"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    return cell;
}

- (void)switchChanged:(UISwitch *)sw {
    NSString *key = objc_getAssociatedObject(sw, "DYYYKey");
    if (key) DYYYSetBool(key, sw.isOn);
}

@end

#pragma mark - 双指长按手势

@interface DYYYGestureHandler : NSObject
+ (instancetype)shared;
- (void)handle:(UILongPressGestureRecognizer *)g;
@end

@implementation DYYYGestureHandler

+ (instancetype)shared {
    static DYYYGestureHandler *s; static dispatch_once_t o;
    dispatch_once(&o, ^{ s = [DYYYGestureHandler new]; });
    return s;
}

- (void)handle:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    UIWindow *win = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:UIWindowScene.class]) {
            win = ((UIWindowScene *)s).windows.firstObject;
            if (win) break;
        }
    }
    if (!win) return;
    DYYYSettingsViewController *vc = [DYYYSettingsViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [win.rootViewController presentViewController:nav animated:YES completion:nil];
}

@end

static void DYYYAttachSettingsGestureToView(UIView *view) {
    if (!view || objc_getAssociatedObject(view, "DYYYGesture")) return;
    UILongPressGestureRecognizer *g =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[DYYYGestureHandler shared]
                                                      action:@selector(handle:)];
    g.numberOfTouchesRequired = 2;
    g.minimumPressDuration = 0.6;
    [view addGestureRecognizer:g];
    objc_setAssociatedObject(view, "DYYYGesture", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 1. 屏蔽更新提示（与原版一致）

%hook AWEVersionUpdateManager
- (void)startVersionUpdateWorkflow:(id)arg1 completion:(id)arg2 {
    if (DYYYGetBool(@"DYYYNoUpdates")) {
        if (arg2) { void (^cb)(void) = arg2; cb(); }
    } else { %orig; }
}
- (id)workflow  { return DYYYGetBool(@"DYYYNoUpdates") ? nil : %orig; }
- (id)badgeModule { return DYYYGetBool(@"DYYYNoUpdates") ? nil : %orig; }
%end

#pragma mark - 2. 隐藏首页跳转引导

%hook AWEFeedTabJumpGuideView
- (void)setHidden:(BOOL)h { %orig(DYYYGetBool(@"DYYYHideFeedTabJumpGuide") ? YES : h); }
- (void)didMoveToSuperview {
    %orig;
    if (DYYYGetBool(@"DYYYHideFeedTabJumpGuide")) [self removeFromSuperview];
}
%end

#pragma mark - 3. 隐藏顶栏分割线

%hook AWEFeedMultiTabSelectedContainerView
- (void)layoutSubviews {
    %orig;
    if (!DYYYGetBool(@"DYYYHideTopTabLine")) return;
    for (UIView *v in self.subviews) {
        if (CGRectGetHeight(v.frame) < 2.0) v.hidden = YES;
    }
}
%end

#pragma mark - 4. 禁用下拉刷新

%hook AWEFeedTableViewController
- (BOOL)enablePullDownRefresh { return DYYYGetBool(@"DYYYDisablePullRefresh") ? NO : %orig; }
%end

%hook AWEFeedContainerViewController
- (BOOL)enablePullDownRefresh { return DYYYGetBool(@"DYYYDisablePullRefresh") ? NO : %orig; }
%end

#pragma mark - 5. 禁用直播 PCDN

%hook HTSLiveStreamPcdnManager
- (void)startPcdn { if (!DYYYGetBool(@"DYYYDisableLivePCDN")) %orig; }
- (BOOL)isPcdnEnabled { return DYYYGetBool(@"DYYYDisableLivePCDN") ? NO : %orig; }
%end

%hook IESLiveLaunchTaskPcdn
- (void)run { if (!DYYYGetBool(@"DYYYDisableLivePCDN")) %orig; }
%end

#pragma mark - 6. 首页标签文字 → 𝑳𝒐𝒗𝒆

%hook AWENormalModeTabBarTextView
- (void)setText:(NSString *)text {
    if (DYYYGetBool(@"DYYYChangeHomeTabText") && [text isEqualToString:@"首页"]) {
        %orig(@"𝑳𝒐𝒗𝒆");
    } else { %orig; }
}
%end

#pragma mark - 7. 禁用首页二次点击刷新

%hook AWENormalModeTabBarGeneralButton
- (void)onClick {
    if (DYYYGetBool(@"DYYYDisableHomeRefresh")) {
        Ivar iv = class_getInstanceVariable([self class], "_status");
        if (iv) {
            id status = object_getIvar(self, iv);
            if ([status respondsToSelector:@selector(isSelected)] && [status performSelector:@selector(isSelected)]) {
                return;     // 已选中再点 → 拦截刷新
            }
        }
    }
    %orig;
}
%end

#pragma mark - 8. 隐藏评论搜索浮层

%hook AWESearchAnchorListModel
- (BOOL)isHidden { return DYYYGetBool(@"DYYYHideCommentViews") ? YES : %orig; }
%end

#pragma mark - 9. 隐藏播放页搜索锚点

%hook AWEPlayInteractionSearchAnchorView
- (void)setHidden:(BOOL)h { %orig(DYYYGetBool(@"DYYYHideInteractionSearch") ? YES : h); }
- (void)didMoveToSuperview {
    %orig;
    if (DYYYGetBool(@"DYYYHideInteractionSearch")) [self removeFromSuperview];
}
%end

#pragma mark - 10. 隐藏热搜底部

%hook AWEHotSearchInnerBottomView
- (void)setHidden:(BOOL)h { %orig(DYYYGetBool(@"DYYYHideHotSearch") ? YES : h); }
- (void)didMoveToSuperview {
    %orig;
    if (DYYYGetBool(@"DYYYHideHotSearch")) [self removeFromSuperview];
}
%end

#pragma mark - 11. 隐藏热点

%hook AWEHotSpotListModel
- (BOOL)isHidden { return DYYYGetBool(@"DYYYHideHotspot") ? YES : %orig; }
%end

#pragma mark - 12. 隐藏消息红包入口

%hook AWEIMMessageTabSideBarView
- (void)setHidden:(BOOL)h { %orig(DYYYGetBool(@"DYYYHideMessageTabRedPacket") ? YES : h); }
- (void)didMoveToSuperview {
    %orig;
    if (DYYYGetBool(@"DYYYHideMessageTabRedPacket")) [self removeFromSuperview];
}
%end

#pragma mark - 13. 隐藏汽水音乐锚点

%hook AWERelatedMusicAnchorModel
- (BOOL)isHidden { return DYYYGetBool(@"DYYYHideQishuiMusicAnchor") ? YES : %orig; }
%end

%hook AWEMusicExtraModel
- (id)anchorInfo { return DYYYGetBool(@"DYYYHideQishuiMusicAnchor") ? nil : %orig; }
%end

#pragma mark - 14. 跳过汽水音乐视频

%hook AWEAwemeModel
- (BOOL)isQishuiMusicVideo {
    BOOL r = %orig;
    if (r && DYYYGetBool(@"DYYYSkipQishuiMusicVideo")) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *win = UIApplication.sharedApplication.windows.firstObject;
            UIView *root = win.rootViewController.view;
            UISwipeGestureRecognizer *swipe =
                [[UISwipeGestureRecognizer alloc] initWithTarget:nil action:nil];
            swipe.direction = UISwipeGestureRecognizerDirectionUp;
            [root.gestureRecognizers enumerateObjectsUsingBlock:^(UIGestureRecognizer *g, NSUInteger i, BOOL *s) {
                if ([g isKindOfClass:UISwipeGestureRecognizer.class]) [g.view sendActionsForControlEvents:UIControlEventTouchUpInside];
            }];
        });
    }
    return r;
}
%end

#pragma mark - 入口手势挂载

%hook AWENormalModeTabBar
- (void)didMoveToWindow {
    %orig;
    DYYYAttachSettingsGestureToView(self);
}
%end
