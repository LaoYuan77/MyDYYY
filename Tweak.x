#import <UIKit/UIKit.h>

// ========== 身份声明 ==========
@interface AWEFeedTabJumpGuideView : UIView
@end

@interface AWEFeedMultiTabSelectedContainerView : UIView
@end
// ==============================

// 功能 1：隐藏双列箭头（已成功）
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

// 功能 2：隐藏顶栏横线（已成功）
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
// 功能 3：究极防下拉刷新 4.0 - 祖宗类物理锁死
// 原理：直接在所有滚动视图的“老祖宗” UIScrollView 里下毒。
// 只要你叫“推荐流”，你的 Y 坐标就绝对不可能变成负数！
// ==========================================

%hook UIScrollView
- (void)setContentOffset:(CGPoint)offset {
    // 探测当前滑动列表的代理，如果是抖音的视频流，直接拦截
    id delegate = self.delegate;
    if (delegate) {
        NSString *delegateName = NSStringFromClass([delegate class]);
        // 覆盖老版Feed、新版AwemeDetail、以及底层ListKit
        if ([delegateName containsString:@"Feed"] || 
            [delegateName containsString:@"AwemeDetail"] || 
            [delegateName containsString:@"ListKit"]) {
            
            // 只要试图向下拉（Y变负数），立刻强制按死在0
            if (offset.y < 0) {
                offset.y = 0; 
                self.bounces = NO; // 顺手关掉边缘回弹
                self.alwaysBounceVertical = NO;
            }
        }
    }
    %orig(offset);
}
%end
