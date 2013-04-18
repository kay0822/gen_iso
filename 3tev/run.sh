#!/bin/bash
BASE_DIR="/home/gen_iso/3tev"                     
ISO_DIR="/home/iso"
BASE_ISO="${ISO_DIR}/rhevh-6.3-20121025.0.iso"
. ${BASE_DIR}/config.sh

function  usage(){
    cat <<EOF
Usage: $0 -P version -S version [-h]
    -P version      Server [P]rotocal version           
    -v              Print [v]erbose information
    -h              Display this [h]elp usage
EOF
    exit 0
}
#PARAM_SERVER_PROTO_VERSION="1.4.1.3"
PARAM_SERVER_PROTO_VERSION=
PARAM_VERBOSE="/dev/null"
IS_v_SET=false
IS_P_SET=false
while getopts "hP:v" opt ; do
    case $opt in
        P)
            IS_P_SET=true
            PARAM_SERVER_PROTO_VERSION=${OPTARG}
        ;;
        v)
            IS_v_SET=true
            PARAM_VERBOSE="/dev/stdout"
        ;;
        h)
            usage
        ;;
		*)
			ERROR "Unknown option -> " $opt
		;;
    esac
done

if ! ( ${IS_P_SET} ) ; then
    usage
fi

###########
## Init  ##              
###########                                     
CURRENT_DATE=`date +%F_%H-%M-%S`

#############                                
##  Mount  ##                                      
#############                                  
umount -d ${ROM_DIR} 2>/dev/null               
umount -d ${ROM_DIR} 2>/dev/null
if [ ! -e "${ROM_DIR}" ];then           
    echo "Error: ${ROM_DIR} not exists!"
    exit -1                                 
fi                         
mount -o loop ${BASE_ISO} ${ROM_DIR}

