#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

baserom="$1"
localbuild="$2"
work_dir=$(pwd)
tools_dir=${work_dir}/bin/$(uname)/$(uname -m)export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH
chmod 777 ${work_dir}/bin/*
chmod 777 ${work_dir}/bin/Linux/x86_64/*
source $work_dir/functions.sh
check unzip aria2c curl 7z zip java zipalign python3 zstd bc xmlstarlet aapt
source "$work_dir/bin/ddevice/getROM.sh" "$baserom"
BLOB="$work_dir/bin/package/UpdateFile/OOSExtenstionUni"

if unzip -l ${baserom} | grep -q "payload.bin"; then
    baserom_type="payload"
    echo "[UNPACK] - This is payload.bin ROM!Vaildation..."
    super_list="system system_ext product vendor odm my_product my_engineering my_stock my_carrier my_region my_bigball my_heytap my_manifest vendor_dlkm system_dlkm odm_dlkm system_ext_dlkm product_dlkm"
    echo "[UNPACK] - ROM validation passed."
else
    echo "[UNPACK] - Unpack failed"
    exit 1
fi

rm -rf app
rm -rf tmp
rm -rf config
rm -rf build/baserom/
rm -rf build/baserom/
find . -type d -name 'miui_*' | xargs rm -rf

echo "[SYSTEM] - Files cleaned up."
mkdir -p build/baserom/images/

echo "[UNPACK] - Extracting files from BASEROM [payload.bin]"
unzip ${baserom} payload.bin -d build/baserom >/dev/null 2>&1 || error "Extracting [payload.bin] error"
echo "[UNPACK] - [payload.bin] extracted."
echo "[UNPACK] - Unpacking BASEROM [payload.bin]"
payload-dumper-go -o build/baserom/images/ build/baserom/payload.bin >/dev/null 2>&1 || error "Unpacking [payload.bin] failed"        
for part in system system_ext product vendor odm my_product my_engineering my_stock my_carrier my_region my_bigball my_heytap my_manifest ;do
    extract_partition $work_dir/build/baserom/images/${part}.img $work_dir/build/baserom/images
    PACK_TYPE=$(cat $work_dir/bin/ddevice/fstype.txt)
done

# ==========================================
# KernelSU / Custom Kernel Injection
# ==========================================
echo "[MOD] - Fetching latest Kernel from JuanTamadski/Action-Build..."

TMP_KERNEL_DIR="$work_dir/tmp_kernel"
mkdir -p "$TMP_KERNEL_DIR"

# 1. Download the latest release asset using the GitHub CLI
# The --pattern flag ensures it only grabs the flashable zip or img
gh release download --repo "JuanTamadski/Action-Build" --pattern "*.zip" --dir "$TMP_KERNEL_DIR" || echo "[WARN] Failed to fetch kernel. Skipping."

# 2. Extract the downloaded zip (assuming it's an AnyKernel3 zip)
if ls "$TMP_KERNEL_DIR"/*.zip 1> /dev/null 2>&1; then
    echo "[MOD] - Extracting kernel zip..."
    unzip -q "$TMP_KERNEL_DIR"/*.zip -d "$TMP_KERNEL_DIR/extracted"
    
    # 3. Swap the kernel images into the ROM workspace
    # GKI 2.0 devices use init_boot for the ramdisk/root
    if [ -f "$TMP_KERNEL_DIR/extracted/init_boot.img" ]; then
        echo "[MOD] - Injecting custom init_boot.img (KernelSU/SUSFS)..."
        cp -f "$TMP_KERNEL_DIR/extracted/init_boot.img" "$work_dir/build/baserom/images/init_boot.img"
    fi
    
    # Always inject the main boot image if present
    if [ -f "$TMP_KERNEL_DIR/extracted/Image" ]; then
         # Note: If your kernel repo outputs a raw 'Image' file instead of a pre-patched boot.img, 
         # you would need an extra step here to repack it into the stock boot.img using magiskboot.
         # If it outputs a ready-to-flash boot.img, use this:
         cp -f "$TMP_KERNEL_DIR/extracted/boot.img" "$work_dir/build/baserom/images/boot.img" 2>/dev/null
    fi
else
    echo "[WARN] No kernel zip found in the release."
fi

# Clean up
rm -rf "$TMP_KERNEL_DIR"
# ==========================================

echo "[INFO] - Gathering Devices Infomations"
source $work_dir/bin/ddevice/fetchINFO.sh
bash $work_dir/bin/ddevice/modifyINFO.sh
main

rm -rf config
if [ -f $work_dir/${baserom}.zip ]; then
    rm -rf ${baserom}.zip
fi
rm -rf build/baserom/payload.bin
bash $work_dir/bin/package/install.sh
MY_STOCK="$work_dir/build/baserom/images/my_stock"

remove_fsv "$work_dir/build/baserom/images/system/system/framework"
remove_fsv "$work_dir/build/baserom/images/system_ext"

cp -rf $BLOB/feature_com.hma.otablock.xml $MY_STOCK/etc/extension


echo "[REPACK] - Packing partition..."
for pname in ${super_list}; do
    if [ -d "$work_dir/build/baserom/images/$pname" ]; then
        thisSize=$(du -sb $work_dir/build/baserom/images/${pname} | awk '{print $1}')
         case $pname in
             odm) addSize=134217728 ;;
             system) addSize=154217728 ;;
             vendor) addSize=154217728 ;;
             system_ext) addSize=154217728 ;;
             product) addSize=204217728 ;;
             *) addSize=8554432 ;;
         esac
        thisSize=$(echo "$thisSize + $addSize" | bc)
        if [[ "$PACK_TYPE" == "EXT" ]]; then
            echo -ne "[REPACK] - Packing [${pname}.img]:[$PACK_TYPE] with size [$thisSize] - " 
            python3 $work_dir/bin/fspatch.py $work_dir/build/baserom/images/${pname} $work_dir/build/baserom/images/config/${pname}_fs_config >/dev/null 2>&1
            python3 $work_dir/bin/contextpatch.py $work_dir/build/baserom/images/${pname} $work_dir/build/baserom/images/config/${pname}_file_contexts >/dev/null 2>&1
            make_ext4fs -J -T $(date +%s) -S $work_dir/build/baserom/images/config/${pname}_file_contexts -l $thisSize -C $work_dir/build/baserom/images/config/${pname}_fs_config -L ${pname} -a ${pname} $work_dir/build/baserom/images/${pname}.img $work_dir/build/baserom/images/${pname} >/dev/null 2>&1
            if [ -f "$work_dir/build/baserom/images/${pname}.img" ]; then
                echo "Success"
            else
                error "Failed"
            fi
        elif [[ "$PACK_TYPE" == "EROFS" ]]; then
            echo -ne "[REPACK] - Packing [${pname}.img]:[$PACK_TYPE] with size [$thisSize] - "
            python3 $work_dir/bin/fspatch.py $work_dir/build/baserom/images/${pname} $work_dir/build/baserom/images/config/${pname}_fs_config >/dev/null 2>&1
            python3 bin/contextpatch.py $work_dir/build/baserom/images/${pname} $work_dir/build/baserom/images/config/${pname}_file_contexts >/dev/null 2>&1
            mkfs.erofs --quiet -zlz4hc,9 --mount-point ${pname} --fs-config-file=$work_dir/build/baserom/images/config/${pname}_fs_config --file-contexts=$work_dir/build/baserom/images/config/${pname}_file_contexts $work_dir/build/baserom/images/${pname}.img $work_dir/build/baserom/images/${pname} >/dev/null 2>&1
            if [ -f "$work_dir/build/baserom/images/${pname}.img" ]; then
                echo "Success"
            else
                error "Failed"
            fi
        else
            error "[REPACK] - Unable to handle img, exit."
            exit 1
        fi
    fi
done

if [[ $localbuild = "y" ]]; then
    bash $work_dir/packROM.sh y
    cp -rf $work_dir/bin/default/script/* $work_dir/bin/script2flash/META-INF/Data/
    cp -rf $work_dir/bin/default/device/* $work_dir/bin/ddevice/
fi
