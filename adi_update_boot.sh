#!/bin/bash
shopt -s extglob # activate extended pattern matching

### Set global variables
REPO="linux_image_ADI-scripts"
BRANCH="origin/master"
SERVER="http://swdownloads.analog.com"
SPATH="cse/boot_partition_files"
RPI_SPATH="cse/linux_rpi"
ARCHIVE_NAME="latest_boot_partition.tar.gz"

# Whenever 'latest' and 'previous' are updated, need to update also conditions from next if
LATEST_RELEASE="2021_r2"
RELEASE=$LATEST_RELEASE
LATEST_RPI_BRANCH="rpi-5.10.y"
RPI_BRANCH=$LATEST_RPI_BRANCH
FILE="latest_boot.txt"
RPI_FILE="rpi_archives_properties.txt"

### Allow selective builds. By default use the latest release
if [ "$1" = "help" -o "$1" = "-h" ]; then
  echo "This script can be called with a parameter to select the release:"
  echo "  There can be used 'dev'(or 'master') for boot files from master,"
  echo "  or a specific release (for example '2019_R2') for specific boot files."
  echo "  By default will use latest released version (right now being $LATEST_RELEASE)."
  exit 0
elif [ "$1" = "dev"  -o "$1" = "master" ]; then
  RELEASE="master"
  RPI_BRANCH="rpi-5.10.y"
elif [ "$1" = "2019_R1" -o "$1" = "2019_r1" ]; then
  RELEASE="2019_r1"
  RPI_BRANCH="rpi-4.9.y"
elif [ "$1" = "2019_R2" -o "$1" = "2019_r2" ]; then
  RELEASE="2019_r2"
  RPI_BRANCH="rpi-5.4.y"
elif [ "$1" = "2021_R1" -o "$1" = "2021_r1" ]; then
  RELEASE="2021_r1"
  RPI_BRANCH="rpi-5.10.y"
elif [ "$1" = "2021_R2" -o "$1" = "2021_r2" ]; then
  RELEASE="2021_r2"
  RPI_BRANCH="rpi-5.10.y"
fi

### Verify if current script is latest version
echo -e "\nVerifying if ./adi_update_boot.sh is up to date..."
cd /usr/local/src
if [ -d $REPO ]; then
  cd ./$REPO
  git checkout -f $BRANCH
  git fetch
  git checkout -f $BRANCH 2>/dev/null
  cd ..
else
  git clone https://github.com/analogdevicesinc/$REPO.git || continue
fi
cd ./$REPO
md5_self=`md5sum $0 | awk '{print $1}'`
md5_new=`md5sum ./adi_update_boot.sh | awk '{print $1}'`
if [ $md5_new != $md5_self ]; then
  echo -e "./adi_update_boot.sh has been updated, installing and switching to new one...\n"
  make install
  ./adi_update_boot.sh $@
  exit
else
  echo -e "./adi_update_boot.sh is up to date, continuing...\n"
fi

### Check if script is ran as root
if [ `id -u` != "0" ]; then
   echo -e "\nThis script must be run as root" 1>&2
   exit 1
fi

### Check mount point of boot partition.
# Mount it if doesn't exist, exit if mounting failed
# Depending on carrier, by default it can be /boot or /media/boot
mmc_mounted=$(mount | grep -i 'mmcblk0p1')
if [[ "$mmc_mounted" == "" ]]; then
  FAT_MOUNT="/media/boot"
  mkdir -p $FAT_MOUNT 2>/dev/null
  mount /dev/mmcblk0p1 $FAT_MOUNT
  if [ $? -ne 0 ]; then
    echo "Mounting /dev/mmcblk0p1 failed" 1>&2
    exit 1
  fi
else
  FAT_MOUNT=$(mount | grep 'mmcblk0p1' | cut -d' ' -f3)
fi
fatsize=`df | grep /dev/mmcblk0p1 | sed -n '1p' | awk '{print $2}'`
if [ $fatsize -lt 300000 ]; then
  echo -e "\n==== WARNING ====\n"
  echo "Old SD Card Image detected. Please update!"
  echo "See http://wiki.analog.com/resources/tools-software/linux-software/zynq_images"
  echo -e "================="
  umount $FAT_MOUNT
  exit 1
fi

