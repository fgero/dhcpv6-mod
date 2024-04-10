#!/bin/bash
########################################################################
#
# RE-INITIATE FULL DHCPv4 and DHCPv6 DISCOVER SEQUENCES :
# - force RELEASE of udhcpc (DHCPv4 client) via SIGUSR2
# - properly stop both udhcpc and odhcp6c via SIGTERM
# - both will be automaticaly restarted by ubios-udapi-server
#
########################################################################

HDR="[restart-dhcp-clients]"  # header set in all messages

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

process_name="odhcp6c"
ps -o cmd= -C ${process_name} >/dev/null
if [[ $? -ne 0 ]]; then
  ps -o cmd= -C ${process_name}-org >/dev/null
  [[ $? -eq 0 ]] && process_name=${process_name}-org
fi

if [[ $? -eq 0 ]]; then         
    echo "$HDR $(colorGreen 'Restarting DHCPv4 (udhcpc) and DHCPv6 (odhcp6c) clients') to take updates into account"
    echo "$HDR (this will initiate a DHCP Discover process, and should not interrupt your connection...)"
    killall -s SIGUSR2 udhcpc   # Force DHCPv4 RELEASE before restarting udhcpc because Unifi doesn't set the -R option
    sleep 1                     #....and ISP wants a proper RELEASE of both v4 and v6 leases before re-discover etc..
    killall udhcpc ${process_name}
    echo "$HDR You can now check dhcp client logs with :"
    echo "grep -E 'dhcpc|odhcp6c|dhcpv6-mod' /var/log/daemon.log"
else
    echo "$HDR $(colorYellow 'NOTE:') DHCPv6 (odhcp6c) client not running"
    echo "$HDR $(colorGreen 'Restarting DHCPv4 (udhcpc) client')"
    echo "$HDR (this will initiate a DHCPv4 Discover process, and should not interrupt your connection...)"
    killall -s SIGUSR2 udhcpc   # Force DHCPv4 RELEASE before restarting udhcpc because Unifi doesn't set the -R option
    sleep 1                     
    killall udhcpc
    echo "$HDR You can now check dhcp client logs with :"
    echo "grep dhcpc /var/log/daemon.log"
fi

exit 0
