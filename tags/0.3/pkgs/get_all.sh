#!/bin/sh

# Author:   Zhang Huangbin (michaelbibby <at> gmail.com)
# Date:     $LastChangedDate: 2008-03-02 21:11:40 +0800 (Sun, 02 Mar 2008) $
# Purpose:  Fetch all extra packages we need to build mail server.

FETCH_CMD='wget -c'

#
# Mirror site.
# Site directory structure:
#
#   ${MIRROR}/
#           |- rpms/
#               |- 5/
#               |- 6/ (not present yet)
#           |- misc/
#
# You can find nearest mirror in this page:
#   http://code.google.com/p/iredmail/wiki/Mirrors
#
MIRROR='http://www.iredmail.org/yum'

ROOTDIR="$(pwd)"
CONF_DIR="${ROOTDIR}/../conf"

. ${CONF_DIR}/global
. ${CONF_DIR}/functions

# Where to store packages and software source tarball.
PKG_DIR="${ROOTDIR}/rpms"
MISC_DIR="${ROOTDIR}/misc"

REPO_FILE="/etc/yum.repos.d/${LOCAL_REPO_NAME}.repo"

# RPM file list and misc file list.
RPMLIST="${ROOTDIR}/rpmlist.$(uname -i)"
NOARCHLIST="${ROOTDIR}/rpmlist.noarch"
MISCLIST="${ROOTDIR}/misclist"

MD5_FILES="MD5.$(uname -i) MD5.noarch MD5.misc"

prepare_dirs()
{
    for i in ${PKG_DIR} ${MISC_DIR}
    do
        [ -d "${i}" ] || mkdir -p "${i}"
    done
}

fetch_rpms()
{
    cd ${PKG_DIR}

    for i in $(cat ${RPMLIST} ${NOARCHLIST}); do
        ECHO_INFO "Fetching package: $(eval echo ${i})..."
        ${FETCH_CMD} ${MIRROR}/rpms/5/${i}
    done
}

fetch_misc()
{
    . ${CONF_DIR}/pypolicyd-spf
    . ${CONF_DIR}/squirrelmail
    . ${CONF_DIR}/phpldapadmin
    . ${CONF_DIR}/roundcube
    . ${CONF_DIR}/postfixadmin
    . ${CONF_DIR}/phpmyadmin
    . ${CONF_DIR}/extmail
    . ${CONF_DIR}/horde

    # Fetch all misc packages.
    cd ${MISC_DIR}

    misc_total=$(cat ${MISCLIST} | grep '^[a-z0-9A-Z\$]' | wc -l | awk '{print $1}')
    misc_count=1

    for i in $(cat ${MISCLIST} | grep '^[a-z0-9A-Z\$]' )
    do
        ECHO_INFO "Fetching (${misc_count}/${misc_total}): $(eval echo ${i})..."

        cd ${MISC_DIR}
        eval ${FETCH_CMD} ${MIRROR}/misc/${i}

        misc_count=$((misc_count + 1))
    done
}

check_md5()
{
    cd ${ROOTDIR}

    for i in ${MD5_FILES}; do
        ECHO_INFO -n "Checking MD5 via file: ${i}..."
        md5sum -c ${ROOTDIR}/${i} |grep 'FAILED'

        if [ X"$?" == X"0" ]; then
            echo -e "\n${OUTPUT_FLAG} MD5 check failed. Check your rpm packages. Script exit...\n"
            exit 255
        else
            echo -e "\t[ OK ]"
        fi
    done
}

create_yum_repo()
{
    which createrepo >/dev/null 2>&1

    if [ X"$?" != X"0" ]; then
        install_pkg createrepo.noarch
        [ X"$?" != X"0" ] && ECHO_INFO "Please install 'createrepo' first." && exit 255
    else
        :
    fi

    # createrepo
    ECHO_INFO -n "Generating yum repository..."
    cd ${ROOTDIR} && createrepo . >/dev/null 2>&1 && echo -e "\t[ OK ]"

    # Backup old repo file.
    [ -f ${REPO_FILE} ] && cp ${REPO_FILE} ${REPO_FILE}.${DATE}

    # Generate new repo file.
    cat > ${REPO_FILE} <<EOF
[${LOCAL_REPO_NAME}]
name=Yum repo generated by ${PROG_NAME}: http://${PROG_NAME}.googlecode.com/
baseurl=file://${ROOTDIR}
enabled=1
gpgcheck=0
EOF
}

check_user root && \
prepare_dirs && \
check_arch && \
fetch_rpms && \
fetch_misc && \
check_md5 && \
create_yum_repo && \
check_dialog && \
cat <<EOF

********************************************************
* All tasks had been finished Successfully. Next step:
*
*   # cd ..
*   # sh ${PROG_NAME}.sh
*
********************************************************

EOF