mkdir -p ${BUILD_DIR}
rm -rf ${BUILD_DIR}/*


####################### 
##  Copy CD/DVD ROM  ## 
####################### 
COPY_COUNT=0
function doCopy(){                                                              
    __src=$1
    __dst=$2            
    cp -rf ${__src} ${__dst}
    COPY_COUNT=$(( ${COPY_COUNT}+1 )) 
#    if ${IS_v_SET} ;then    
        printf "%05d: %s\n>>>>>> %s\n"  ${COPY_COUNT}  ${__src}  ${__dst}
#    fi                      
}    

for package in `ls -a ${ROM_DIR} | grep -vE "^\.*$"`;do
	doCopy ${ROM_DIR}/${package}  ${BUILD_DIR}
done

##################
##  unsquashfs  ##
##################
unsquashfs -d ${SQUASHFS_ROOT} ${SQUASHFS_IMG}
umount -d ${EXT3FS_DIR} 2> /dev/null
umount -d ${EXT3FS_DIR} 2> /dev/null
if [ ! -e "${EXT3FS_DIR}" ];then 
    echo "Error: ${EXT3FS_DIR} not exists!"
    exit -1                             
fi 
mount -o loop,rw ${EXT3FS_IMG} ${EXT3FS_DIR}



#----- get protocol package ------
if [ ! -d ${CUSTOMIZE_PROTO_DIR}/${PARAM_SERVER_PROTO_VERSION} ];then
    TMP_PWD=`pwd`
    cd ${CUSTOMIZE_PROTO_DIR}
    rm -rf ${CUSTOMIZE_PROTO_DIR}/${PARAM_SERVER_PROTO_VERSION}*
    PROTO_PACKAGE_URL="${PROTO_PACKAGE_RELEASE_DIR_URL}/${PARAM_SERVER_PROTO_VERSION}.tbz2"
    PROTO_PACKAGE_MD5_URL="${PROTO_PACKAGE_RELEASE_DIR_URL}/${PARAM_SERVER_PROTO_VERSION}.tbz2.md5"

    FLAG=1
    while [ ${FLAG} -eq 1 ];do
        wget ${PROTO_PACKAGE_RELEASE_DIR_URL}/${PARAM_SERVER_PROTO_VERSION}.tbz2
        wget ${PROTO_PACKAGE_RELEASE_DIR_URL}/${PARAM_SERVER_PROTO_VERSION}.tbz2.md5
        X=`cat ${PARAM_SERVER_PROTO_VERSION}.tbz2.md5`
        Y=`md5sum ${PARAM_SERVER_PROTO_VERSION}.tbz2 | awk '{print $1}'`
        if [ "$X" == "$Y" ];then
            FLAG=0
        fi
    done
    tar jxvf ${PARAM_SERVER_PROTO_VERSION}.tbz2
    cd ${TMP_PWD}
fi

for package in `ls -a ${CUSTOMIZE_PROTO_DIR}/${PARAM_SERVER_PROTO_VERSION}  | grep -vE '^\.*$'`; do
	if [ "${package}" == "libspice-server.so.1.0.2.${PARAM_SERVER_PROTO_VERSION}" ];then
		doCopy ${CUSTOMIZE_PROTO_DIR}/${PARAM_SERVER_PROTO_VERSION}/${package}  ${EXT3FS_DIR}/usr/lib64/
		rm -rf ${EXT3FS_DIR}/usr/lib64/libspice-server.so.1.0.2
		ln -s libspice-server.so.1.0.2.${PARAM_SERVER_PROTO_VERSION} ${EXT3FS_DIR}/usr/lib64/libspice-server.so.1.0.2
	elif [[ "${package}" =~ .*\.pyc ]];then
		mkdir -p ${EXT3FS_DIR}${PROTO_PYC_DIR_3TEV}
		doCopy ${CUSTOMIZE_PROTO_DIR}/${PARAM_SERVER_PROTO_VERSION}/${package}  ${EXT3FS_DIR}${PROTO_PYC_DIR_3TEV}
	elif [ "${package}" == "characterGenerator" -o "${package}" == "customerLicenseRegister" -o "${package}" == "heartbeatmanager" ];then
		mkdir -p ${EXT3FS_DIR}${LICENSE_DEST_DIR_3TEV}
		doCopy ${CUSTOMIZE_PROTO_DIR}/${PARAM_SERVER_PROTO_VERSION}/${package}  ${EXT3FS_DIR}${LICENSE_DEST_DIR_3TEV}/
	elif [ ! "${package}" == "libheartbeat.so" -a ! "${package}" == "install.sh" ];then
		mkdir -p ${EXT3FS_DIR}${BIN_DIR}
		doCopy ${CUSTOMIZE_PROTO_DIR}/${PARAM_SERVER_PROTO_VERSION}/${package}  ${EXT3FS_DIR}${BIN_DIR}/
	fi
done

###########################
##  rc.local && selinux  ##
###########################
cat ${CUSTOMIZE_RC_LOCAL} | sed -e "s/{SERVER_PROTO_VERSION}/${PARAM_SERVER_PROTO_VERSION}/" 	\
								-e "s/{BIN_DIR}/${BIN_DIR_REGEX}/" 								\
								-e "s/{LICENSE_DEST_DIR_3TEV}/${LICENSE_DEST_DIR_3TEV_REGEX}/" 	\
								-e "s/{PROTO_PYC_DIR_3TEV}/${PROTO_PYC_DIR_3TEV_REGEX}/" >> ${EXT3FS_DIR}/etc/rc.local
TMP_SELINUX="/tmp/selinux.tmp"
cat ${EXT3FS_DIR}/etc/sysconfig/selinux | sed 's/SELINUX=enforcing/SELINUX=permissive/g' 	>  ${TMP_SELINUX}
cat ${TMP_SELINUX} 	>  ${EXT3FS_DIR}/etc/sysconfig/selinux


##################
##  mksquashfs  ##
##################
mkdir -p ${EXT3FS_BAK_DIR}
rm -rf ${EXT3FS_BAK_DIR}/*
cp -a ${EXT3FS_DIR}/* ${EXT3FS_BAK_DIR}/
sync
umount -d ${EXT3FS_DIR} 2>/dev/null
umount -d ${EXT3FS_DIR} 2>/dev/null
rm -f  ${SQUASHFS_IMG}
mksquashfs ${SQUASHFS_ROOT} ${SQUASHFS_IMG}
rm -rf ${SQUASHFS_ROOT} 
sync

###############
##  mkisofs  ##
###############
COUNT=`autoIncrease`
#output_name=`basename ${BASE_ISO} | awk -F- '{printf("%s",$1$2)}' ; echo "-${PARAM_SERVER_PROTO_VERSION}_${CURRENT_DATE}.iso"`
output_name=`basename ${BASE_ISO} | awk -F- '{printf("%s",$1$2)}' ; echo "-V${COUNT}-${PARAM_SERVER_PROTO_VERSION}_${CURRENT_DATE}.iso"`
image_label=`cat ${ISOLINUX_CFG_FILE} | grep -E "append.*initrd.*CDLABEL" |sed '2,$d' | sed 's/.*CDLABEL=//' |awk '{print $1}'`
mkisofs -V ${image_label} -o ${OUTPUT_DIR}/${output_name} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -R -J -v -T ${BUILD_DIR} > ${PARAM_VERBOSE} 2>&1
INFO "ISO -> %s\n" "${OUTPUT_DIR}/${output_name}"

##############
## CleanUp  ##
##############
umount -d ${ROM_DIR} 	2>/dev/null


