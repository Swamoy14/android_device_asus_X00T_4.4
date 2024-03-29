#!/bin/bash
#
# Copyright (C) 2020 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

DEVICE=X00T
VENDOR=asus

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true
SECTION=
KANG=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
    
    product/lib64/libdpmframework.so)
        "${PATCHELF}" --add-needed libdpmframework_shim.so "${2}"
        ;;

    # Load vndk 29 libprotobuf
    vendor/lib64/libwvhidl.so | vendor/lib64/libvendor.goodix.hardware.fingerprint@1.0-service.so)
        "${PATCHELF}" --replace-needed "libprotobuf-cpp-lite.so" "libprotobuf-cpp-lite-v29.so" "${2}"
        ;;

    vendor/lib64/libril-qc-hal-qmi.so | vendor/lib64/libsettings.so)
        "${PATCHELF}" --replace-needed "libprotobuf-cpp-full.so" "libprotobuf-cpp-full-v29.so" "${2}"
        ;;
        
    # Remove android.hidl.base dependency
    system/lib64/libwfdnative.so | system/lib/libwfdnative.so)
        "${PATCHELF}" --remove-needed "android.hidl.base@1.0.so" "${2}"
        ;;
        
    system/lib/libwfdaudioclient.so)
        "${PATCHELF}" --set-soname "libwfdaudioclient.so" "${2}"
        ;;

    system/lib/libwfdmediautils.so)
        "${PATCHELF}" --set-soname "libwfdmediautils.so" "${2}"
        ;;

    system/lib/libwfdmmsink.so)
        "${PATCHELF}" --add-needed "libwfdaudioclient.so" "${2}"
        "${PATCHELF}" --add-needed "libwfdmediautils.so" "${2}"
        ;;

    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