### Download new descriptor file
rm $FILE 2>/dev/null
echo -e "\nCheck latest available version..."
wget --no-check-certificate "$SERVER/$SPATH/$RELEASE/$FILE"
if [ $? -ne 0 ]; then
  echo -e "\nDownloading $SERVER/$SPATH/$RELEASE/$FILE failed - Aborting."  1>&2
  umount $FAT_MOUNT
  exit 1
fi

### Convert any windows characters from descriptor file in unix format
sed -i 's/\r$//' $FILE

### Extract version and release from downloaded file (latest_boot.txt)
# First line can be boot_master_<timestamp> or boot_<release>_<timestamp>
nr=$(sed -n 1p $FILE | tr -cd '_' | wc -c)
if [ $nr -lt 5 ]; then
   new_version=$(sed -n 1p $FILE|sed 's/_/ /1'|sed 's/_/ /1'|cut -d' ' -f3)
   new_release=$(sed -n 1p $FILE|sed 's/_/ /1'|sed 's/_/ /1'|cut -d' ' -f2)
else
   new_version=$(sed -n 1p $FILE|sed 's/_/ /1'|sed 's/_/ /2'|cut -d' ' -f3)
   new_release=$(sed -n 1p $FILE|sed 's/_/ /1'|sed 's/_/ /2'|cut -d' ' -f2)
fi
new_url=$(sed -n 2p $FILE)
new_md5=$(sed -n 3p $FILE | cut -d' ' -f2)
echo -e "\nLatest version available: $new_version"
echo -e "Release: $new_release\n"

### Extract current version and release
CURRENT_VERSION_FILE="$FAT_MOUNT/VERSION.txt"
if [ -f $CURRENT_VERSION_FILE ]; then
  # If there is VERSION.txt - first line has next format: "Boot partition: [<Release>] <YYYY_MM_DD-HH_mm_SS>"
  # Check first if contains also <release> by counting number of spaces
  nr=$(sed -n 1p $CURRENT_VERSION_FILE | tr -cd ' ' | wc -c)
  if [ "$nr" -gt "2" ]; then
    current_version=$(sed -n 1p $CURRENT_VERSION_FILE | cut -d' ' -f4 | cut -d'-' -f1)
    current_release=$(sed -n 1p $CURRENT_VERSION_FILE | cut -d' ' -f3 | cut -d'-' -f1)
  else
    current_version=$(sed -n 1p $CURRENT_VERSION_FILE | cut -d' ' -f3 | cut -d'-' -f1)
    current_release=$(sed -n 8p $CURRENT_VERSION_FILE); current_release=${current_release##* }
  fi
elif [ -f "$FAT_MOUNT/VERSION" ]; then
  # If there is VERSION (no .txt extension/used for older releases) there is "boot_<release>_<YYYY_MM_DD>"
  current_release=$(sed -n 1p $FAT_MOUNT/VERSION|sed 's/_/ /1'|sed 's/_/ /2'|cut -d' ' -f2)
  current_version=$(sed -n 1p $FAT_MOUNT/VERSION|sed 's/_/ /3'|cut -d' ' -f2)
else
  echo -e "\nWarning! No VERSION or VERSION.txt file found in boot partition, current version of files cannot be extracted."
  echo "Please update whole SD card by following steps from http://wiki.analog.com/resources/tools-software/linux-software/zynq_images"
  umount $FAT_MOUNT
  rm $FILE
  exit 0
fi
echo -e "\nCurrent version detected: $current_version"
echo -e "Release: $current_release\n"

### Compare old and new releases and versions
current_release=$(echo $current_release | tr '[:upper:]' '[:lower:]')
new_release=$(echo $new_release | tr '[:upper:]' '[:lower:]')
if [ "$current_release" != "$new_release" ]; then
  # Check if files fit on boot partition (for older release including 2019-R2 there is 1 GB, newer ones have 2 GB)
  boot_part_size=$(df -k $FAT_MOUNT | awk '/[0-9]%/{print $(NF-4)}' | sed 's/G//')
  if [[ "$new_release" =~ *"2021_r1"* ]] || [[ "$new_release" =~ *"2021_r2"* ]] || [[ "$new_release" =~ *"master"* ]]; then
    if [[ $boot_part_size -lt 1250000 ]]; then
      echo -e "\nWarning! You want to update boot files from a newer release: $new_release (current release: $current_release)"
      echo "But newer releases have the size of boot files more than 1 GB (the size of boot partition used in older releases),"
      echo "so boot files wont fit on boot partition."
      echo -e "\nPlease update whole SD card by following steps from http://wiki.analog.com/resources/tools-software/linux-software/zynq_images"
      rm $FILE
      umount $FAT_MOUNT
      exit 0
    fi
  fi
  echo -e "\nWarning! You want to update boot files from a different release: $new_release (current release: $current_release)"
  echo "In this case there may appear compatibility issues with root file system."
  while true
    do
      read -r -p 'Are you sure you want to continue?(y/n) ' answer
      case "$answer" in
        n)
          echo "Done."
          rm $FILE
          umount $FAT_MOUNT
          exit 0
          ;;
        y)
          echo -e "Continuing...\n"
          break
          ;;
        *)
          echo "Valid answers: y/n"
          ;;
      esac
  done
