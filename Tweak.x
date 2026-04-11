#import <UIKit/UIKit.h>

// ========== 身份声明 ==========
@interface AWEFeedTabJumpGuideView : UIView
@end

@interface AWEFeedMultiTabSelectedContainerView : UIView
@end

@interface AWEFeedTableView : UIScrollView
@end

@interface AWEListKitMagicCollectionView : UIScrollView
@end
// ==============================

// 功能 1：隐藏双列箭头（保持成功逻辑）
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

// 功能 2：隐藏顶栏横线（保持成功逻辑）
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
// 功能 3：终极防御 - 彻底禁用顶部下拉刷新
// 原理：拦截底层的 bounds 和 offset 变化，彻底封死向下拉动的物理空间。
// 同时覆盖 TableView 和新版抖音特有的 MagicCollectionView。
// ==========================================

%hook AWEFeedTableView
- (void)setBounds:(CGRect)bounds {
    // 禁止 bounds.origin.y 小于 0（即禁止画面被向下拉出边界）
    if (bounds.origin.y < 0) {
        bounds.origin.y = 0;
    }
    %orig(bounds);
}
- (void)setContentOffset:(CGPoint)offset {
    if (offset.y < 0) {
        offset.y = 0;
    }
    %orig(offset);
}
- (BOOL)bounces { return NO; }
- (void)setBounces:(BOOL)bounces { %orig(NO); }
%end

%hook AWEListKitMagicCollectionView
- (void)setBounds:(CGRect)bounds {
    if (bounds.origin.y < 0) {
        bounds.origin.y = 0;
    }
    %orig(bounds);
}
- (void)setContentOffset:(CGPoint)offset {
    if (offset.y < 0) {
        offset.y = 0;
    }
    %orig(offset);
}
- (BOOL)bounces { return NO; }
- (void)setBounces:(BOOL)bounces { %orig(NO); }
%end
