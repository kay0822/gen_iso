#!/bin/bash
# ------ iso ------
#BASE_DIR="/home/kimi/3tos"
#ISO_DIR="/home/iso"
#BASE_ISO="${ISO_DIR}/CentOS-6.3-x86_64-bin-DVD1.iso"

ROM_DIR="${BASE_DIR}/ROM"

#-------- centos ------
CENTOS_DIR="${BASE_DIR}/centos"
INSTALL_LOG="${CENTOS_DIR}/install.log"
ANACONDA_KS_CFG="${CENTOS_DIR}/anaconda-ks.cfg"

#-------- build ----------
BUILD_DIR="${BASE_DIR}/build"
KS_CFG="${BUILD_DIR}/ks.cfg"
REPOMD_XML="${BUILD_DIR}/repodata/repomd.xml"
ISOLINUX_CFG_FILE="${BUILD_DIR}/isolinux/isolinux.cfg"
ISOLINUX_BIN_FILE="${BUILD_DIR}/isolinux/isolinux.bin"
BOOT_CAT_FILE="${BUILD_DIR}/isolinux/boot.cat"

#------- customize ----------
CUSTOMIZE_DIR="${BASE_DIR}/customize"
CUSTOMIZE_KS_POST="${CUSTOMIZE_DIR}/ks.post"
CUSTOMIZE_KS_PRE="${CUSTOMIZE_DIR}/ks.pre"
CUSTOMIZE_PACKAGES_DIR="${CUSTOMIZE_DIR}/Packages"
CUSTOMIZE_ISOLINUX_CFG_HEADER="${CUSTOMIZE_DIR}/isolinux.cfg.header"
CUSTOMIZE_ISOLINUX_CFG_KS="${CUSTOMIZE_DIR}/isolinux.cfg.ks"
CUSTOMIZE_ISOLINUX_CFG_FOOTER="${CUSTOMIZE_DIR}/isolinux.cfg.footer"

#-------- extra pkg ---------
EXTRA_PACKAGES='pexpect:pexpect*'

#-------- protocol ----------
CUSTOMIZE_PROTO_DIR="${CUSTOMIZE_DIR}/Proto"

#-------- output -----------
OUTPUT_DIR="${BASE_DIR}/output_iso"

#-------- protocol url -----
PROTO_RELEASE_SERVER="10.1.1.5"
PROTO_PACKAGE_RELEASE_DIR_URL="http://${PROTO_RELEASE_SERVER}/3tcloud/serverrelease"

#-------- destination --------
SED_REGEX_STRING='s/\//\\\//g'
LICENSE_DEST_DIR="/opt/3tcloud/server/bin"
LICENSE_DEST_DIR_REGEX=`echo ${LICENSE_DEST_DIR} |sed ${SED_REGEX_STRING}`
BIN_DIR="/usr/bin"
BIN_DIR_REGEX=`echo ${BIN_DIR} |sed ${SED_REGEX_STRING}`
PROTO_PYC_DIR="/opt/3tcloud/server/bin"
PROTO_PYC_DIR_REGEX=`echo ${PROTO_PYC_DIR} |sed ${SED_REGEX_STRING}`
PROTO_PYC_DIR_3TEV="/usr/bin"
PROTO_PYC_DIR_3TEV_REGEX=`echo ${PROTO_PYC_DIR} |sed ${SED_REGEX_STRING}`

#-------- rhevh ------------
EXT3FS_DIR="${BASE_DIR}/ext3fs"

SQUASHFS_IMG="${BUILD_DIR}/LiveOS/squashfs.img"
SQUASHFS_ROOT="${BUILD_DIR}/LiveOS/squashfs_root"
EXT3FS_IMG="${SQUASHFS_ROOT}/LiveOS/ext3fs.img"

CUSTOMIZE_RC_LOCAL="${CUSTOMIZE_DIR}/3tevh.rc.local"

function LOGGING(){
	echo -n "$1"
	shift 1
	printf "$@"
}
function INFO(){
	LOGGING "INFO: "  "$@"
}
function DEBUG(){
	if USE_DEBUG; then
		LOGGING "DEBUG: "  "$@"
	fi
}
function ERROR(){
	LOGGING "ERROR: "  "$@"
	exit 1
}


