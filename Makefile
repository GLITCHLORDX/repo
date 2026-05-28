TARGET := iphone:clang:latest:12.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DepthClockXI
DepthClockXI_FILES = Tweak.xm
DepthClockXI_CFLAGS = -fobjc-arc
DepthClockXI_FRAMEWORKS = UIKit Foundation QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
