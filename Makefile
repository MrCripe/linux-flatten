.PHONY: build clean help

help:
	@echo "Available targets:"
	@echo "  build  - Build the kernel package (makepkg)"
	@echo "  clean  - Clean build artifacts"
	@echo "  help   - Show this help"

build:
	makepkg -sf

clean:
	rm -rf pkg/ src/ linux-flatten-*.pkg.tar.zst *.log
