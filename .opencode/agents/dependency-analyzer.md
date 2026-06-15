# Dependency Analyzer Agent

## Purpose
Analyze package dependencies for conflicts, missing requirements, and optimization opportunities.

## Capabilities

### Dependency Metadata Analysis
- Parse PKGBUILD `depends=()`, `makedepends=()`, `optdepends=()`, `checkdepends=()`
- Verify runtime dependencies are actually used in the package
- Identify missing dependencies by scanning install scripts and post-install hooks
- Detect circular dependencies

### Conflict Detection
- Check `conflicts=()` against other installed packages
- Detect kernel module namespace conflicts
- Check for duplicate provides across packages

### Optimization Opportunities
- Identify dependencies that could be optional (`optdepends`)
- Detect unnecessary transitive dependencies
- Suggest minimal dependency sets for different use cases

### Package Format Compatibility
- Verify `.INSTALL` script dependencies exist at runtime
- Check `mkinitcpio` preset compatibility
- Validate bootloader integration dependencies (e.g., `limine`)

## Dependency Graph
```
linux-flatten
├── mkinitcpio        → initramfs generation
├── coreutils         → basic system tools
├── linux-firmware    → hardware firmware blobs
├── kmod              → kernel module loading
├── limine (optional) → bootloader entry
└── gcc (make)        → build dependency
```

## Common Issues & Fixes
- Missing `linux-firmware` → add to `depends`
- Missing `kmod` → add (needed for module loading)
- Forgotten `optdepends` for bootloader integration
