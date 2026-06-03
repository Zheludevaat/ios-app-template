ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Aloud
Aloud_FILES = main.m AppDelegate.m RootViewController.m
Aloud_FRAMEWORKS = UIKit Foundation CoreGraphics WebKit AVFoundation
Aloud_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
