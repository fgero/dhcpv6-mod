#!/bin/bash
########################################################################
#
# INSTALL OR UPDATE DHCPV6-MOD (can be run at any time)
# This script will replace Unifi's executable /usr/sbin/odhcp6c
# by /data/dhcpv6-mod/odhcp6c.sh (and save odhcp6c as odhcp6c-org before)
# Then it will restart both udhcpc and odhcp6c (restart discover process)
# without interrupting the WAN connection (if dhcpv6.conf is valid)
# It will only do that if needed (i.e. odhcp6c outdated vs dhcp6c-mod)
# So this script can be executed at any time, at initial install
# as well as for any update (e.g. from dhcpv6-mod repo)
#
########################################################################

DHCP6C_PATH="/usr/sbin/odhcp6c"                # Unifi's binary path for DHCPv6 client

DHCPV6_CONF="/data/local/etc/dhcpv6.conf"     # Config file for DHCPv6 client options

###########################################################
#                    MESSAGE UTILITIES                    #
###########################################################

green='\E[32m'; red='\E[31m'; yellow='\E[33m'; clear='\E[0m'
colorGreen() { printf "$green$1$clear"; }
colorRed() { printf "$red$1$clear"; }
colorYellow() { printf "$yellow$1$clear"; }

errExit() {
  >&2 echo "$HDR $(colorRed 'ERROR:') $1"
  exit 1
}

###########################################################
#                        FUNCTIONS                        #
###########################################################

get_elaps_of_process() {
    process_age=$(ps -o etimes= -C $1)
    [[ -z "${process_age}" ]] && process_age="ERROR"
    printf "%s" ${process_age}
}

get_elaps_of_file() {
    if [[ -f "$1" ]]; then
        epoch_file=$(date -r "$1" +%s)
        epoch_now=$(date +%s)
        printf "%s" $((${epoch_now} - ${epoch_file}))
    else
        printf "ERROR"
    fi
}

prettyAge() {
    echo $1 | awk '{ a=$1;
        if (a>=86400) printf "%dd",int(a/86400); a=a%86400;
        if (a>=3600) printf "%02dh",int(a/3600); a=a%3600;
        if (a>=60) printf "%02dm",int(a/60); a=a%60; printf "%02ds",a
    }'
}

###########################################################
#                    INITIALIZATIONS                      #
###########################################################

SCRIPT_DIR=$(dirname "$0")
HDR="[install-dhcpv6-mod]"  # header set in all messages

need_update=0    # assume update of binary not needed
need_refresh=0   # assume refresh of dhcpc running process not needed
force_update=0   # force overwrite of existing /usr/sbin/odhcp6c in any case

[[ "$1" = "--force" ]] && force_update=1 || force_update=0

read OS_V OS_R OS_M <<<$(mca-cli-op info|grep ^Version:|awk '{print $2}'| awk -F. '{print $1,$2,$3}')
[[ $OS_V -lt 3 || $OS_V -eq 3 && $OS_R -lt 2 || $OS_V -eq 3 && $OS_R -eq 2 && OS_M -lt 9 ]] && \
    errExit "You need to be at least in Unifi OS 3.2.9 to install dhcpv6-mod, sorry."

bin_name=$(basename ${DHCP6C_PATH})
mod_script="${SCRIPT_DIR}/${bin_name}.sh"

# Avoids wget fw-download.ubnt.com IPv6 endpoints unreachable
grep -sq '^prefer-family' /root/.wgetrc || echo 'prefer-family = IPv4' >> /root/.wgetrc

# Creates default dhcpv6.conf if does not exist (default : Orange DHCP V6 conf)
if [[ ! -f "${DHCPV6_CONF}" ]]; then
    mkdir -p $(dirname ${DHCPV6_CONF})
    cp -p ${SCRIPT_DIR}/dhcpv6-orange.conf ${DHCPV6_CONF}
    [[ $? -ne 0 ]] && errExit "Unable to copy default Orange conf to ${DHCPV6_CONF}" 
    echo "$HDR copied dhcpv6-orange.conf default config to ${DHCPV6_CONF}"
fi