fi

# Transform current and new versions in 'date' datatype and compare them
current_version_date=$(date -d $(echo "$current_version" | sed 's/_/-/g') +"%Y%m%d")
new_version_date=$(date -d $(echo "$new_version" | sed 's/_/-/g') +"%Y%m%d")
if [ $new_version_date -le $current_version_date ]; then
  echo "Already up to date!"
  rm $FILE
  umount $FAT_MOUNT
  exit 0
fi

### Download new boot files archive and check md5sum
echo -e "\nStart downloading $ARCHIVE_NAME ..."
rm -rf $ARCHIVE_NAME
wget --no-check-certificate -nc $new_url
if [ $? -ne 0 ]; then
  echo "Download failed - aborting" 1>&2
  rm -f $FILE
  umount $FAT_MOUNT
  exit 1
else
  key=`md5sum $ARCHIVE_NAME | awk '{print $1}'`
  if [ $key != $new_md5 ]; then
    echo "MD5SUM Error" 1>&2
    rm -rf $ARCHIVE_NAME
    rm -f $FILE
    umount $FAT_MOUNT
    exit 1
  fi
fi

### Download RPI boot files (kernels and modules) and check md5

rm -rf $RPI_FILE
wget --no-check-certificate "$SERVER/$RPI_SPATH/$RPI_BRANCH/$RPI_FILE"
if [ $? -ne 0 ]; then
  echo -e "\nDownloading $SERVER/$RPI_SPATH/$RPI_BRANCH/$RPI_FILE failed - Aborting."  1>&2
  umount $FAT_MOUNT
  exit 1
fi

### Extract information from RPI_FILE:
#  line #2 is path to rpi_modules.tar.gz
#  line #3 is path to rpi_latest_boot.tar.gz
#  line #4 is checksum of modules archive
#  line #5 is checksum of boot archive

rpi_modules_url=$(sed -n 2p $RPI_FILE)
rpi_boot_url=$(sed -n 3p $RPI_FILE)
rpi_modules_key=$(sed -n 4p $RPI_FILE | cut -d'=' -f2)
rpi_boot_key=$(sed -n 5p $RPI_FILE | cut -d'=' -f2)

RPI_MODULES_ARCHIVE_NAME="rpi_modules.tar.gz"
echo -e "\nStart downloading $RPI_MODULES_ARCHIVE_NAME..."
rm -rf $RPI_MODULES_ARCHIVE_NAME
wget --no-check-certificate -nc $rpi_modules_url
if [ $? -ne 0 ]; then
  echo "Download failed - aborting" 1>&2
  rm -rf $FILE $RPI_FILE $RPI_MODULES_ARCHIVE_NAME
  umount $FAT_MOUNT
  exit 1
else
  key=`md5sum $RPI_MODULES_ARCHIVE_NAME | awk '{print $1}'`
  if [ $key != $rpi_modules_key ]; then
    echo "MD5SUM Error" 1>&2
    rm -rf $FILE $RPI_FILE $RPI_MODULES_ARCHIVE_NAME
    umount $FAT_MOUNT
    exit 1
  fi
fi

RPI_BOOT_ARCHIVE_NAME="rpi_latest_boot.tar.gz"
echo -e "\nStart downloading $RPI_BOOT_ARCHIVE_NAME..."
rm -rf $RPI_BOOT_ARCHIVE_NAME
wget --no-check-certificate -nc $rpi_boot_url
if [ $? -ne 0 ]; then
  echo "Download failed - aborting" 1>&2
  rm -rf $FILE $RPI_FILE $RPI_BOOT_ARCHIVE_NAME
  umount $FAT_MOUNT
  exit 1
