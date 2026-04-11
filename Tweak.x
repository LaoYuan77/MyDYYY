#import <UIKit/UIKit.h>

// ========== 身份声明 ==========
@interface AWEFeedTabJumpGuideView : UIView
@end

@interface AWEFeedMultiTabSelectedContainerView : UIView
@end
// ==============================

// 功能 1：隐藏双列箭头（已成功，保持原样）
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

// 功能 2：隐藏顶栏横线（已成功，保持原样）
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
// 功能 3：终极杀手锏 - 降维打击禁用下拉刷新
// 原理：直接拦截 iOS 系统底层的 UITableView 和 UICollectionView。
// 只要发现是“视频流（Feed）”在试图向下拉（y < 0），直接按死归零并强行关闭回弹！
// ==========================================

%hook UITableView
- (void)setContentOffset:(CGPoint)offset {
    if (offset.y < 0) {
        id delegate = self.delegate;
        if (delegate) {
            NSString *className = NSStringFromClass([delegate class]);
            if ([className containsString:@"Feed"] && [className containsString:@"Controller"]) {
                offset.y = 0;
                self.bounces = NO; // 彻底关闭回弹
            }
        }
    }
    %orig(offset);
}

- (void)setBounds:(CGRect)bounds {
    if (bounds.origin.y < 0) {
        id delegate = self.delegate;
        if (delegate) {
            NSString *className = NSStringFromClass([delegate class]);
            if ([className containsString:@"Feed"] && [className containsString:@"Controller"]) {
                bounds.origin.y = 0;
            }
        }
    }
    %orig(bounds);
}
%end

%hook UICollectionView
- (void)setContentOffset:(CGPoint)offset {
    if (offset.y < 0) {
        id delegate = self.delegate;
        if (delegate) {
            NSString *className = NSStringFromClass([delegate class]);
            if ([className containsString:@"Feed"] && [className containsString:@"Controller"]) {
                offset.y = 0;
                self.bounces = NO; // 彻底关闭回弹
            }
        }
    }
    %orig(offset);
}

- (void)setBounds:(CGRect)bounds {
    if (bounds.origin.y < 0) {
        id delegate = self.delegate;
        if (delegate) {
            NSString *className = NSStringFromClass([delegate class]);
            if ([className containsString:@"Feed"] && [className containsString:@"Controller"]) {
                bounds.origin.y = 0;
            }
        }
    }
    %orig(bounds);
}
%end
