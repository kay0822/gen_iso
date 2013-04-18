#!/bin/bash
BASE_DIR="/home/gen_iso/3tos"
ISO_DIR="/home/iso"
BASE_ISO="${ISO_DIR}/CentOS-6.3-x86_64-bin-DVD1.iso"
USE_DEBUG=true
. ${BASE_DIR}/config.sh

function  usage(){
    cat <<EOF
Usage: $0 -P version -S version [options]
    -P, --protocol version      Server [P]rotocal version           
    -S, --server   version      [S]erver(python.tar.gz) version
[options]:
    -v, --verbose               Print [v]erbose information
    -h, --help                  Display this [h]elp usage
    --skip-copy                 skip coping packages, better to use --skip-cp-a-repo 
    --skip-repo                 skip create reposite, better to use --skip-cp-a-repo
    --skip-cp-a-repo            combine --skip-copy and --skip-repo
    --skip-partition            skip the partitioning during kick-start installation
EOF
    exit 0
}
#PARAM_SERVER_PROTO_VERSION="1.4.1.3"
PARAM_SERVER_PROTO_VERSION=
#PARAM_PYTHON_SERVER_VERSION="1.3.1"
PARAM_PYTHON_SERVER_VERSION=
PARAM_VERBOSE="/dev/null"
PARAM_SKIP_PARTITIONING="\1"
PARAM_PARTITION_LABEL=
PARAM_SKIP_COPY=false
PARAM_SKIP_REPO=false
IS_v_SET=false
IS_P_SET=false
IS_S_SET=false

args=`getopt -a -o P:S:v -l protocol:,server:,skip-partition,skip-copy,skip-repo,skip-cp-a-repo,help -- "$@"`
eval set -- "$args"
while true; do
	case $1 in
		-P|--protocol)
			IS_P_SET=true
			PARAM_SERVER_PROTO_VERSION=$2
			if ! [[ "${PARAM_SERVER_PROTO_VERSION}" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]];then
				ERROR "protocol version invalid, example: 1.4.1.3\n"
			fi
			shift
		;;
		-S|--server)
			IS_S_SET=true
			PARAM_PYTHON_SERVER_VERSION=$2
			if ! [[ "${PARAM_PYTHON_SERVER_VERSION}" =~ [0-9]+\.[0-9]+\.[0-9]+ ]];then
				ERROR "server version invalid, example: 1.3.1\n"
			fi
			shift
		;;
		-v|--verbose)
			IS_v_SET=true
			PARAM_VERBOSE="/dev/stdout"
		;;
		-h|--help)
			usage
		;;
		--skip-copy)
			PARAM_SKIP_COPY=true
		;;
		--skip-repo)
			PARAM_SKIP_REPO=true
		;;
		--skip-cp-a-repo)
			PARAM_SKIP_COPY=true
			PARAM_SKIP_REPO=true
		;;
		--skip-partition)
			PARAM_SKIP_PARTITIONING="clearpart --all\nautopart"
			PARAM_PARTITION_LABEL="-skip-partition"
		;;
		--)
			shift
			break
		;;
	esac
	shift
done

if ! ( ${IS_P_SET} && ${IS_S_SET} ) ; then
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

if ${PARAM_SKIP_COPY};then
	INFO "remove skipped\n"
else
	rm -rf ${BUILD_DIR}/*
fi

########################
##  Generate Configs  ##
########################
INFO "generate configure files\n"
TMP_PACKAGE_LIST="/tmp/packages.list.tmp"
TMP_KS_CFG="/tmp/ks.cfg.tmp"
awk -F "Installing" '{print $2}'  ${INSTALL_LOG} |sed -e '/^$/d' -e 's/^ //g' > ${TMP_PACKAGE_LIST}
cat ${CUSTOMIZE_KS_POST} 			>  ${TMP_KS_CFG}

#----- generate ------
cat ${ANACONDA_KS_CFG} | sed -e 's/--onboot.*--bootproto/--onboot yes --bootproto/' \
							 -e 's/^selinux --enforcing/selinux --permissive/'      \
							 -e 's/^repo.*--baseurl=cdrom.*//'                      \
							 -e "s/\(^#clearpart .*\)/${PARAM_SKIP_PARTITIONING}/"      \
							 -e 's/^%end$//'									>  ${KS_CFG}
echo "# extra packages "														>> ${KS_CFG}
for item in ${EXTRA_PACKAGES}; do
	echo ${item} | awk -F':' '{print $1}'										>> ${KS_CFG}
done
echo -e "\n\n\n"																>> ${KS_CFG}
cat ${TMP_KS_CFG} | sed -e "s/{SERVER_PROTO_VERSION}/${PARAM_SERVER_PROTO_VERSION}/" \
						-e "s/{LICENSE_DEST_DIR}/${LICENSE_DEST_DIR_REGEX}/"		 \
						-e "s/{PROTO_PYC_DIR}/${PROTO_PYC_DIR_REGEX}/"				 \
						-e "s/{BIN_DIR}/${BIN_REGEX}/"							>> ${KS_CFG}
echo "%end"																		>> ${KS_CFG}


#######################
##  Copy CD/DVD ROM  ##
#######################
COPY_COUNT=0
function doCopy(){
	__src=$1
	__dst=$2
	cp -rf ${__src} ${__dst}
	COPY_COUNT=$(( ${COPY_COUNT}+1 ))
	if ${IS_v_SET} ;then
		printf "%05d: %s\n>>>>>> %s\n"  ${COPY_COUNT}  ${__src}  ${__dst}
	fi
}
#export -f doCopy
if ${PARAM_SKIP_COPY};then
	INFO "copy skipped\n"
