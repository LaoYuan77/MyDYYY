TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = Aweme

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MyDYYY
MyDYYY_FILES = Tweak.x
MyDYYY_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
