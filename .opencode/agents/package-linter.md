# Package Linter Agent

## Purpose
Automated package quality assurance for Arch Linux PKGBUILD and install scripts.

## Capabilities

### PKGBUILD Validation
- Syntax checking with `bash -n PKGBUILD`
- `namcap` linting (if available)
- Verify mandatory fields: `pkgname`, `pkgver`, `pkgrel`, `arch`, `license`
- Check for `source=()` and `sha256sums=()`
- Validate `depends` and `makedepends` are not empty
- Check `install=` references an existing file
- Verify `validpgpkeys` for git sources

### Install Script Validation
- Syntax check with `bash -n`
- `shellcheck` audit (SC2086, SC2181, etc.)
- Verify required functions: `post_install`, `post_upgrade`, `pre_remove`, `post_remove`
- Check for dangerous patterns:
  - `sudo` inside scripts
  - `/tmp/` without `mktemp`
  - Hardcoded absolute paths
  - Modifying system files without backup
- Validate `.install` format (bash functions)

### Package Structure
- Check for non-standard file locations
- Verify `.BUILDINFO` and `.PKGINFO` exist
- Validate module compression (zst vs xz)
- Check `provides`/`conflicts` consistency

## Usage
```bash
# Lint PKGBUILD
bash -n PKGBUILD
namcap PKGBUILD

# Lint install script
bash -n linux-flatten.install
shellcheck linux-flatten.install
```

## Common Issues & Fixes
- Empty `source=()` → add required files (e.g., `config.gz`)
- `SKIP` sha256sums → pin to commit hash and use `validpgpkeys`
- Missing `optdepends` → document optional dependencies
- Hardcoded paths → use `$pkgdir`, `$srcdir` in PKGBUILD
