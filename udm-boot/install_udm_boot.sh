#!/bin/bash

#########################################################################################################
#                                                                                                       #
#  (RE)INSTALL UDM-BOOT PACKAGE ON UDM/UDR, in order to execute all /data/on-boot.d/ scripts at reboot  #
#      Use ubnt-dpkg-cache config file to re-install the pockage after a Unifi OS firmware update       #
#        Based on udm-boot-2x deb package from unifi-utilities GitHub repo, renamed as udm-boot         #
#                                                                                                       #
#########################################################################################################

green='\e[32m'; red='\e[31m'; clear='\e[0m'
colorGreen() { echo -ne $green$1$clear; }
colorRed() { echo -ne $red$1$clear; }

errExit() {
  >&2 echo "$(colorRed 'ERROR'): $1"
  exit 1
}

[ $(ubnt-device-info firmware | sed 's#\..*$##g' || true) -lt 2 ] && errExit "unsupported firmware, must be 2.x or more"

SERVICE_NAME="udm-boot"
PKG_VERSION="1.0.1"

ONBOOT_DEB="${SERVICE_NAME}_${PKG_VERSION}_all.deb"
DPKG_CACHE_CONF="/etc/default/ubnt-dpkg-cache"
OLD_SERVICE_NAME="udm-boot-2x"

echo "Adding package ${SERVICE_NAME} in ${DPKG_CACHE_CONF} ..."
export DPKG_LINE='DPKG_CACHE_UBNT_PKGS+=" '${SERVICE_NAME}'"'
grep -qxF "${DPKG_LINE}" ${DPKG_CACHE_CONF} || echo "${DPKG_LINE}" >>${DPKG_CACHE_CONF}
echo "--> $(colorGreen 'OK')"; echo

echo "Purging old package ${OLD_SERVICE_NAME} if still exist ..."
dpkg -P ${OLD_SERVICE_NAME} 2>/dev/null
echo "--> $(colorGreen 'OK')"; echo

echo "Installing ${ONBOOT_DEB} package..."
dpkg -i ${ONBOOT_DEB}
[ $? -ne 0 ] && errExit "dpkg -i command failed"
echo "--> $(colorGreen 'OK')"; echo

dpkg -s ${SERVICE_NAME} >/dev/null || errExit "something failed, package ${SERVICE_NAME} is not installed !!!!"
systemctl -q is-enabled ${SERVICE_NAME} || errExit "something failed, service ${SERVICE_NAME} is not enabled !!!!"

echo "===> Service ${SERVICE_NAME} $(colorGreen 'successfully installed'), see status below"
echo

systemctl status ${SERVICE_NAME} --no-pager
