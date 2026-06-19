.PHONY: build clean help

help:
	@echo "Available targets:"
	@echo "  build  - Build the package (via linux-flatten.sh)"
	@echo "  clean  - Clean build artifacts"
	@echo "  help   - Show this help"

build:
	./linux-flatten.sh build

clean:
	rm -rf pkg/ src/ linux-flatten-*.pkg.tar.zst linux-flatten-*.tar.gz *.log