else

INFO "coping files\n"
ls -a ${ROM_DIR} | grep -vE '^\.*$|^Packages$'|xargs -n 1 -I {} cp -rf ${ROM_DIR}/{}  ${BUILD_DIR}/
mkdir -p ${BUILD_DIR}/Packages
for package in `cat ${TMP_PACKAGE_LIST}`;do
	echo >/dev/null
	doCopy ${ROM_DIR}/Packages/${package}*  ${BUILD_DIR}/Packages/
done
for package in `ls -a ${CUSTOMIZE_PACKAGES_DIR}  | grep -vE '^\.*$'`; do
	doCopy  ${CUSTOMIZE_PACKAGES_DIR}/${package} ${BUILD_DIR}/Packages/
done

INFO "copy extra package\n"
for item in ${EXTRA_PACKAGES}; do
	pkgs=`echo ${item} | awk -F':' '{print $2}'| awk -F'|' '
		{
			for(i=1; i<=NF; i++){
				printf("%s ", $i);
			}
		}
	'`
	for pkg in ${pkgs}; do
		doCopy  ${ROM_DIR}/Packages/${pkg}  ${BUILD_DIR}/Packages/	
	done
done

INFO "copy protocol package\n"
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
	doCopy  ${CUSTOMIZE_PROTO_DIR}/${PARAM_SERVER_PROTO_VERSION}/${package} ${BUILD_DIR}/Packages/
done

fi # /* DO_COPY */


############
##  Repo  ##
############
if ${PARAM_SKIP_REPO}; then
	INFO "create repo skipped\n"
else
INFO "create repo\n"
TMP_REPOMD_XML="/tmp/repomd.xml.tmp"
TMP_REPO_GROUP_XML="/tmp/repo.group.xml.tmp"
cat ${REPOMD_XML} |awk '
		BEGIN{
			FLAG=0
		}
		{
			if(/<data.*type=.*group/){
				FLAG=1
			} 
			if(FLAG){
				print
			}  
		}'								> ${TMP_REPO_GROUP_XML}

createrepo -p -d --unique-md-filenames  ${BUILD_DIR}/	> ${PARAM_VERBOSE}
#--- generate ---
cat ${REPOMD_XML} | sed '/<\/repomd>/d'	>  ${TMP_REPOMD_XML}
cat ${TMP_REPO_GROUP_XML}				>> ${TMP_REPOMD_XML}
cat ${TMP_REPOMD_XML} > ${REPOMD_XML}
fi


####################
##  isolinux.cfg  ##
####################
TMP_ISOLINUX_CFG_FILE="/tmp/isolinux.cfg.tmp"
cat ${CUSTOMIZE_ISOLINUX_CFG_HEADER}	>  ${TMP_ISOLINUX_CFG_FILE}
cat ${ISOLINUX_CFG_FILE} | sed '1d'		>> ${TMP_ISOLINUX_CFG_FILE}
cat ${CUSTOMIZE_ISOLINUX_CFG_KS}    	>> ${TMP_ISOLINUX_CFG_FILE}
cat ${CUSTOMIZE_ISOLINUX_CFG_FOOTER}    >> ${TMP_ISOLINUX_CFG_FILE}
cat ${TMP_ISOLINUX_CFG_FILE}	>  ${ISOLINUX_CFG_FILE}


###############
##  mkisofs  ##
###############
INFO "generate iso\n"
COUNT=`autoIncrease`
#CENTOS_VERSION=`cd ${CENTOS_DIR} ; basename \`pwd -P\` `
#image_label="${CENTOS_VERSION}-${PARAM_PYTHON_SERVER_VERSION}-${PARAM_SERVER_PROTO_VERSION}_${CURRENT_DATE}"
#image_label=`basename ${BASE_ISO} | awk -F- '{printf("3tos%s",$2)}' ;echo "-${COUNT}-${CURRENT_DATE}"`
#output_name=`basename ${BASE_ISO} | awk -F- '{printf("%s",$1$2)}'   ;echo "-${PARAM_PYTHON_SERVER_VERSION}-${PARAM_SERVER_PROTO_VERSION}_${CURRENT_DATE}${PARAM_PARTITION_LABEL}.iso"`
image_label=`basename ${BASE_ISO} | awk -F- '{printf("3tos%s",$2)}' ;echo "-V${COUNT}-${CURRENT_DATE}"`
output_name=`basename ${BASE_ISO} | awk -F- '{printf("%s",$1$2)}'   ;echo "-${PARAM_PYTHON_SERVER_VERSION}-${PARAM_SERVER_PROTO_VERSION}_V${COUNT}-${PARAM_PARTITION_LABEL}.iso"`

cd ${BUILD_DIR}
mkisofs -V ${image_label} -o ${OUTPUT_DIR}/${output_name} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -R -J -v -T ${BUILD_DIR}  > ${PARAM_VERBOSE} 2>&1
INFO "ISO -> %s\n" "${OUTPUT_DIR}/${output_name}"

###############
##  CleanUp  ##
###############
rm -f ${TMP_KS_CFG}  ${TMP_PACKAGE_LIST}  ${TMP_REPOMD_XML}  ${TMP_REPO_GROUP_XML}  ${TMP_ISOLINUX_CFG_FILE}
umount -d ${ROM_DIR} 2>/dev/null