else
  key=`md5sum $RPI_BOOT_ARCHIVE_NAME | awk '{print $1}'`
  if [ $key != $rpi_boot_key ]; then
    echo "MD5SUM Error" 1>&2
    rm -rf $FILE $RPI_FILE $RPI_BOOT_ARCHIVE_NAME
    umount $FAT_MOUNT
    exit 1
  fi
fi

############# Restoring boot config methods #############

### Define "find_current_setup" method - find current setup by device tree md5sum
find_current_setup ()
{
  # There may be devicetree.dtb, system.dtb, socfpga.dtb etc, depending on setup - get the file name
  dtb_file_name=$(basename $(ls $1/socfpg*.dtb 2>/dev/null) 2>/dev/null)
  if [[ "$dtb_file_name" == "" ]];then
    dtb_file_name=$(basename $(ls $1/devicetree.dtb 2>/dev/null) 2>/dev/null)
    if [[ "$dtb_file_name" == "" ]];then
      dtb_file_name=$(basename $(ls $1/system.dtb 2>/dev/null) 2>/dev/null)
      if [[ "$dtb_file_name" == "" ]];then
        exit
      fi
    fi
  fi
  key=`md5sum $1/$dtb_file_name | awk '{print $1}'`
  matching_files=$(find $1/ -name "$dtb_file_name")
  for file in $matching_files ; do
    t=`md5sum $file | awk '{print $1}'`
    if [ "$t" == "$key" ] ; then
      echo "$(dirname $file)"
      exit
    fi
  done
}

### Define "restoring_boot_bin" method - try to restore BOOT.BIN
restoring_boot_bin()
{
  if [[ "$1" == *"zynq-"* ]] || [[ "$1" == *"zynqmp"* ]] || [[ "$1" == *"versal"* ]]; then
    echo -e "\nRestoring BOOT.BIN..."
    if [ -e "$1/BOOT.BIN" ]; then # BOOT.BIN may be 1 or 2 level up
      cp $1/BOOT.BIN $FAT_MOUNT/
    else
      CURRENT_FOLDER=$(dirname $1)
      if [ -e "$CURRENT_FOLDER/BOOT.BIN" ]; then
        cp $CURRENT_FOLDER/BOOT.BIN $FAT_MOUNT/
      else
        $CURRENT_FOLDER=$(dirname $CURRENT_FOLDER)
        if [ -e "$CURRENT_FOLDER/BOOT.BIN" ]; then
          cp $CURRENT_FOLDER/BOOT.BIN $FAT_MOUNT/
        else
          echo "Warning! BOOT.BIN cannot be restored. "
          echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
          exit 1
        fi
      fi
      echo "BOOT.BIN restored."
    fi
  elif [[ "$1" == *"arria10"* ]]; then
    echo -e "\nRestoring socfpga_arria10_socdk.rbf/fit_spl_fpga.itb..."
    # Restore config depending on release, in master and starting with 2021_R1
    # there is a different boot flow (starting with Quartus Pro 20.1)
    if [ "$new_release" == "2019_r1" -o "$new_release" == "2019_r2" ]; then
      if [ -e $1/socfpga_arria10_socdk.rbf ]; then
        cp $1/socfpga_arria10_socdk.rbf $FAT_MOUNT/
      else
        echo "Warning! socfpga_arria10_socdk.rbf cannot be restored. "
        echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
        exit 1
      fi
    else # new quartus boot flow
      if [ -e $1/fit_spl_fpga.itb ]; then
        cp $1/fit_spl_fpga.itb $FAT_MOUNT/
      else
        echo "Warning! fit_spl_fpga.itb (equivalent of rbf file for a10soc) cannot be restored. "
        echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
        exit 1
      fi
    fi
    echo "socfpga_arria10_socdk.rbf/fit_spl_fpga.itb restored."
  elif [[ "$1" == *"cyclone5"* ]]; then
    echo -e "\nRestoring soc_system.rbf..."
    if [ -e $1/soc_system.rbf ]; then
      cp $1/soc_system.rbf $FAT_MOUNT/
    else
      echo "Warning! soc_system.rbf cannot be restored. "
      echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
      exit 1
    fi
    echo "soc_system.rbf restored."
  fi
}

