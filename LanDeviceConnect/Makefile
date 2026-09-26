.PHONY: build clean run icons test

DERIVED=.derived
ARCH=$(shell uname -m)
APP=$(DERIVED)/Build/Products/Debug/LanDeviceConnect.app
XCPRETTY=$(shell command -v xcpretty 2>/dev/null)

build:
	@/bin/bash -lc 'if [ -n "$(XCPRETTY)" ]; then xcodebuild -project LanDeviceConnect.xcodeproj -scheme LanDeviceConnect -configuration Debug -destination "platform=macOS,arch=$(ARCH)" -derivedDataPath $(DERIVED) build | xcpretty; else xcodebuild -project LanDeviceConnect.xcodeproj -scheme LanDeviceConnect -configuration Debug -destination "platform=macOS,arch=$(ARCH)" -derivedDataPath $(DERIVED) build; fi'

run: build
	@open "$(APP)"

clean:
	rm -rf $(DERIVED)

icons:
	bash scripts/generate-icons.sh

test:
	bash scripts/test.sh
