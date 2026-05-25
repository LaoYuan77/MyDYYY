#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 替代方法：直接返回 NO
BOOL return_no(id self, SEL _cmd) {
    return NO;
}

// 替代方法：什么都不做 (用于拦截无参数动作)
void do_nothing_void(id self, SEL _cmd) {
    return;
}

// 替代方法：什么都不做 (用于拦截带参数动作)
void do_nothing_void_bool(id self, SEL _cmd, BOOL arg) {
    return;
}

// 安全替换方法的工具函数
void hook_method(Class cls, SEL sel, IMP newImp) {
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        method_setImplementation(m, newImp);
    }
}

// 当你的 dylib 被注入到抖音加载时，自动执行拦截逻辑
__attribute__((constructor)) static void setup_hooks() {
    // 拦截 AWEFeedTableViewController
    Class cls1 = NSClassFromString(@"AWEFeedTableViewController");
    if (cls1) {
        hook_method(cls1, NSSelectorFromString(@"canRefresh"), (IMP)return_no);
        hook_method(cls1, NSSelectorFromString(@"setCanRefresh:"), (IMP)do_nothing_void_bool);
        hook_method(cls1, NSSelectorFromString(@"refreshData"), (IMP)do_nothing_void);
        hook_method(cls1, NSSelectorFromString(@"handlePullToRefresh"), (IMP)do_nothing_void);
        hook_method(cls1, NSSelectorFromString(@"pulldownToRefresh"), (IMP)do_nothing_void);
    }

    // 拦截 AWEFeedContainerViewController
    Class cls2 = NSClassFromString(@"AWEFeedContainerViewController");
    if (cls2) {
        hook_method(cls2, NSSelectorFromString(@"canRefresh"), (IMP)return_no);
        hook_method(cls2, NSSelectorFromString(@"setCanRefresh:"), (IMP)do_nothing_void_bool);
    }
}