### Define "restoring_device_tree" method - try to restore device_tree
restoring_device_tree()
{
  echo -e "\nRestoring device tree..."
  if [[ "$1" == *"zynq-"* ]]; then
    device_tree_name="devicetree.dtb"
  elif [[ "$1" == *"zynqmp"* ]] || [[ "$1" == *"versal"* ]]; then
    device_tree_name="system.dtb"
  elif [[ "$1" == *"arria10"* ]]; then
    device_tree_name="socfpga_arria10_socdk_sdmmc.dtb"
  elif [[ "$1" == *"cyclone5"* ]]; then
    device_tree_name="socfpga.dtb"
  else
    echo "Warning! Device tree cannot be restored."
    echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
    exit 1
  fi
  if [ -e "$1/$device_tree_name" ]; then
    cp $1/$device_tree_name $FAT_MOUNT/
  else
    echo "Warning! Device tree cannot be restored."
    echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
    exit 1
  fi
  echo "$device_tree_name restored."
}

### Define "restoring_image" method - try to restore image
restoring_image()
{
  echo -e "\nRestoring image..."
  zynq_image="$FAT_MOUNT/zynq-common/uImage"
  zynqmp_image="$FAT_MOUNT/zynqmp-common/Image"
  versal_image="$FAT_MOUNT/versal-common/Image"
  # A10SOC and C5SOC images paths depend on release
  if [[ "$new_release" == "2019_r1" ]] || [[ "$new_release" == "2019_r2" ]]; then
    a10soc_image="$FAT_MOUNT/socfpga_arria10-common/zImage"
    c5soc_image="$FAT_MOUNT/socfpga_cyclone5_sockit_arradio/uImage"
    de10nano_image="$FAT_MOUNT/socfpga_cyclone5_de10_nano_cn0540/zImage"
  else
    a10soc_image="$FAT_MOUNT/socfpga_arria10_common/zImage"
    c5soc_image="$FAT_MOUNT/socfpga_cyclone5_common/zImage"
    de10nano_image="$FAT_MOUNT/socfpga_cyclone5_common/zImage"
  fi
  if [[ "$1" == *"zynq-"* ]]; then
    image=$zynq_image
  elif [[ "$1" == *"zynqmp"* ]]; then
    image=$zynqmp_image
  elif [[ "$1" == *"versal"* ]]; then
    image=$versal_image
  elif [[ "$1" == *"arria10"* ]]; then
    image=$a10soc_image
  elif [[ "$1" == *"de10"* ]]; then
    image=$de10nano_image
  elif [[ "$1" == *"cyclone5"* ]]; then
    image=$c5soc_image
  else
    echo "Warning! Image cannot be restored."
    echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
    exit 1
  fi
  if [ -e "$image" ]; then
    cp $image $FAT_MOUNT/
  else
    echo "Warning! Image cannot be restored."
    echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
    exit 1
  fi
  echo -e "Image restored."
}

### Define "restoring_extra_files" method - used for exceptions
restoring_extra_files()
{
  if [[ "$1" == *"cyclone5"* ]]; then
    echo -e "\nRestoring u-boot.scr (specific to cyclone5 projects)..."
    if [ -e "$1/u-boot.scr" ]; then
      cp "$1/u-boot.scr" $FAT_MOUNT/
    else
      echo "Warning! u-boot.scr cannot be restored."
      echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
      exit 1
    fi
    echo "u-boot.scr restored."
    # Restore config depending on release, in master and starting with 2021_R1
    # there is a different boot flow (starting with Quartus Pro 20.1)
    if [ "$new_release" != "2019_r1" ] && [ "$new_release" != "2019_r2" ]; then
      echo -e "\nRestoring extlinux/extlinux.conf (specific to cyclone5 projects starting with 2021_r1 release)..."
      if [ -e "$1/extlinux.conf" ]; then
        mkdir -p $FAT_MOUNT/extlinux;
        cp $1/extlinux.conf $FAT_MOUNT/extlinux/
      else
        echo "Warning! extlinux.conf cannot be restored."
        echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
        exit 1
      fi
      echo "extlinux.conf restored."
    fi
  elif [[ "$1" == *"arria10"* ]]; then
    # Restore config depending on release, in master and starting with 2021_R1
    # there is a different boot flow (starting with Quartus Pro 20.1)
    if [ "$new_release" != "2019_r1" ] && [ "$new_release" != "2019_r2" ]; then
      echo -e "\nRestoring u-boot.img (specific to arria10soc projects starting with 2021_r1 release)..."
      if [ -e "$1/u-boot.img" ]; then
        cp $1/u-boot.img $FAT_MOUNT/
      else
        echo "Warning! u-boot.img cannot be restored."
        echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
        exit 1
      fi
      echo "u-boot.img restored."
      echo -e "\nRestoring extlinux/extlinux.conf (specific to cyclone5 projects starting with 2021_r1 release)..."
      if [ -e "$1/extlinux.conf" ]; then
        mkdir -p $FAT_MOUNT/extlinux;
        cp $1/extlinux.conf $FAT_MOUNT/extlinux/
      else
        echo "Warning! extlinux.conf cannot be restored."
        echo "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)"
        exit 1
      fi
      echo "extlinux.conf restored."
    fi
  fi
}

