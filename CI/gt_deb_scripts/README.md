# GT Debian Package Builder

This directory contains the infrastructure to build Debian packages for [gt (USB Gadget Tool)](https://github.com/linux-usb-gadgets/gt) using debhelper.

## Overview

The build system:
1. Builds gt using cmake
2. Creates a `.deb` package with debhelper
3. Generates source package files (`.orig.tar.gz`, `.debian.tar.xz`, `.dsc`)

## Prerequisites

```bash
sudo apt-get install debhelper devscripts build-essential wget cmake libusbgx-dev libconfig-dev libglib2.0-dev gettext-base
```

Download/checkout the `gt_deb_scripts` directory.

## Usage

### Building the Package

```bash
./build-gt-deb.sh [package_name] [version] [architecture]
```

Parameters:
- `package_name`: Name of the package (default: `gt`)
- `version`: Package version (default: `1.0.0`)
   - Follow semantic versioning (e.g., `1.0.0`, `2.1.3`)
- `architecture`: Target architecture (default: `any` for host arch)
  - Common values: `amd64` (64-bit), `i386` (32-bit x86), `arm64` (64-bit ARM), `armhf` (32-bit ARM)

Note: Always builds from the master branch.

### Examples

```bash
# Build with default version for host architecture
./build-gt-deb.sh

# Build version 1.0.0 for 64-bit
./build-gt-deb.sh gt 1.0.0 amd64 

# Build version 1.0.0 for 32-bit x86
./build-gt-deb.sh gt 1.0.0 i386 

# Build version 2.0.0  for 64-bit ARM
./build-gt-deb.sh gt 2.0.0 arm64

# Build version 1.0.0 for 32-bit ARM
./build-gt-deb.sh gt 1.0.0 armhf
```

## Output Files

The build process generates:
- `gt_<version>.orig.tar.gz` - Upstream source tarball
- `gt_<version>-1.debian.tar.xz` - Debian packaging files
- `gt_<version>-1.dsc` - Debian source package descriptor
- `gt_<version>-1_amd64.deb` - Binary package
- `gt_<version>-1_amd64.buildinfo` - Build information
- `gt_<version>-1_amd64.changes` - Changes file for upload

## Package Contents

The package installs:
- `/usr/bin/gt` - The gt command-line tool
- `/etc/gt/gt.conf` - Default configuration file
- `/usr/share/bash-completion/completions/gt` - Bash completion script

## Dependencies

The gt package runtime dependencies are automatically resolved via `${shlibs:Depends}` during the build process. Key libraries include:
- `libusbgx` - USB gadget configuration library
- `libconfig` - Configuration file library
- `libglib2.0` - GLib library

## Usage with adi-scripts

The `adi-scripts` package should depend on this `gt` package to ensure the USB gadget functionality works properly.

Add to adi-scripts debian/control:
```
Depends: gt (>= 1.0.0), ...
```
