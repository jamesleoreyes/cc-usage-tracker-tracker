APP_NAME = CCUsageTrackerTracker
BUNDLE_ID = com.jamesleoreyes.cc-usage-tracker-tracker

# Stamped into the built bundle (CFBundleShortVersionString AND CFBundleVersion —
# Sparkle compares the latter). The release workflow passes the tag's version;
# local dev builds are fine as 0.0.0.
VERSION ?= 0.0.0

# "-" = ad-hoc signing (local dev). The release workflow passes the real thing:
#   make dmg SIGN_IDENTITY="Developer ID Application: James Reyes (TEAMID)"
# Hardened runtime always (notarization requires it; harmless ad-hoc).
# --timestamp only with a real identity — ad-hoc signatures can't be timestamped.
SIGN_IDENTITY ?= -
ifeq ($(SIGN_IDENTITY),-)
SIGN_FLAGS = -o runtime
else
SIGN_FLAGS = -o runtime --timestamp
endif

BUILD_DIR = .build/release
APP_BUNDLE = build/$(APP_NAME).app
DMG_NAME = $(APP_NAME)-$(VERSION).dmg
DMG_DIR = build/dmg

BINARY = $(BUILD_DIR)/$(APP_NAME)
RESOURCE_BUNDLE = $(BUILD_DIR)/$(APP_NAME)_$(APP_NAME).bundle
FRAMEWORKS_DIR = $(APP_BUNDLE)/Contents/Frameworks
SPARKLE_B = $(FRAMEWORKS_DIR)/Sparkle.framework/Versions/B

.PHONY: all build app dmg clean run

all: dmg

# --- Build the Swift binary ---
build:
	swift build -c release

# --- Assemble the .app bundle ---
app: build
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@mkdir -p $(FRAMEWORKS_DIR)

	# Binary
	cp $(BINARY) $(APP_BUNDLE)/Contents/MacOS/

	# Info.plist
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/

	# SPM resource bundle — inside Contents/Resources/ for valid bundle structure
	cp -R $(RESOURCE_BUNDLE) $(APP_BUNDLE)/Contents/Resources/

	# Sparkle.framework — SwiftPM copies it next to the binary; fall back to
	# digging it out of .build/artifacts if that layout ever changes.
	@if [ -d "$(BUILD_DIR)/Sparkle.framework" ]; then \
		cp -R "$(BUILD_DIR)/Sparkle.framework" "$(FRAMEWORKS_DIR)/"; \
	else \
		SRC=$$(find .build/artifacts -type d -name "Sparkle.framework" | head -1); \
		[ -n "$$SRC" ] || { echo "error: Sparkle.framework not found under .build — run swift build first"; exit 1; }; \
		cp -R "$$SRC" "$(FRAMEWORKS_DIR)/"; \
	fi

	# PkgInfo
	printf 'APPL????' > $(APP_BUNDLE)/Contents/PkgInfo

	# Version stamping — the bundle, not the repo file, carries the release version
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" $(APP_BUNDLE)/Contents/Info.plist
	plutil -replace CFBundleVersion -string "$(VERSION)" $(APP_BUNDLE)/Contents/Info.plist

	# Sign inside-out, per Sparkle's non-Xcode docs. Never --deep.
	codesign -f -s "$(SIGN_IDENTITY)" $(SIGN_FLAGS) "$(SPARKLE_B)/XPCServices/Installer.xpc"
	codesign -f -s "$(SIGN_IDENTITY)" $(SIGN_FLAGS) --preserve-metadata=entitlements "$(SPARKLE_B)/XPCServices/Downloader.xpc"
	codesign -f -s "$(SIGN_IDENTITY)" $(SIGN_FLAGS) "$(SPARKLE_B)/Autoupdate"
	codesign -f -s "$(SIGN_IDENTITY)" $(SIGN_FLAGS) "$(SPARKLE_B)/Updater.app"
	codesign -f -s "$(SIGN_IDENTITY)" $(SIGN_FLAGS) "$(FRAMEWORKS_DIR)/Sparkle.framework"
	codesign -f -s "$(SIGN_IDENTITY)" $(SIGN_FLAGS) "$(APP_BUNDLE)"

	@echo "Built $(APP_BUNDLE) (version $(VERSION), identity: $(SIGN_IDENTITY))"

# --- Package into a .dmg ---
dmg: app
	@rm -rf $(DMG_DIR) build/$(DMG_NAME)
	@mkdir -p $(DMG_DIR)

	cp -R $(APP_BUNDLE) $(DMG_DIR)/
	ln -s /Applications $(DMG_DIR)/Applications

	hdiutil create -volname "CC Usage Tracker Tracker" \
		-srcfolder $(DMG_DIR) \
		-ov -format UDZO \
		build/$(DMG_NAME)

	@if [ "$(SIGN_IDENTITY)" != "-" ]; then \
		codesign -f -s "$(SIGN_IDENTITY)" --timestamp build/$(DMG_NAME); \
	fi

	@rm -rf $(DMG_DIR)
	@echo "Created build/$(DMG_NAME)"

# --- Dev: build and run the .app directly ---
run: app
	open $(APP_BUNDLE)

# --- Clean ---
clean:
	swift package clean
	rm -rf build
