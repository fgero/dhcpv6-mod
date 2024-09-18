#!/bin/bash
########################################################################
#
# RE-INITIATE FULL DHCPv4 and DHCPv6 DISCOVER SEQUENCES :
# - force RELEASE of udhcpc (DHCPv4 client) via SIGUSR2
# - properly stop both udhcpc and odhcp6c via SIGTERM
# - both will be automaticaly restarted by ubios-udapi-server
#
########################################################################

DHCP4C_BIN="udhcpc"             # Unifi's binary name (not path) for DHCPv4 client
DHCP6C_BIN="odhcp6c"            # Unifi's binary name (not path) for DHCPv6 client

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
#                      MAIN SECTION                       #
###########################################################

HDR="[restart-dhcp-clients]"  # header set in all messages

if ps -o cmd= -C ${DHCP6C_BIN} &>/dev/null; then
    dhcpv6_process=${DHCP6C_BIN}
elif ps -o cmd= -C ${DHCP6C_BIN}-org &>/dev/null; then
    dhcpv6_process=${DHCP6C_BIN}-org
else
    echo "$HDR $(colorYellow 'NOTE:') DHCPv6 client process is not running, it needs to be activated in the WAN settings"
    dhcpv6_process=""
fi

if [[ -n "${dhcpv6_process}" ]]; then         
    echo "$HDR $(colorGreen 'Restarting DHCPv4 (udhcpc) and DHCPv6 (odhcp6c) clients') to take updates into account"
    echo "$HDR (this will initiate a DHCPv4+v6 Discover process, and should not interrupt your connection...)"
else
    echo "$HDR $(colorGreen 'Restarting DHCPv4 (udhcpc) client')"
    echo "$HDR (this will initiate a DHCPv4 Discover process, and should not interrupt your connection...)"
fi

killall -s SIGUSR2 ${DHCP4C_BIN}   # Force DHCPv4 RELEASE before restarting udhcpc because Unifi doesn't set the -R option
sleep 1                            #....and ISP wants a proper RELEASE of both v4 and v6 leases before re-discover etc..
killall ${DHCP4C_BIN} ${dhcpv6_process}

echo "$HDR Restart done, you can now check dhcp client logs with :"
echo "grep -E 'dhcpc|odhcp6c|dhcpv6-mod' /var/log/daemon.log"

exit 0