if readelf -h ${DHCP6C_PATH} &>/dev/null; then # if odhcp6c is a binary exec, then it's a first install

    #################################################
    #  FIRST INSTALL (OR AFTER AN UNIFI OS UPDATE)  #
    #################################################

    # If there's a WAN IPv6 PD active, perhaps we don't need dhcpv6-mod
    v6_if_json=$(ubios-udapi-client GET -r /interfaces | jq -r '.[] | select(.ipv6.dhcp6PDStatus[0].network and .status.comment=="WAN")')
    if [[ -n "$v6_if_json" ]]; then
        v6_if=$(echo $v6_if_json | jq -r '.identification.id')
        v6_pd=$(echo $v6_if_json | jq -r '.ipv6.dhcp6PDStatus[0].network')
        if [[ "$v6_pd" =~ ^([0-9a-fA-F]{0,4}:){2,7}(/([0-9]{1,3}))$ ]]; then
            echo "$HDR $(colorYellow 'WARNING:') found a WAN interface $(colorGreen $v6_if) having an active IPv6 prefix delegation $(colorGreen $v6_pd)"
            echo "$HDR This could mean that your IPv6 WAN already works without dhcpv6-mod installed"
            read -p "$HDR Do you really want to install dhcpv6-mod [y/N] : " confirm_anyway
            case "$confirm_anyway" in
                y|Y|yes|YES) echo "$HDR OK, installing dhcpv6-mod despite having already a IPv6 PD...";;
                n|Y|no|NO|"") echo "$HDR Installation canceled, as requested"; exit 1;;
                *) echo "$HDR invalid response, installation canceled"; exit 1;;
            esac
        fi
    fi

    # Just to be sure, test if odhcp6c binary is OK before renaming it
    ${DHCP6C_PATH} -h 2>&1 | grep -q '\-K ' 
    [[ $? -ne 0 ]] && errExit "${DHCP6C_PATH} doesn't have the -K option, that is unexpected"
    echo "$HDR ${DHCP6C_PATH} detected as an original Unifi executable, we can rename it"
    # Rename odhcp6c as odhcp6c-org so that our script will take it's place (and call it)
    mv ${DHCP6C_PATH} ${DHCP6C_PATH}-org
    [[ $? -ne 0 ]] && errExit "Unable to rename ${DHCP6C_PATH} to ${DHCP6C_PATH}-org" 
    echo "$HDR "$(colorGreen "${DHCP6C_PATH} renamed ${DHCP6C_PATH}-org")
    need_update=1   # update = we will copy our script in place of the odhcp6c binary

elif readelf -h ${DHCP6C_PATH}-org &>/dev/null; then  # Not a first install

    ###################################################
    # NOT A FIRST INSTALL : UPDATE/REFRESH NEEDED ?   #
    ###################################################

    # Just to be sure, test if odhcp6c original binary is OK before renaming it
    ${DHCP6C_PATH}-org -h 2>&1 | grep -q '\-K ' 
    [[ $? -ne 0 ]] && errExit "${DHCP6C_PATH}-org doesn't have the -K option, that is unexpected"
    echo "$HDR ${DHCP6C_PATH}-org detected as an original Unifi executable, this is not a first install"

    dhcpv6_process=${bin_name}-org
    process_age=$(get_elaps_of_process "${dhcpv6_process}")   # can be ERROR if not started (V6 inact or KO)
    sbin_file_age=$(get_elaps_of_file "${DHCP6C_PATH}")       # cannot be ERROR, either Unifi or ours
    mod_script_age=$(get_elaps_of_file "${mod_script}")       # cannot be ERROR, this is our repository
    dhcpv6_conf_age=$(get_elaps_of_file "${DHCPV6_CONF}")     # cannot be ERROR, we just copied it if inex

    if [[ "${process_age}" == "ERROR" ]]; then
        echo "$HDR No runnning ${dhcpv6_process} process found : we'll assume ${DHCP6C_PATH} needs an update"
        need_update=1
    elif [[ $process_age -gt $mod_script_age ]]; then
        echo "$HDR ${dhcpv6_process} process ($(prettyAge ${process_age})) is older than ${mod_script} file ($(prettyAge ${mod_script_age}))"
        need_update=1
    elif [[ $process_age -gt $dhcpv6_conf_age ]]; then
        echo "$HDR ${dhcpv6_process} process ($(prettyAge ${process_age})) is older than dhcpv6.conf file ($(prettyAge ${dhcpv6_conf_age}))"
        need_refresh=1
    fi

    if [[ $sbin_file_age -gt $mod_script_age ]]; then
        echo "$HDR ${DHCP6C_PATH} ($(prettyAge ${sbin_file_age})) is older than ${mod_script} ($(prettyAge ${mod_script_age}))"
        need_update=1
    fi

    if [[ $force_update -eq 1 && $need_update -eq 0 ]]; then
        echo "$HDR $(colorYellow 'NOTE:') no need to update binary or config, but you used --force so we will to that anyway"
        need_update=1
    fi

else errExit "neither ${DHCP6C_PATH} nor ${DHCP6C_PATH}-org are executable binaries, this is NOT expected"

fi

###########################################################
#             UPDATE OR REFRESH IS NEEDED                 #
###########################################################

if [[ $need_update -eq 1 ]]; then
    cp -p ${mod_script} ${DHCP6C_PATH}
    [[ $? -ne 0 ]] && errExit "unable to copy ${mod_script} to ${DHCP6C_PATH}, install failed"
    echo "$HDR "$(colorGreen "${DHCP6C_PATH} now replaced by ${mod_script}")
elif [[ $need_refresh -eq 1 ]]; then    
    diff -q ${DHCP6C_PATH} ${mod_script}
    if [[ $? -ne 0 ]]; then
        echo "$HDR $(colorYellow 'WARNING:') ${DHCP6C_PATH} is unexpectedly both newer AND different from ${mod_script}..."
        echo "$HDR...perhaps did you update it : to overwrite with the dhcpv6-mod version, use --force argument"
        exit 1
    fi
else
    echo "$HDR $(colorGreen 'No need to update') binary or to refresh config, use --force if you really want to do it anyway"
    exit 0
fi

# Refresh (restart) dhcp clients (if any)

${SCRIPT_DIR}/restart-dhcp-clients.sh

exit 0