### Define "write_preloader" method - restore preloader for intel projests
write_preloader()
{
  if [[ "$1" == *"arria10"* ]]||[[ "$1" == *"cyclone5"* ]]; then
    # Preloader name depends on carrier and release
    echo -e "\nWriting preloader..."
    if [ "$new_release" == "2019_r1" ] || [ "$new_release" == "2019_r2" ]; then
      if [[ "$1" == *"arria10"* ]]; then
        preloader="preloader_bootloader.bin"
      elif [[ "$1" == *"cyclone5"* ]]; then
        preloader="preloader_bootloader.img"
      fi
    else
      if [[ "$1" == *"arria10"* ]]; then
        preloader="u-boot-splx4.sfp"
      elif [[ "$1" == *"cyclone5"* ]]; then
        preloader="u-boot-with-spl.bin"
      fi
    fi
    if [ -e "$1/$preloader" ]; then
      cp $1/$preloader .
      dd if=$preloader of=/dev/mmcblk0p3
      if [ $? -ne 0 ];then
        echo "Writing preloader ($preloader) failed - aborting"
        echo "You will have to manually write it (see boot partition Readme.txt)"
      fi
    else
      echo "Warning! Preloader ($preloader) cannot be restored. "
      echo "You will have to manually write it (see boot partition Readme.txt)"
      exit 1
    fi
    echo "Preloader restored."
  fi
}
###################################################################
### Check first if there is only one dtb in boot partition root, and if yes- detect configuration
echo -e "First detecting current boot configuration..."
socfpga_dtb=$(ls $FAT_MOUNT/socfpg*.dtb 2>/dev/null | wc -l)
zynq_dtb=$(ls $FAT_MOUNT/devicetree.dtb 2>/dev/null | wc -l)
zynqmp_dtb=$(ls $FAT_MOUNT/system.dtb 2>/dev/null | wc -l)
number_of_dtb_files=$(( $socfpga_dtb + $zynq_dtb + $zynqmp_dtb ))
#echo -e "\n socfpga_dtb: $socfpga_dtb\n zynq_dtb: $zynq_dtb\n zynqmp_dtb: $zynqmp_dtb\n sum: $number_of_dtb_files"
if [ "$number_of_dtb_files" -ne 1 ]; then
  CURRENT_CONFIG=""
else
  CURRENT_CONFIG=`find_current_setup $FAT_MOUNT` # CURRENT_CONFIG can be empty from here too
fi
if [ "$CURRENT_CONFIG" == "" ]; then
  echo -e "\nWarning! There is no or multiple device tree files in boot partition root in current setup."
  echo -e "You will have to manually copy specific boot files in boot partition root (see boot partition Readme.txt)\n"
else
  echo -e "Current configuration: $CURRENT_CONFIG\n"
fi

default_files="fixup*.dat|start*.elf|bootcode.bin|cmdline.txt|config.txt|LICENCE.*|COPYING.linux|issue.txt"

# Before proceeding with deleting files from /boot, check if unpacked files will fit

# Size, in bytes, of uncompressed files from latest_boot_partition.tar.gz
extracted_boot_files_size=$(echo $(gzip -l $ARCHIVE_NAME) | cut -d' ' -f'6')

# Size, in bytes, of uncompressed files from rpi_latest_boot.tar.gz
extracted_rpi_files_size=$(echo $(gzip -l $RPI_BOOT_ARCHIVE_NAME) | cut -d' ' -f'6')

