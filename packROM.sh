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

# The aggressive vbmeta-disable-verification and patch-vbmeta.py loop 
# has been permanently removed from here to prevent fastbootd fake-locks.

echo "[SCRIPT] - Generating flashing script"
OUT_DIR="$work_dir/out/${NTBUILD}_${DEVICE_MODEL}_${ANDROID_VER}_OS${BASE_BUILD_ID}"

mkdir -p "$OUT_DIR/SYSTEM"
mkdir -p "$OUT_DIR/EXTRA"
mkdir -p "$OUT_DIR/CRITICAL"
mkdir -p "$OUT_DIR/BOOTLOADER"
mkdir -p "$OUT_DIR/MODEM"

# --- GITHUB INTEGRATION START ---
echo "[SCRIPT] - Fetching latest AnyKernel3 from JuanTamadski/Action-Build..."

# Determine the target device based on the ROM variables.
if [[ "$DEVICE_MODEL" == *"PJD110"* ]] || [[ "$OS_TYPE" == *"ColorOS"* ]] || [[ "$INPUT_URL" == *"ColorOS"* ]]; then
    AK3_KEYWORD="ace3"
    echo "[SCRIPT] - Detected Ace 3 (ColorOS) build. Targeting kernel with keyword: ${AK3_KEYWORD}"
else
    AK3_KEYWORD="12r"
    echo "[SCRIPT] - Detected 12R (OxygenOS) build. Targeting kernel with keyword: ${AK3_KEYWORD}"
fi

# Use GitHub Token to prevent rate limiting and access private repos
if [ -n "$GITHUB_TOKEN" ]; then
    echo "[SCRIPT] - Authenticated GitHub API request..."
    AK3_URL=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/repos/JuanTamadski/Action-Build/releases/latest | grep "browser_download_url" | grep -i "anykernel.*${AK3_KEYWORD}.*\.zip" | head -n 1 | cut -d '"' -f 4)
