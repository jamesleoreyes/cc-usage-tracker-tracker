APP_NAME = CCUsageTrackerTracker
BUNDLE_ID = com.jamesleoreyes.cc-usage-tracker-tracker
VERSION = 1.0.0

BUILD_DIR = .build/release
APP_BUNDLE = build/$(APP_NAME).app
DMG_NAME = $(APP_NAME)-$(VERSION).dmg
DMG_DIR = build/dmg

BINARY = $(BUILD_DIR)/$(APP_NAME)
RESOURCE_BUNDLE = $(BUILD_DIR)/$(APP_NAME)_$(APP_NAME).bundle

.PHONY: all build app dmg clean run release bump

all: dmg

# --- Build the Swift binary ---
build:
	swift build -c release

# --- Assemble the .app bundle ---
app: build
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources

	# Binary
	cp $(BINARY) $(APP_BUNDLE)/Contents/MacOS/

	# Info.plist
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/

	# SPM resource bundle — accessor looks at Bundle.main.bundleURL root
	cp -R $(RESOURCE_BUNDLE) $(APP_BUNDLE)/

	# PkgInfo
	echo -n "APPL????" > $(APP_BUNDLE)/Contents/PkgInfo

	@echo "Built $(APP_BUNDLE)"

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

	@rm -rf $(DMG_DIR)
	@echo "Created build/$(DMG_NAME)"

# --- Dev: build and run the .app directly ---
run: app
	open $(APP_BUNDLE)

# --- Bump version, build DMG, and create GitHub release ---
# Usage: make release V=1.2.0
release:
ifndef V
	$(error Usage: make release V=1.2.0)
endif
	@echo "Bumping version to $(V)..."
	sed -i '' 's/^VERSION = .*/VERSION = $(V)/' Makefile
	plutil -replace CFBundleShortVersionString -string "$(V)" Resources/Info.plist
	$(MAKE) dmg VERSION=$(V)
	git add Makefile Resources/Info.plist
	git commit -m "Bump version to $(V)"
	gh release create v$(V) build/$(APP_NAME)-$(V).dmg \
		--title "v$(V)" \
		--generate-notes
	@echo "Released v$(V)"

# --- Clean ---
clean:
	swift package clean
	rm -rf build
