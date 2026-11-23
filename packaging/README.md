# ADI Scripts Debian Package Builder

This directory contains the infrastructure to build Debian packages for the [linux_image_ADI-scripts](https://github.com/analogdevicesinc/linux_image_ADI-scripts) repository using debhelper.

## Overview

The build system:
1. Builds it using `make`
2. Creates a `.deb` package with debhelper
3. Generates source package files (`.orig.tar.gz`, `.debian.tar.xz`, `.dsc`)

## Prerequisites

```bash
sudo apt-get install debhelper devscripts build-essential wget gettext
git clone https://github.com/analogdevicesinc/linux_image_ADI-scripts.git 
git checkout kuiper2.0
```

**Note:** This package depends on the `gt` (USB Gadget Tool) package. You should build and install the gt package separately before using the USB gadget functionality.

## Usage

### Building the Package

The script should be run from the parent folder of the entire git repository and call the script 

```bash
linux_image_ADI-scripts/packaging/build-adi-scripts-deb.sh [branch] [version] [clone_dir]
```

Parameters:
- `branch`: Branch or tag name (default: `kuiper2.0`) (used for changelog only)
- `version`: Package version (default: `1.0.0`)
- `clone_dir`: Directory where the repository is cloned (default: `linux_image_ADI-scripts`)

### Example

```bash
# Build from kuiper2.0 branch with default version
./build-adi-scripts-deb.sh

# Build from specific branch with custom version
./build-adi-scripts-deb.sh main 1.5

# Build from specific branch with custom version and clone directory
./build-adi-scripts-deb.sh main 1.5 /path/to/linux_image_ADI-scripts
```

## Output Files

The build process generates:
- `adi-scripts_<version>.orig.tar.gz` - Upstream source tarball
- `adi-scripts_<version>-1.debian.tar.xz` - Debian packaging files
- `adi-scripts_<version>-1.dsc` - Debian source package descriptor
- `adi-scripts_<version>-1_all.deb` - Binary package (architecture-independent)

## Package Contents

The package installs:
- Shell scripts to `/usr/bin/`
- Systemd service files to `/etc/systemd/system/`
- Python scripts to `/usr/share/systemd/`
- Configuration files for lightdm, USB gadget, etc.

The following systemd services are enabled on installation:
- `adi-power.service` - Power management service
- `fan-control.service` - Fan control service
- `fix-display-port.service` - DisplayPort fix service

## Notes

- The package is architecture-independent (`all`) as it contains only shell scripts
- Uses upstream Makefile with `make install DESTDIR=... PREFIX=/usr`
- Systemd services are enabled during package installation via postinst script
- The build process creates both binary and source packages automatically
