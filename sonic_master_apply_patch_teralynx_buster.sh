#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for compilation


#
# patch script for SONiC Teralynx master builds
#

#
# CONFIGURATIONS:-
#

SONIC_COMMIT="05e51f4b8a04e7457397aa1d066237062cad10f9"

#
# END of CONFIGURATIONS
#

# PREDEFINED VALUES
CUR_DIR=$(basename `pwd`)
LOG_FILE=patches_result.log
FULL_PATH=`pwd`

# Path for 202211 patches
WGET_PATH="https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/master-bookworm/"

# Patches
SERIES="0001-Add-SDK-dependent-python-packages.patch
	0002-Add-Marvell-platform-support-for-dbmvt9180.patch
        0003-marvell-teralynx-master-cel-wistron-platform-files.patch"

PATCHES=""

# Sub module patches
declare -a SUB_PATCHES=(SP1)
declare -A SP1=([NAME]="0001-Marvell-teralynx-generate_dump.patch" [DIR]="src/sonic-utilities")

log()
{
    echo $@
    echo $@ >> ${FULL_PATH}/${LOG_FILE}
}

pre_patch_help()
{
    log "STEPS TO BUILD:"
    log "git clone https://github.com/sonic-net/sonic-buildimage.git"
    log "cd sonic-buildimage"
    log "git checkout $SONIC_COMMIT"
    log "make init"

    log "<<Apply patches using patch script>>"
    log "bash $0"

    log "<<FOR INTEL>> make configure PLATFORM=innovium"
    log "make target/sonic-innovium.bin"
}

apply_patch_series()
{
    for patch in $SERIES
    do
        echo $patch
        pushd patches
        wget -c --timeout=2 $WGET_PATH/$patch
        popd
        git am patches/$patch
        if [ $? -ne 0 ]; then
            log "ERROR: Failed to apply patch $patch"
            exit 1
        fi
    done
}

apply_patches()
{
    for patch in $PATCHES
    do
	echo $patch
    	pushd patches
    	wget -c --timeout=2 $WGET_PATH/$patch
        popd
	    patch -p1 < patches/$patch
        if [ $? -ne 0 ]; then
	        log "ERROR: Failed to apply patch $patch"
            exit 1
    	fi
    done
}

apply_submodule_patches()
{
    CWD=`pwd`
    for SP in ${SUB_PATCHES[*]}
    do
	patch=${SP}[NAME]
	dir=${SP}[DIR]
	echo "${!patch}"
    	pushd patches
    	wget -c --timeout=2 $WGET_PATH/${!patch}
        popd
	    pushd ${!dir}
        git am $CWD/patches/${!patch}
        if [ $? -ne 0 ]; then
	        log "ERROR: Failed to apply patch ${!patch}"
            exit 1
    	fi
	popd
    done
}

apply_hwsku_changes()
{
    # Download hwsku and platform files for celestica and wistron for teralynx7
    wget -c --timeout=2 https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/mrvl_sonic_master_hwsku_tl7.tgz

    rm -fr device/celestica/x86_64-cel_midstone-r0 || true
    rm -fr device/wistron || true
    tar -C device/ -xzf mrvl_sonic_master_hwsku_tl7.tgz
}

main()
{
    sonic_buildimage_commit=`git rev-parse HEAD`
    if [ "$CUR_DIR" != "sonic-buildimage" ]; then
        log "ERROR: Need to be at sonic-builimage git clone path"
        pre_patch_help
        exit
    fi

    if [ "${sonic_buildimage_commit}" != "$SONIC_COMMIT" ]; then
        log "Checkout sonic-buildimage commit to proceed"
        log "git checkout ${SONIC_COMMIT}"
        pre_patch_help
        exit
    fi

    date > ${FULL_PATH}/${LOG_FILE}
    [ -d patches ] || mkdir patches

    # Apply patch series
    apply_patch_series
    # Apply  submodule init mainly for sonic-platform-marvell submodule for TL10
    git submodule update --init
    # Apply patches
    apply_patches
    # Apply submodule patches
    apply_submodule_patches
    # Apply hwsku changes
    apply_hwsku_changes
}

main $@
