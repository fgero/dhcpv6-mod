########################################################################
#
# This script shoud be placed in /data/on_boot.d, and needs udm-boot
#
# This script will replace, if needed, Unifi executable /usr/sbin/odhcp6c
# by /data/dhcpv6-mod/odhcp6c.sh (and save odhcp6c as odhcp6c-org before)
# Then it will restart both udhcpc and odhcp6c (restart discover process)
# without interrupting the WAN connection (if dhcpv6.conf is valid)
# It will only do that if needed (i.e. odhcp6c back to Unifi's version)
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
#                    INITIALIZATIONS                      #
###########################################################

bin_name="odhcp6c"

sbin_file="/usr/sbin/${bin_name}"
mod_script="/data/dhcpv6-mod/${bin_name}.sh"
mod_bin="/data/local/bin/${bin_name}"

${mod_bin} -h 2>&1 | grep -q '\-K ' || errExit "${mod_bin} is NOT supporting -K CoS"

# Avoids wget fw-download.ubnt.com IPv6 endpoints unreachable
grep -sq '^prefer-family' /root/.wgetrc || echo 'prefer-family = IPv4' >> /root/.wgetrc

###########################################################
#          ANALYSIS TO SEE IF UPDATE IS NEEDED            #
###########################################################

need_update=0

if [[ "$(file -b --mime-type ${sbin_file})" =~ "application/" ]]; then
    echo "$HDR ${sbin_file} detected as an original Unifi executable, not our shell script"
    mv ${sbin_file} ${sbin_file}-org
    [[ $? -ne 0 ]] && exit 1 || echo "$HDR "$(colorGreen "${sbin_file} renamed ${sbin_file}-org")
    need_update=1
else
    diff -q ${sbin_file} ${mod_script}
    if [[ $? -ne 0 ]]; then
        echo "$HDR $(colorYellow 'WARNING:') ${sbin_file} is different from ${mod_script}..."
        echo "$HDR...perhaps have you modified it : to overwrite with dhcpv6-mod version, use /data/dhcpv6-mod/install-dhcpv6-mod.sh"
    else
        echo "$HDR $(colorGreen 'No need to update') ${sbin_file}, as it is the same as dhcpv6-mod version"
    fi
fi

###########################################################
#                    UPDATE IS NEEDED                     #
###########################################################

if [[ $need_update -eq 1 ]]; then
    cp -p ${mod_script} ${sbin_file}
    [[ $? -ne 0 ]] && exit 1 || echo "$HDR "$(colorGreen "${sbin_file} replaced by ${mod_script}")
    ps -o cmd= -C odhcp6c >/dev/null
    if [[ $? -eq 0 ]]; then
        echo "$HDR $(colorGreen 'Restarting DHCPv4 (udhcpc) and DHCPv6 (odhcp6c) clients') to take updates into account"
        killall udhcpc odhcp6c
    fi
fi

exit 0