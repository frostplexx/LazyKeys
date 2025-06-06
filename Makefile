# Metadata
BIN_NAME = lazykeys
VERSION ?= dev-$(shell date -Idate)

# Paths
SRC_DIR = src
SRC_FILES = $(wildcard $(SRC_DIR)/*.swift)
BIN_DIR = bin
OUTPUT = $(BIN_DIR)/$(BIN_NAME)
APP_NAME = $(BIN_NAME).app
APP_DIR = $(BIN_DIR)/$(APP_NAME)
WRAPPER = $(APP_DIR)/Contents/MacOS/$(BIN_NAME)

# Libraries
LIBS = -framework Cocoa -framework Carbon -framework Foundation

# Default target
all: release

# Create output dir
$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Version header
version.h:
	@echo '#ifndef VERSION_H' > version.h
	@echo '#define VERSION_H' >> version.h
	@echo '#define VERSION_STRING "$(VERSION)"' >> version.h
	@echo '#endif /* VERSION_H */' >> version.h

# Build (debug)
build: SWIFT_FLAGS = -DDEBUG
build: version.h $(OUTPUT)

$(OUTPUT): $(SRC_FILES) | $(BIN_DIR)
	xcrun swiftc -I. -import-objc-header version.h \
		-O \
		-whole-module-optimization \
		-Xcc -flto \
		-Xlinker -dead_strip \
		$(SWIFT_FLAGS) \
		$(LIBS) \
		$(SRC_FILES) \
		-o $(OUTPUT)
	@echo ✅ Build successful: $(OUTPUT)

# Release build
release: SWIFT_FLAGS =
release: clean version.h $(OUTPUT)
	@echo 🚀 Release build complete

# Wrap binary into .app bundle
wrap: build
	@mkdir -p "$(APP_DIR)/Contents/MacOS"
	@cp "$(OUTPUT)" "$(WRAPPER)"
	@mkdir -p "$(APP_DIR)/Contents"
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > "$(APP_DIR)/Contents/Info.plist"
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> "$(APP_DIR)/Contents/Info.plist"
	@echo '<plist version="1.0">' >> "$(APP_DIR)/Contents/Info.plist"
	@echo '<dict>' >> "$(APP_DIR)/Contents/Info.plist"
	@echo '  <key>CFBundleName</key><string>LazyKeys</string>' >> "$(APP_DIR)/Contents/Info.plist"
	@echo '  <key>CFBundleIdentifier</key><string>com.example.lazykeys</string>' >> "$(APP_DIR)/Contents/Info.plist"
	@echo '  <key>CFBundleVersion</key><string>$(VERSION)</string>' >> "$(APP_DIR)/Contents/Info.plist"
	@echo '  <key>CFBundleExecutable</key><string>$(BIN_NAME)</string>' >> "$(APP_DIR)/Contents/Info.plist"
	@echo '  <key>LSUIElement</key><true/>' >> "$(APP_DIR)/Contents/Info.plist"
	@echo '</dict>' >> "$(APP_DIR)/Contents/Info.plist"
	@echo '</plist>' >> "$(APP_DIR)/Contents/Info.plist"
	@echo 📦 App bundle created at: $(APP_DIR)

# Run the .app bundle in debug mode
run: clean wrap
	open "$(APP_DIR)"
	log stream --predicate 'subsystem == "com.frostplexx.lazykeys"'

# Clean all build artifacts
clean:
	@echo "🗑️ Cleaning up build files"
	@rm -rf $(BIN_DIR) version.h

# Install binary to /usr/local/bin
install: release
	cp "$(OUTPUT)" /usr/local/bin/$(BIN_NAME)
	@echo 🛠️ Installed to /usr/local/bin/$(BIN_NAME)
