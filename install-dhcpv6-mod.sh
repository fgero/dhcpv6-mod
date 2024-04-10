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

HDR="[dhcpv6-mod]"  # header set in all messages

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

refresh_dhcp_clients() {
    ps -o cmd= -C ${process_name} >/dev/null
    if [[ $? -eq 0 ]]; then
        ./restart-dhcp-clients.sh
    else
        echo "$HDR $(colorYellow 'NOTE:') ${process_name} process was not started, you will need to activate DHCPv6 in Unifi UI WAN settings"
        echo "$HDR (set 'IPv6 Connection' to 'DHCPv6' and 'Prefix Delegation Size' to 56)"
    fi
}

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

# We need the "file" package in this script
if [[ ! $(which file) ]]; then 
  echo "$HDR This script needs the 'file' package, trying to install it..."
  apt install -y file || errExit "Unable to install the 'file' package (are you root?), aborting."
fi

# Force overwrite existing script in /usr/sbin/odhcp6c only if --force
[[ "$1" = "--update" ]] && echo "$HDR $(colorYellow 'NOTE:') --update ignored, no longer useful"
[[ "$1" = "--force" ]] && force_update=1 || force_update=0

bin_name="odhcp6c"
process_name=${bin_name}
${process_name}-org -h 2>&1 | grep -q '\-K '
[ $? -eq 0 ] && process_name=${process_name}-org

sbin_file="/usr/sbin/${bin_name}"
mod_script="/data/dhcpv6-mod/${bin_name}.sh"
mod_bin="/data/local/bin/${bin_name}"
dhcpv6_conf="/data/local/etc/dhcpv6.conf"
dhcpv6_default_conf="/data/dhcpv6-mod/dhcpv6-orange.conf"

# Let's test if we have either Unifi's odhcp6c supporting -K, or we have built another one supporting that
${mod_bin} -h 2>&1 | grep -q '\-K '
if [ $? -ne 0 ]; then # if no rebuilt odhcp6c bin found, or (should not happen) if it does not support -K
  if [[ "$(file -b --mime-type ${sbin_file})" =~ "application/" ]]; then # if /usr/sbin/odhcp6c is Unifi's executable binary
    ${sbin_file} -h 2>&1 | grep -q '\-K '
    [ $? -ne 0 ] && errExit "Unifi's ${sbin_file} does not support -K option, you must build one from source in ${mod_bin}, see README.md"
  else # /usr/sbin/odhcp6c is our shell script, just check that backuped Unifi (odhcp6c-org) exec is there and supports -K
    ${sbin_file}-org -h 2>&1 | grep -q '\-K '
    [ $? -ne 0 ] && errExit "Mod previously installed, but neither ${mod_bin} nor ${sbin_file}-org supports -K option, that is unexpected, please build one from source in ${mod_bin}, see README.md"
  fi
fi

# Avoids wget fw-download.ubnt.com IPv6 endpoints unreachable
grep -sq '^prefer-family' /root/.wgetrc || echo 'prefer-family = IPv4' >> /root/.wgetrc

# Creates default dhcpv6.conf if does not exist (default : Orange DHCP V6 conf)
if [[ ! -f "${dhcpv6_conf}" ]]; then
    mkdir -p /data/local/etc
    cp -p ${dhcpv6_default_conf} ${dhcpv6_conf}
fi

# Our on_boot.d script is no longer useful, remove it if exists
onboot_script="/data/on_boot.d/05-replace-odhcp6c.sh"
[[ -e ${onboot_script} ]] && rm -f ${onboot_script}

###########################################################
# FILE & PROCESS AGE ANALYSIS TO SEE IF UPDATE IS NEEDED  #
###########################################################

process_age=$(get_elaps_of_process "${process_name}")   # can be ERROR if not started (V6 inact or KO)
sbin_file_age=$(get_elaps_of_file "${sbin_file}")       # cannot be ERROR, either Unifi or ours
mod_script_age=$(get_elaps_of_file "${mod_script}")     # cannot be ERROR, this is our repository
dhcpv6_conf_age=$(get_elaps_of_file "${dhcpv6_conf}")   # cannot be ERROR, we just copied it if inex

need_update=0    # assume update of binary not needed
need_refresh=0   # assume refresh of dhcpc running process not needed

if [[ "${process_age}" = "ERROR" ]]; then
    echo "$HDR No runnning ${process_name} process found, need to install or update from dhcpv6-mod"
    need_update=1
fi
if [[ $sbin_file_age -gt $mod_script_age ]]; then
    echo "$HDR ${sbin_file} ($(prettyAge ${sbin_file_age})) is older than ${mod_script} ($(prettyAge ${mod_script_age}))"
    need_update=1
fi
# note: if process_age=ERROR then it is always less than any number
if [[ $process_age -gt $mod_script_age ]]; then
    echo "$HDR ${process_name} process ($(prettyAge ${process_age})) is older than ${mod_script} ($(prettyAge ${mod_script_age}))"
    need_update=1
fi
if [[ $process_age -gt $dhcpv6_conf_age ]]; then
    echo "$HDR ${process_name} process ($(prettyAge ${process_age})) is older than dhcpv6.conf ($(prettyAge ${dhcpv6_conf_age}))"
    need_refresh=1
fi

if [[ "$(file -b --mime-type ${sbin_file})" =~ "application/" ]]; then
    echo "$HDR ${sbin_file} detected as an original Unifi executable, not our shell script"
    mv ${sbin_file} ${sbin_file}-org
    [[ $? -ne 0 ]] && exit 1 || echo "$HDR "$(colorGreen "${sbin_file} renamed ${sbin_file}-org")
    need_update=1   # force even if was determined to be 0 before
fi

if [[ $force_update -eq 1 ]]; then
    echo "$HDR $(colorYellow 'NOTE:') no need to update binary or config, but you used --force so we will to that anyway"
    need_update=1
fi

[[ $need_update -eq 1 ]] && need_refresh=1

if [[ $need_refresh -eq 0 ]]; then
    echo "$HDR $(colorGreen 'No need to update') binary or to refresh config, use --force if you really want to do it anyway"
    exit 0
elif [[ $need_update -eq 0 ]]; then
    diff -q ${sbin_file} ${mod_script}
    if [[ $? -ne 0 ]]; then
        echo "$HDR $(colorYellow 'WARNING:') ${sbin_file} is unexpectedly both newer AND different from ${mod_script}..."
        echo "$HDR...perhaps have you modified it : to overwrite with dhcpv6-mod version, use --force argument"
        exit 0
    fi
fi


###########################################################
#                    UPDATE IS NEEDED                     #
###########################################################

if [[ $need_update -eq 1 ]]; then
    cp -p ${mod_script} ${sbin_file}
    [[ $? -ne 0 ]] && exit 1 || echo "$HDR "$(colorGreen "${sbin_file} replaced by ${mod_script}")
fi

refresh_dhcp_clients

exit 0