.PHONY: build clean run

DERIVED=.derived
APP=$(DERIVED)/Build/Products/Debug/SSHMacApp.app
XCPRETTY=$(shell command -v xcpretty 2>/dev/null)

build:
	@/bin/bash -lc 'if [ -n "$(XCPRETTY)" ]; then xcodebuild -project SSHMacApp.xcodeproj -scheme SSHMacApp -configuration Debug -destination "platform=macOS" -derivedDataPath $(DERIVED) build | xcpretty; else xcodebuild -project SSHMacApp.xcodeproj -scheme SSHMacApp -configuration Debug -destination "platform=macOS" -derivedDataPath $(DERIVED) build; fi'

run: build
	@open "$(APP)"

clean:
	rm -rf $(DERIVED)
