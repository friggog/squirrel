include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Squirrel
Squirrel_FILES = Tweak.xm
Squirrel_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
