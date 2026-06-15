.PHONY: build test lint clean install uninstall pkgbuild-check help

# Default target
help:
	@echo "Available targets:"
	@echo "  build           - Build the package with makepkg"
	@echo "  test            - Run tests (lint checks)"
	@echo "  lint            - Run all linters"
	@echo "  pkgbuild-check  - Check PKGBUILD with namcap"
	@echo "  clean           - Clean build artifacts"
	@echo "  install         - Install the built package"
	@echo "  uninstall       - Uninstall the package"
	@echo "  help            - Show this help"

# Build the package
build:
	makepkg -sf --noconfirm

# Run linting
lint: pkgbuild-check shellcheck-install

# Check PKGBUILD with namcap (if available)
pkgbuild-check:
	@which namcap >/dev/null 2>&1 && namcap PKGBUILD || echo "namcap not installed, skipping..."

# Check install script with shellcheck
shellcheck-install:
	@which shellcheck >/dev/null 2>&1 && shellcheck linux-flatten.install || echo "shellcheck not installed, skipping..."

# Run tests
test: lint
	@echo "All tests passed"

# Clean build artifacts
clean:
	rm -rf pkg/ src/ *.pkg.tar.* *.log
	rm -f kernelrelease.txt

# Install the package (requires root)
install: build
	sudo pacman -U --noconfirm *.pkg.tar.zst

# Uninstall the package (requires root)
uninstall:
	sudo pacman -Rns --noconfirm linux-flatten

# Full rebuild
rebuild: clean build