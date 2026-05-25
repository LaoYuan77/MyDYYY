# 1. 目标平台设定
TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Aweme

# 2. 引入公共模块 (只需一次)
include $(THEOS)/makefiles/common.mk

# 3. 定义插件信息
TWEAK_NAME = MyDYYY
MyDYYY_FILES = Tweak.x
MyDYYY_CFLAGS = -fobjc-arc
MyDYYY_FRAMEWORKS = UIKit Foundation

# 4. 引入打包路径
include $(THEOS_MAKE_PATH)/tweak.mk
