TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Aweme
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MyDYYY

MyDYYY_FILES = Tweak.x
MyDYYY_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
