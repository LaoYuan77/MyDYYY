TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Aweme
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MyDYYY

# 如果你还有别的代码文件，用空格隔开写在后面，例如 Tweak.x setting.m
MyDYYY_FILES = Tweak.x
MyDYYY_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
