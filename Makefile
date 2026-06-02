ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = MyApp
MyApp_FILES = main.m AppDelegate.m RootViewController.m
MyApp_FRAMEWORKS = UIKit Foundation CoreGraphics
MyApp_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
