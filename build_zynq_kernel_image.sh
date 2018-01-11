#!/bin/bash
set -e

# Usage: build_zynq_kernel_image.sh [dt_file] [CROSS_COMPILE]
#  If no dt_file is specified, the default is `zynq-zc702-adv7511-ad9361-fmcomms2-3.dtb`
#  If no CROSS_COMPILE specified, a GCC toolchain will be downloaded
#  from Linaro's website and used.


DTFILE="$1"

[ -n "$NUM_JOBS" ] || NUM_JOBS=5

# set Linaro GCC
GCC_VERSION="${2:-5.5.0-2017.10}"
GCC_DIR=gcc-linaro-$GCC_VERSION-x86_64_arm-linux-gnueabi
GCC_TAR=$GCC_DIR.tar.xz

get_linaro_link() {
	local ver="$1"
	local gcc_dir="${ver:0:3}-${ver:(-7)}"
	echo "https://releases.linaro.org/components/toolchain/binaries/$gcc_dir/arm-linux-gnueabi/$GCC_TAR"
}

# if CROSS_COMPILE hasn't been specified, go with Linaro's
[ -n "$CROSS_COMPILE" ] || {
	if [ ! -d "$GCC_DIR" ] && [ ! -e "$GCC_TAR" ] ; then
		wget "$(get_linaro_link "$GCC_VERSION")"
	fi
	if [ ! -d "$GCC_DIR" ] ; then
		tar -xvf $GCC_TAR || {
			echo "'$GCC_TAR' seems invalid ; remove it and re-download it"
			exit 1
		}
	fi
	CROSS_COMPILE=$(pwd)/$GCC_DIR/bin/arm-linux-gnueabi-
}

# Get ADI Linux if not downloaded
# We won't do any `git pull` to update the tree, users can choose to do that manually
[ -d linux-adi ] || \
	git clone https://github.com/analogdevicesinc/linux.git linux-adi

export ARCH=arm
export CROSS_COMPILE

pushd linux-adi

make zynq_xcomm_adv7511_defconfig

make -j$NUM_JOBS uImage UIMAGE_LOADADDR=0x8000

if [ -z "$DTFILE" ] ; then
	echo
	echo "No DTFILE file specified ; using default 'zynq-zc702-adv7511-ad9361.dtb'"
	DTFILE=zynq-zc702-adv7511-ad9361-fmcomms2-3.dtb
fi

make $DTFILE

popd 1> /dev/null

cp -f linux-adi/arch/arm/boot/uImage .
cp -f linux-adi/arch/arm/boot/dts/$DTFILE .

echo "Exported files: uImage, $DTFILE"

