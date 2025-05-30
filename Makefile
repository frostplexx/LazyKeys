BIN_NAME = lazykeys
SRC_FILES = $(wildcard src/*.swift)
LIBS = -framework Cocoa -framework Carbon -framework Foundation
VERSION ?= dev-$(shell date -Idate)
BIN_DIR = bin
OUTPUT = $(BIN_DIR)/$(BIN_NAME)

all: clean build

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

version.h: 
	echo '#ifndef VERSION_H' > version.h
	echo '#define VERSION_H' >> version.h
	echo '#define VERSION_STRING "$(VERSION)"' >> version.h
	echo '#endif /* VERSION_H */' >> version.h

build: version.h $(OUTPUT)
	@echo ✅ Build successfully

$(OUTPUT): $(SRC_FILES) | $(BIN_DIR)
	xcrun swiftc -I. -import-objc-header version.h \
		-O \
		-whole-module-optimization \
		-Xcc -flto \
		-Xlinker -dead_strip \
		$(LIBS) \
		$(SRC_FILES) \
		-o $(OUTPUT)

# Clean build artifacts
clean:
	rm -rf $(BIN_DIR) version.h

# Install the binary (optional)
install: build
	cp $(OUTPUT) /usr/local/bin/$(BIN_NAME)
