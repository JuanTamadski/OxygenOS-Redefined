#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

work_dir=$(pwd)
localbuild="$1"
source $work_dir/functions.sh
ANDROID_VER=$(cat $work_dir/bin/ddevice/androidver.txt)
DEVICE_MODEL=$(cat $work_dir/bin/ddevice/device_model.txt)
BASE_BUILD_ID=$(cat $work_dir/bin/ddevice/base_build_id.txt)
BRAND=$(cat $work_dir/bin/ddevice/brand.txt)
super_list="system system_ext product vendor odm my_product my_engineering my_stock my_carrier my_region my_bigball my_heytap my_manifest vendor_dlkm system_dlkm odm_dlkm system_ext_dlkm product_dlkm"

if [[ $BRAND == "OnePlus" ]]; then
  NTBUILD="ColorOS"
elif [[ $BRAND == "OnePlus_Global" ]]; then
  NTBUILD="OxygenOS"
elif [[ $BRAND == "RealmeUI" ]]; then
  NTBUILD="RealmeUI"
fi

OUT_DIR="$work_dir/out/${NTBUILD}_${DEVICE_MODEL}_${ANDROID_VER}_OS${BASE_BUILD_ID}_Fastboot"
mkdir -p "$OUT_DIR"

# 1. Disable vbmeta verification
for img in $(find $work_dir/build/baserom/images -type f -name "vbmeta*.img"); do
    sudo $work_dir/bin/vbmeta-disable-verification "${img}"
    python3 $work_dir/bin/patch-vbmeta.py "${img}"
done

echo "[SCRIPT] - Organizing images for Fastboot flashing..."

# Delete stock recovery if present (Optional: remove this if you want to keep stock recovery)
if [ -f $work_dir/build/baserom/images/recovery.img ]; then 
  rm -rf $work_dir/build/baserom/images/recovery.img
fi

# Move ALL unpacked images to the root of the output directory
mv -f $work_dir/build/baserom/images/*.img "$OUT_DIR/"

# Copy custom preload/company images if they exist
if [ -f "$work_dir/bin/script2flash/my_company.img" ]; then
  cp -rf $work_dir/bin/script2flash/my_company.img "$OUT_DIR/"
fi
if [ -f "$work_dir/bin/script2flash/my_preload.img" ]; then
  cp -rf $work_dir/bin/script2flash/my_preload.img "$OUT_DIR/"
fi

echo "[SCRIPT] - Generating flash_all scripts..."

FLASH_SH="$OUT_DIR/flash_all.sh"
FLASH_BAT="$OUT_DIR/flash_all.bat"

# Initialize headers
echo "#!/bin/bash" > "$FLASH_SH"
echo "echo '========================================'" >> "$FLASH_SH"
echo "echo '  Fastboot Flasher for $DEVICE_MODEL  '" >> "$FLASH_SH"
echo "echo '========================================'" >> "$FLASH_SH"

echo "@echo off" > "$FLASH_BAT"
echo "echo ========================================" >> "$FLASH_BAT"
echo "echo   Fastboot Flasher for $DEVICE_MODEL  " >> "$FLASH_BAT"
echo "echo ========================================" >> "$FLASH_BAT"

# Helper function to write to both OS scripts at once
write_cmd() {
  echo "$1" >> "$FLASH_SH"
  echo "$1" >> "$FLASH_BAT"
}

write_cmd "fastboot --version || (echo 'Fastboot not found!' && exit 1)"
write_cmd "echo 'Waiting for device in fastboot mode...'"
write_cmd "fastboot wait-for-device"

# --- PART 1: Flash static partitions (Regular Bootloader) ---
write_cmd "echo '--- Flashing static firmware partitions ---'"
for img_path in "$OUT_DIR"/*.img; do
  img_name=$(basename "$img_path" .img)
  # If it is NOT a dynamic partition (super_list) and NOT a preload image, flash it here
  if [[ ! " $super_list my_company my_preload " =~ " $img_name " ]]; then
    if [[ "$img_name" == "vbmeta" || "$img_name" == "vbmeta_system" || "$img_name" == "vbmeta_vendor" ]]; then
      write_cmd "fastboot flash $img_name $img_name.img --disable-verity --disable-verification"
    else
      write_cmd "fastboot flash $img_name $img_name.img"
    fi
  fi
done

# --- PART 2: Reboot to fastbootd for dynamic partitions ---
write_cmd "echo '--- Rebooting to fastbootd for logical partitions ---'"
write_cmd "fastboot reboot fastboot"
write_cmd "fastboot wait-for-device"

# --- PART 3: Flash dynamic partitions (Fastbootd) ---
write_cmd "echo '--- Flashing dynamic partitions ---'"
for pname in $super_list my_company my_preload; do
  if [ -f "$OUT_DIR/${pname}.img" ]; then
    # Deleting the logical partition first helps prevent "Not enough space" errors on OPlus devices
    write_cmd "fastboot delete-logical-partition $pname || true"
    write_cmd "fastboot create-logical-partition $pname 1 || true"
    write_cmd "fastboot flash $pname ${pname}.img"
  fi
done

# --- PART 4: Format Data & Reboot ---
# Bash Prompt
echo "read -p 'Format Data? (Wipes all userdata) [y/N]: ' format_data" >> "$FLASH_SH"
echo "if [[ \"\$format_data\" =~ ^[Yy]\$ ]]; then fastboot -w; fi" >> "$FLASH_SH"

# Batch Prompt
echo "set /p format_data=Format Data? (Wipes all userdata) [y/N]: " >> "$FLASH_BAT"
echo "if /I \"%format_data%\"==\"Y\" fastboot -w" >> "$FLASH_BAT"

write_cmd "echo '--- Flashing complete! Rebooting... ---'"
write_cmd "fastboot reboot"

chmod +x "$FLASH_SH"

echo "[SCRIPT] - Fastboot scripts generated successfully."

# Zipping the final package
if [[ $localbuild != "y" ]]; then
  echo "[SCRIPT] - Zipping fastboot package..."
  pushd "$OUT_DIR" > /dev/null || exit
  zip -r "../${NTBUILD}_${DEVICE_MODEL}_${ANDROID_VER}_OS${BASE_BUILD_ID}_Fastboot.zip" ./*
  popd > /dev/null || exit
  rm -rf "$OUT_DIR"
  echo "[SCRIPT] - Build completed."
else
  # Move the folder back to root if it's a local test build
  mv -f "$OUT_DIR" "$work_dir/"
  echo "[SCRIPT] - LocalBuild completed."
fi
