#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys  # Moved to the top to fix scope issues
from difflib import SequenceMatcher
from typing import Generator, Any
from re import escape, match

fix_permission = {
    r"/system_ext/lost\+found": "u:object_r:system_file:s0",
    r"/product/lost\+found": "u:object_r:system_file:s0",
    r"/mi_ext/lost\+found": "u:object_r:system_file:s0",
    r"/odm/lost\+found": "u:object_r:vendor_file:s0",
    r"/vendor/lost\+found": "u:object_r:vendor_file:s0",
    r"/vendor_dlkm/lost\+found": "u:object_r:vendor_file:s0",
    r"/system/lost\+found": "u:object_r:rootfs:s0",
    r"/lost\+found": "u:object_r:rootfs:s0",
    "/mi_ext/product/lib*": "u:object_r:system_lib_file:s0",
    "/system/system/app/*": "u:object_r:system_file:s0",
    "/system/system/priv-app/*": "u:object_r:system_file:s0",
    "/system/system/lib*": "u:object_r:system_lib_file:s0",
    "/system/system/bin/apexd": "u:object_r:apexd_exec:s0",
    "/system/system/bin/init": "u:object_r:init_exec:s0",
    "system_ext/lib*": "u:object_r:system_lib_file:s0",
    "/product/lib*": "u:object_r:system_lib_file:s0",
    "/odm/app/*": "u:object_r:vendor_app_file:s0",
    "/odm/etc*": "u:object_r:vendor_configs_file:s0",
    "/vendor/apex*": "u:object_r:vendor_apex_file:s0",
    "/vendor/app/*": "u:object_r:vendor_app_file:s0",
    "/vendor/priv-app/*": "u:object_r:vendor_app_file:s0",
    "/vendor/etc*": "u:object_r:vendor_configs_file:s0",
    "/vendor/firmware*": "u:object_r:vendor_firmware_file:s0",
    "/vendor/framework*": "u:object_r:vendor_framework_file:s0",
    "*/hw/android.hardware.audio*": "u:object_r:hal_audio_default_exec:s0",
    "*/hw/android.hardware.bluetooth*": "u:object_r:hal_bluetooth_default_exec:s0",
    "*/hw/android.hardware.boot*": "u:object_r:hal_bootctl_default_exec:s0",
    "*/hw/android.hardware.power*": "u:object_r:hal_power_default_exec:s0",
    "*/hw/android.hardware.wifi*": "u:object_r:hal_wifi_default_exec:s0",
    "*/bin/idmap": "u:object_r:idmap_exec:s0",
    "*/bin/fsck": "u:object_r:fsck_exec:s0",
    "*/bin/e2fsck": "u:object_r:fsck_exec:s0",
    "*/bin/logcat": "u:object_r:logcat_exec:s0",
    "*/bin/audioserver": "u:object_r:audioserver_exec:s0",
    "*/vendor/data/model/*": "u:object_r:vendor_file:s0", # FIXED: Removed leading colon
}


def scan_context(file) -> dict:
    context = {}
    with open(file, "r", encoding="utf-8") as file_:
        for i in file_.readlines():
            if not i.strip() or i.startswith("#"):
                continue
            filepath, *other = i.strip().split()
            filepath = filepath.replace(r"\@", "@")
            context[filepath] = other
            if len(other) > 1:
                print(f"[Warn] {filepath} has too much data. Skip.")
                del context[filepath]
    return context


def scan_dir(folder) -> Generator[Any, Any, Any]:
    part_name = os.path.basename(folder)
    allfiles = [
        "/",
        "/lost+found",
        f"/{part_name}",
        f"/{part_name}/",
        f"/{part_name}/lost+found",
    ]
    for root, dirs, files in os.walk(folder, topdown=True):
        for dir_ in dirs:
            yield os.path.join(root, dir_).replace(folder, "/" + part_name).replace("\\", "/")
        for file in files:
            yield os.path.join(root, file).replace(folder, "/" + part_name).replace("\\", "/")
        for rv in allfiles:
            yield rv


def str_to_selinux(string: str):
    return escape(string).replace("\\-", "-")


def context_patch(fs_file, dir_path) -> tuple:
    new_fs = {}
    r_new_fs = {}
    add_new = 0
    print("ContextPatcher: Load origin %d entries" % (len(fs_file.keys())))
    
    # Context fallbacks optimized for OPlus structures
    if dir_path.endswith("system_dlkm"):
        permission_d = ["u:object_r:system_dlkm_file:s0"]
    elif dir_path.endswith(("odm", "vendor", "vendor_dlkm")):
        permission_d = ["u:object_r:vendor_file:s0"]
    else:
        permission_d = ["u:object_r:system_file:s0"]

    for i in scan_dir(os.path.abspath(dir_path)):
        if not i.isprintable():
            tmp = ""
            for c in i:
                tmp += c if c.isprintable() else "*"
            i = tmp
        if " " in i:
            i = i.replace(" ", "*")
        i = str_to_selinux(i)
        if fs_file.get(i):
            new_fs[i] = fs_file[i]
        else:
            permission = None
            if r_new_fs.get(i):
                continue
            if i:
                for f in fix_permission.keys():
                    pattern = f.replace("*", ".*")
                    if i == pattern or match(pattern, i):
                        permission = [fix_permission[f]]
                        break
                if not permission:
                    for e in fs_file.keys():
                        if SequenceMatcher(None, os.path.dirname(i), e).quick_ratio() >= 0.8:
                            if e == os.path.dirname(i):
                                continue
                            permission = fs_file[e]
                            break
                if not permission:
                    permission = permission_d
            
            # FIXED: Handle string cleaning carefully context lists
            permission = [p.replace(" ", "") for p in permission]
            
            print(f"Add {i} {permission}")
            add_new += 1
            r_new_fs[i] = permission
            new_fs[i] = permission
    return new_fs, add_new


def main(dir_path, fs_config) -> None:
    new_fs, add_new = context_patch(scan_context(os.path.abspath(fs_config)), dir_path)
    with open(fs_config, "w+", encoding="utf-8", newline="\n") as f:
        f.writelines([i + " " + " ".join(new_fs[i]) + "\n" for i in sorted(new_fs.keys())])
    print("ContextPatcher: Add %d entries" % add_new)


def Usage():
    print("Usage:")
    print("%s <folder> <fs_config>" % (sys.argv[0]))
    print("    This script will auto patch file_context")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        Usage()
        sys.exit()
    if os.path.isdir(sys.argv[1]) or os.path.isfile(sys.argv[2]):
        main(sys.argv[1], sys.argv[2])
        print("Done!")
    else:
        print("The path or filetype you have given may be wrong, please check it.")
        Usage()
