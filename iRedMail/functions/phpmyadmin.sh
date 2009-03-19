#!/bin/sh

# Author: Zhang Huangbin <michaelbibby (at) gmail.com>

# -------------------------------------------------
# phpMyAdmin.
# -------------------------------------------------
phpmyadmin_install()
{
    cd ${MISC_DIR}

    extract_pkg ${PHPMYADMIN_TARBALL} ${HTTPD_SERVERROOT}

    ECHO_INFO "Set file permission for phpMyAdmin: ${PHPMYADMIN_HTTPD_ROOT}."
    chown -R root:root ${PHPMYADMIN_HTTPD_ROOT}
    chmod -R 0755 ${PHPMYADMIN_HTTPD_ROOT}

    # Create symbol link, so that we don't need to modify apache
    # conf.d/phpmyadmin.conf file after upgrade this component.
    ln -s ${PHPMYADMIN_HTTPD_ROOT} ${HTTPD_SERVERROOT}/phpmyadmin 2>/dev/null

    ECHO_INFO "Create directory alias for phpMyAdmin in Apache: ${HTTPD_CONF_DIR}/phpmyadmin.conf."
    cat > ${HTTPD_CONF_DIR}/phpmyadmin.conf <<EOF
${CONF_MSG}
#Alias /phpmyadmin "${HTTPD_SERVERROOT}/phpmyadmin/"
#Alias /mysql "${HTTPD_SERVERROOT}/phpmyadmin/"
<Directory "${PHPMYADMIN_HTTPD_ROOT}/">
    Options -Indexes
</Directory>
EOF

    # Make phpMyAdmin can be accessed via HTTPS only.
    sed -i 's#\(</VirtualHost>\)#Alias /phpmyadmin '${HTTPD_SERVERROOT}/phpmyadmin/'\n\1#' ${HTTPD_SSL_CONF}
    sed -i 's#\(</VirtualHost>\)#Alias /mysql '${HTTPD_SERVERROOT}/phpmyadmin/'\n\1#' ${HTTPD_SSL_CONF}

    ECHO_INFO "Config phpMyAdmin: ${PHPMYADMIN_CONFIG_FILE}."
    cd ${PHPMYADMIN_HTTPD_ROOT} && cp config.sample.inc.php ${PHPMYADMIN_CONFIG_FILE}

    export COOKIE_STRING="$(${RANDOM_STRING})"
    perl -pi -e 's#(.*blowfish_secret.*= )(.*)#${1}"$ENV{'COOKIE_STRING'}"; //${2}#' ${PHPMYADMIN_CONFIG_FILE}
    perl -pi -e 's#(.*Servers.*host.*=.*)localhost(.*)#${1}$ENV{'MYSQL_SERVER'}${2}#' ${PHPMYADMIN_CONFIG_FILE}

    if [ X"${MYSQL_SERVER}" == X"localhost" ]; then
        # Use unix socket.
        perl -pi -e 's#(.*Servers.*connect_type.*=).*#${1}"socket";#' ${PHPMYADMIN_CONFIG_FILE}
    else
        # Use TCP/IP.
        perl -pi -e 's#(.*Servers.*connect_type.*=).*#${1}"tcp";#' ${PHPMYADMIN_CONFIG_FILE}
    fi

    cat >> ${TIP_FILE} <<EOF
phpMyAdmin:
    * Configuration files:
        - ${PHPMYADMIN_HTTPD_ROOT}
        - ${PHPMYADMIN_CONFIG_FILE}
    * URL:
        - https://${HOSTNAME}/phpmyadmin
    * See also:
        - ${HTTPD_CONF_DIR}/phpmyadmin.conf

EOF

    echo 'export status_phpmyadmin_install="DONE"' >> ${STATUS_FILE}
}