# Size, in bytes, of files that won't be deleted from /boot
cd $FAT_MOUNT
# Next line replace '|' with space in variable 'default_files', run 'du -cs' on the list of files then cut the total size from command output
kuiper_rpi_files_size=$(echo $(du -cs $(echo $default_files | sed 's/|/ /g')) | rev | cut -d' ' -f'2' | rev)
cd - 2>&1 >/dev/null

# Computing required size by adding all previous values plus a buffer of 100 MB
required_space=$(( $extracted_boot_files_size + $extracted_rpi_files_size + $kuiper_rpi_files_size + 104857600 ))

# Computing size of /boot in bytes using 'df -B1'
boot_partition_size=$(echo $(df -B1 $MOUNT_POINT) | cut -d' ' -f'9')

if [[ ${required_space} -ge ${boot_partition_size} ]]; then
  echo "Downloaded archives cannot be extracted on $MOUNT_POINT because there is not enough space."
  echo "Please update whole SD card by following steps from http://wiki.analog.com/resources/tools-software/linux-software/zynq_images"
  rm -rf $FILE $RPI_FILE $ARCHIVE_NAME $RPI_BOOT_ARCHIVE_NAME $RPI_MODULES_ARCHIVE_NAME
  umount $FAT_MOUNT
  exit 0
fi

### Replace files on boot partition
echo -e "\n\nATTENTION!\nNext step will delete files from /boot. Make sure you backup modified files on another partition (rootfs for example) before proceeding next!!!\n"
while true
  do
    read -r -p 'Are you sure you want to continue? (y/n) ' answer
    case "$answer" in
      n)
        umount $FAT_MOUNT
        exit 0
        ;;
      y)
        ### Remove boot partition
        echo "Removing boot files from /boot..."
        cd "$FAT_MOUNT" || exit 1
        rm -rf !($default_files)
        cd - 2>&1 >/dev/null
        ### Extract new files
        echo -e "\nExtracting files from $ARCHIVE_NAME in boot partition... be patient!"
        tar -C $FAT_MOUNT -xzf ./$ARCHIVE_NAME --no-same-owner --checkpoint=.1000
        if [ $? -ne 0 ]; then
          echo "Extraction failed - aborting" 1>&2
          umount $FAT_MOUNT
          exit 1
        fi
        echo -e "\nExtracting files from $RPI_BOOT_ARCHIVE_NAME in boot partition... be patient!"
        tar -C $FAT_MOUNT -xvf ./$RPI_BOOT_ARCHIVE_NAME --no-same-owner --checkpoint=.1000
        if [ $? -ne 0 ]; then
          echo "Extraction failed - aborting" 1>&2
          umount $FAT_MOUNT
          exit 1
        fi
        echo -e "\nExtracting files from $RPI_MODULES_ARCHIVE_NAME in /lib/modules... be patient!"
        tar -C /lib/modules -xvf ./$RPI_MODULES_ARCHIVE_NAME --no-same-owner --checkpoint=.1000
        if [ $? -ne 0 ]; then
          echo "Extraction failed - aborting" 1>&2
          umount $FAT_MOUNT
          exit 1
        fi
        echo  -e "\nBoot partition files were updated successfully."
        break
        ;;
      *)
        echo 'Valid answers: y/n'
        ;;
    esac
done

if [ "$CURRENT_CONFIG" != "" ]; then
  echo -e "\nNext step tries to restore boot configuration (overwrite boot files directly on boot partition root)."
  while true
  do
    read -r -p 'Are you sure you want to continue?(y/n) ' answer
    case "$answer" in
      n)
        echo "Done."
        umount $FAT_MOUNT
        exit 0
        ;;
      y)
        echo -e "\nTry to restore boot files configuration (BOOT.BIN, device tree, image etc)..."
        ### Call methods that try to restore current configuration
        restoring_boot_bin $CURRENT_CONFIG
        restoring_device_tree $CURRENT_CONFIG
        restoring_image $CURRENT_CONFIG
        restoring_extra_files $CURRENT_CONFIG
        write_preloader $CURRENT_CONFIG
        echo -e "\nDone\nNext reboot will use new files for booting."
        break
        ;;
      *)
        echo "Valid answers: y/n"
        ;;
    esac
  done
fi

echo -e "\nRemoving temporary files..."
sync

rm -rf $FILE $RPI_FILE
rm -rf $ARCHIVE_NAME $RPI_BOOT_ARCHIVE_NAME $RPI_MODULES_ARCHIVE_NAME
umount $FAT_MOUNT
echo -e "\nDONE"
exit 0
