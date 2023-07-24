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
    ps -o cmd= -C odhcp6c >/dev/null
    if [[ $? -eq 0 ]]; then
        ./restart-dhcp-clients.sh
    else
        echo "$HDR $(colorYellow 'NOTE:') odhcp6c process was not started, you will need to activate DHCPv6 in Unifi UI WAN settings"
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

# Force overwrite existing script in /usr/sbin/odhcp6c only if --force
[[ "$1" = "--update" ]] && echo "$HDR $(colorYellow 'NOTE:') --update ignored, no longer useful"
[[ "$1" = "--force" ]] && force_update=1 || force_update=0

bin_name="odhcp6c"

sbin_file="/usr/sbin/${bin_name}"
mod_script="/data/dhcpv6-mod/${bin_name}.sh"
mod_bin="/data/local/bin/${bin_name}"
dhcpv6_conf="/data/local/etc/dhcpv6.conf"
dhcpv6_default_conf="/data/dhcpv6-mod/dhcpv6-orange.conf"

${mod_bin} -h 2>&1 | grep -q '\-K ' || errExit "${mod_bin} is NOT a valid modified ${bin_name} binary"

# Avoids wget fw-download.ubnt.com IPv6 endpoints unreachable
grep -sq '^prefer-family' /root/.wgetrc || echo 'prefer-family = IPv4' >> /root/.wgetrc

# Creates default dhcpv6.conf if does not exist (default : Orange DHCP V6 conf)
if [[ ! -f "${dhcpv6_conf}" ]]; then
    mkdir -p /data/local/etc
    cp -p ${dhcpv6_default_conf} ${dhcpv6_conf}
fi

# Ensure our on_boot.d script is a symlink and is up to date
onboot_script="/data/on_boot.d/05-replace-odhcp6c.sh"
if [[ -e ${onboot_script} ]]; then
    real_install_script="/data/dhcpv6-mod/udm-boot/05-replace-odhcp6c.sh"
    diff -q ${onboot_script} ${real_install_script}
    if [[ $? -ne 0 ]]; then
        if [[ -x "${real_install_script}" ]]; then
            echo "$HDR ${onboot_script} needs to be updated"
            ln -sf ${real_install_script} ${onboot_script}
            [ $? -ne 0 ] && errExit "unable to create symlink ${onboot_script}"
            echo "$HDR existing ${onboot_script} successfully updated"
        fi
    fi
fi

###########################################################
# FILE & PROCESS AGE ANALYSIS TO SEE IF UPDATE IS NEEDED  #
###########################################################

process_age=$(get_elaps_of_process "${bin_name}")   # can be ERROR if not started (V6 inact or KO)
sbin_file_age=$(get_elaps_of_file "${sbin_file}")       # cannot be ERROR, either Unifi or ours
mod_script_age=$(get_elaps_of_file "${mod_script}")     # cannot be ERROR, this is our repository
dhcpv6_conf_age=$(get_elaps_of_file "${dhcpv6_conf}")   # cannot be ERROR, we just copied it if inex

need_update=1    # assume update because it's easier to determine if update not needed...

if [[ "${process_age}" != "ERROR" ]]; then
    if [[ ("$sbin_file_age" -le "$mod_script_age") && ("$process_age" -le "$mod_script_age") && ("$process_age" -le "$dhcpv6_conf_age") ]]; then
        echo "$HDR running ${bin_name} is more recent than dhcpv6-mod script (and config)"
        need_update=0
    else
        [[ "$sbin_file_age" > "$mod_script_age" ]] && \
            echo "$HDR ${sbin_file} ($(prettyAge ${sbin_file_age})) is older than ${mod_script} ($(prettyAge ${mod_script_age}))"
        [[ "$process_age" > "$mod_script_age" ]] && \
            echo "$HDR ${bin_name} process ($(prettyAge ${process_age})) is older than ${mod_script} ($(prettyAge ${mod_script_age}))"
        [[ "$process_age" > "$dhcpv6_conf_age" ]] && \
            echo "$HDR ${bin_name} process ($(prettyAge ${process_age})) is older than dhcpv6.conf ($(prettyAge ${dhcpv6_conf_age}))"
        echo "$HDR ==> we need to update ${bin_name} from dhcpv6-mod"
    fi
else
    echo "$HDR No runnning ${bin_name} process found, need to install or update from dhcpv6-mod"
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
elif [[ $need_update -eq 0 ]]; then
    diff -q ${sbin_file} ${mod_script}
    if [[ $? -ne 0 ]]; then
        echo "$HDR $(colorYellow 'WARNING:') ${sbin_file} is unexpectedly both newer AND different from ${mod_script}..."
        echo "$HDR...perhaps have you modified it : to overwrite with dhcpv6-mod version, use --force argument"
    else
        echo "$HDR $(colorGreen 'No need to update') binary or config, use --force if you really want to do it anyway"
    fi
    exit 0
fi

###########################################################
#                    UPDATE IS NEEDED                     #
###########################################################

cp -p ${mod_script} ${sbin_file}
[[ $? -ne 0 ]] && exit 1 || echo "$HDR "$(colorGreen "${sbin_file} replaced by ${mod_script}")

refresh_dhcp_clients

exit 0
