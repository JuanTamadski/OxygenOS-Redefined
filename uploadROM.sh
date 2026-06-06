#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

work_dir=$(pwd)
source $work_dir/functions.sh
ANDROID_VER=$(cat $work_dir/bin/ddevice/androidver.txt)
DEVICE_MODEL=$(cat $work_dir/bin/ddevice/device_model.txt)
BASE_BUILD_ID=$(cat $work_dir/bin/ddevice/base_build_id.txt)
BRAND=$(cat $work_dir/bin/ddevice/brand.txt)


if [[ $(git branch --show-current) == "beta" ]]; then
    VERSION="$(cat $work_dir/Version)"
 	status="Beta"
else
    VERSION="$(cat $work_dir/Version)"
 	status="Official"
fi

if [[ $BRAND == "OnePlus" ]]; then
  NTBUILD="ColorOS"
  uploaddir="ColorOS"
elif [[ $BRAND == "OnePlus_Global" ]]; then
  NTBUILD="OxygenOS"
  uploaddir="OxygenOS"
elif [[ $BRAND == "RealmeUI" ]]; then
  NTBUILD="RealmeUI"
  uploaddir="RealmeUI"
fi

# 1. Look for the file in $work_dir instead of out/, and include the _Fastboot suffix
SOURCE_ZIP="$work_dir/${NTBUILD}_${DEVICE_MODEL}_${ANDROID_VER}_OS${BASE_BUILD_ID}_Fastboot.zip"

if [ ! -f "$SOURCE_ZIP" ]; then
    echo "[ERROR] - Packaged ROM not found at: $SOURCE_ZIP"
    exit 1
fi

# 2. Safely grab the MD5 hash
hash=$(md5sum "$SOURCE_ZIP" | awk '{print $1}' | head -c 5)

# 3. Rename the file in the working directory
output_file="$work_dir/${NTBUILD}_${VERSION}_${DEVICE_MODEL}_OS${BASE_BUILD_ID}_${hash}_${status}_Fastboot.zip"
mv "$SOURCE_ZIP" "$output_file"

echo "[SCRIPT] - Output: "
echo "$output_file"
echo "[ONEDRIVE] - Uploading"

#echo "[SCRIPT] - Output: "
output_file="$work_dir/${NTBUILD}_${VERSION}_${DEVICE_MODEL}_OS${BASE_BUILD_ID}_${hash}_${status}_Fastboot.zip"
echo "$output_file"
echo "[SOURCEFORGE] - Uploading via rsync..."

# Define your SourceForge details here
SF_USER="juanski"
SF_PROJECT="oplus-toolbuild"

echo "[SOURCEFORGE] - Preparing local directory tree..."

# 1. Create the exact folder structure locally on the runner
LOCAL_TREE="$work_dir/sf_upload/${uploaddir}/${VERSION}/${DEVICE_MODEL}"
mkdir -p "$LOCAL_TREE"

# 2. Move the completed ROM into this local folder structure
mv "$output_file" "$LOCAL_TREE/"

echo "[SOURCEFORGE] - Uploading tree via rsync..."

# 3. Rsync the contents of the 'sf_upload' directory directly to the SourceForge project root. 
# Rsync will automatically build the internal folders as it transfers.
rsync -avP -e ssh "$work_dir/sf_upload/" "${SF_USER}@frs.sourceforge.net:/home/frs/project/${SF_PROJECT}/" || {
    echo "[SOURCEFORGE] - Error uploading file to SourceForge"
    exit 1
}


echo "[SYSTEM] - Clean Workflow.."
rm -rf "$work_dir/out"
rm -rf "$work_dir/build"

echo "[INFO] - Build ${NTBUILD}_${VERSION} for ${DEVICE_MODEL} successful !"