else
    echo "[SCRIPT] - Unauthenticated GitHub API request..."
    AK3_URL=$(curl -s https://api.github.com/repos/JuanTamadski/Action-Build/releases/latest | grep "browser_download_url" | grep -i "anykernel.*${AK3_KEYWORD}.*\.zip" | head -n 1 | cut -d '"' -f 4)
fi

if [ -n "$AK3_URL" ]; then
    # FIXED: Download to a temporary working directory instead of $OUT_DIR/EXTRA
    AK3_TMP_DIR="$work_dir/ak3_tmp"
    mkdir -p "$AK3_TMP_DIR"
    
    echo "[SCRIPT] - Downloading $(basename "$AK3_URL") to temporary directory..."
    curl -L "$AK3_URL" -o "$AK3_TMP_DIR/AnyKernel3.zip"
    
    # Extract the zip to get the kernel binary (usually named 'Image')
    echo "[SCRIPT] - Extracting kernel binary..."
    unzip -q "$AK3_TMP_DIR/AnyKernel3.zip" -d "$AK3_TMP_DIR"
    
    # Point your Magiskboot patching logic to look here:
    # e.g., KERNEL_BINARY="$AK3_TMP_DIR/Image"
else
    echo "[WARN] - No AnyKernel3 zip found matching '${AK3_KEYWORD}' in the latest release."
fi
# --- GITHUB INTEGRATION END ---

# --- AUTOMATED KERNEL PATCHING START ---
MAGISKBOOT="$work_dir/bin/Linux/x86_64/magiskboot"
AK3_ZIP="$OUT_DIR/EXTRA/AnyKernel3.zip"
BOOT_IMG_PATH="$work_dir/build/baserom/images/boot.img"

if [ -f "$AK3_ZIP" ] && [ -f "$MAGISKBOOT" ] && [ -f "$BOOT_IMG_PATH" ]; then
    echo "[SCRIPT] - Initiating host-side kernel patching..."
    TMP_KDIR="$work_dir/tmp_kernel"
    mkdir -p "$TMP_KDIR"
    
    echo "[SCRIPT] - Extracting custom kernel from AnyKernel3.zip..."
    unzip -q -j "$AK3_ZIP" "*Image" -d "$TMP_KDIR/"
    
    if [ -f "$TMP_KDIR/Image" ]; then
        pushd "$TMP_KDIR" >/dev/null || exit
        cp "$BOOT_IMG_PATH" .
        echo "[SCRIPT] - Unpacking stock boot.img..."
        "$MAGISKBOOT" unpack boot.img >/dev/null 2>&1
        
        if [ -f "kernel" ]; then
            echo "[SCRIPT] - Swapping stock kernel with custom Image..."
            cp Image kernel
            echo "[SCRIPT] - Repacking boot.img..."
            "$MAGISKBOOT" repack boot.img >/dev/null 2>&1
            
            if [ -f "new-boot.img" ]; then
                mv -f new-boot.img "$BOOT_IMG_PATH"
                echo "[SCRIPT] - Successfully patched boot.img!"
            else
                echo "[ERROR] - magiskboot repack failed."
            fi
        else
            echo "[ERROR] - magiskboot could not find 'kernel' in boot.img."
        fi
        popd >/dev/null || exit
    else
        echo "[WARN] - No 'Image' file found inside the AnyKernel3 zip. Skipping patch."
    fi
    rm -rf "$TMP_KDIR"
fi
# --- AUTOMATED KERNEL PATCHING END ---

# --- VENDOR BOOT GKI FIX START ---
echo "[SCRIPT] - Securing pure stock vendor_boot to prevent fastbootd lock..."
# 1. Destroy the edited vendor_boot so it cannot trigger a security panic
if [ -f "$work_dir/build/baserom/images/vendorboot_edt.img" ]; then
    rm -f "$work_dir/build/baserom/images/vendorboot_edt.img"
fi

# 2. Rescue the pure stock version and rename it for standard flashing
if [ -f "$work_dir/build/baserom/images/vendorboot_stk.img" ]; then
    mv -f "$work_dir/build/baserom/images/vendorboot_stk.img" "$OUT_DIR/BOOTLOADER/vendor_boot.img"
elif [ -f "$work_dir/build/baserom/images/vendor_boot.img" ]; then
    mv -f "$work_dir/build/baserom/images/vendor_boot.img" "$OUT_DIR/BOOTLOADER/vendor_boot.img"
fi
# --- VENDOR BOOT GKI FIX END ---


# 1. MODEM
if [ -f "$work_dir/build/baserom/images/modem.img" ]; then
    mv -f "$work_dir/build/baserom/images/modem.img" "$OUT_DIR/MODEM/"
fi

# 2. BOOTLOADER (vendor_boot is already moved above)
for b_img in boot dtbo init_boot recovery vbmeta vbmeta_system vbmeta_vendor vbmeta_boot; do
    if [ -f "$work_dir/build/baserom/images/${b_img}.img" ]; then
        mv -f "$work_dir/build/baserom/images/${b_img}.img" "$OUT_DIR/BOOTLOADER/"
    fi
done

# 3. SYSTEM
for pname in ${super_list}; do
    if [ -f "$work_dir/build/baserom/images/${pname}.img" ]; then
        mv -f "$work_dir/build/baserom/images/${pname}.img" "$OUT_DIR/SYSTEM/"
    fi
done

# Copy my_company and my_preload to SYSTEM from script2flash
if [ -f "$work_dir/bin/script2flash/my_company.img" ]; then
    cp -rf "$work_dir/bin/script2flash/my_company.img" "$OUT_DIR/SYSTEM/"
fi
if [ -f "$work_dir/bin/script2flash/my_preload.img" ]; then
    cp -rf "$work_dir/bin/script2flash/my_preload.img" "$OUT_DIR/SYSTEM/"
fi

# 4. CRITICAL (Move all remaining unmatched images here)
if ls "$work_dir/build/baserom/images/"*.img >/dev/null 2>&1; then
    mv -f "$work_dir/build/baserom/images/"*.img "$OUT_DIR/CRITICAL/"
fi

# generate dynamic script
# Uncomment if you you want it as flashable in TWRP
#if [ -d "$work_dir/bin/script2flash/META-INF" ]; then
#    cp -rf "$work_dir/bin/script2flash/META-INF" "$OUT_DIR/"
#fi
#if ls "$work_dir/bin/script2flash/"*.exe >/dev/null 2>&1; then
#   cp -rf "$work_dir/bin/script2flash/"*.exe "$OUT_DIR/"
#fi

echo "[SCRIPT] - Packaging output into a standard .zip archive..."
ZIP_NAME="${NTBUILD}_${DEVICE_MODEL}_${ANDROID_VER}_OS${BASE_BUILD_ID}_Fastboot.zip"

# Navigate into the output directory so the zip structure is flat 
# (Users will see the 5 folders immediately upon extracting)
pushd "$OUT_DIR" >/dev/null || exit
zip -r "$ZIP_NAME" ./* 
mv "$ZIP_NAME" "$work_dir/"
popd >/dev/null || exit

echo "[SCRIPT] - Cleaning up temporary output directories..."
rm -rf "$work_dir/out"

echo "[SCRIPT] - Build completed successfully!"
