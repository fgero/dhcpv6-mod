#!/bin/bash
#
# udapi-server will pass as arguments ("$@") : -e -v -s /usr/share/ubios-udapi-server/ubios-odhcp6c-script -D -P 56 eth4.832
# -D means : Discard advertisements without any address or prefix proposed
# -P 56 comes from UI WAN section (defaut 48 to change as IT MUST MATCH what we will get from Orange e.g. 2a01:cb00:647:6c00::/56)

org_odhcp6c=/usr/sbin/odhcp6c-org       # We have renamed original to -org
new_odhcp6c=/data/local/bin/odhcp6c     # Updated exec (replaces Unifi's old odhcp6c), will be "exec" at the end of this script

vendor_class_pfx="0000040E0005"              # Prefix for option 16 DHCPv6 : SagemCom IANA enterp number + strlen 'sagem' (0005)
client_id_pfx="00030001"                     # Prefix for option 1 DHCPv6 : DUID-LL (0003) + hw type (0001)

[[ $# -lt 1 ]] && { echo "At least 1 (last argument) : WAN interface, e.g. eth4.832"; exit 1; }
[[ $# -eq 2 && "$1" == "test" ]] && test_mode=1 || test_mode=0

dhcp6_client=${new_odhcp6c}
${org_odhcp6c} -h 2>&1 | grep -q '\-K '                   # Test if Unifi exec finally has the CoS (-K) option
if [ $? -eq 0 ]; then dhcp6_client=${org_odhcp6c}; fi     # If YES, then use Unifi exec instead of our new one

[[ ! -x "$dhcp6_client" ]] && { echo "Could not find odhcp6c executable $dhcp6_client" >&2 ; exit 1; }
echo "Selected DHCPv6 client executable (with support for CoS) : ${dhcp6_client}"

# Interface name provided by udapi-server as last arg, we will look for it in JSON config
arg_iface="${@: -1}"

config_file=$(ps -o cmd= -C ubios-udapi-server | awk '{ for(i=2;i<NF;i++) if($i=="-c") a=$(i+1); print a; }')
[[ ! -f "$config_file" ]] && { echo "Could not retrieve or find ubios-udapi-server config file" >&2 ; exit 1; }
echo "Found ubios-udapi-server JSON config in $config_file"

interface_json=$(cat $config_file | jq -r '.interfaces[] | select(.identification.id=="'${arg_iface}'")')
[[ -z "$interface_json" ]] && { echo "Could not retrieve interface $arg_iface in JSON config" >&2 ; exit 1; }
dhcpopt_json=$(echo $interface_json | jq -r '.ipv4.dhcpOptions')
[[ "$dhcpopt_json" == "null" ]] && { echo "Could not retrieve dhcpOptions of interface ${arg_iface}" >&2 ; exit 1; }

# Option 16 DHCPv6 vendor-class (-V) : from option 60 DHCPv4
vendor=$(echo $dhcpopt_json | jq -r '.[] | select(.optionNumber==60) | .value')
vendor_class_16=${vendor_class_pfx}$(echo -n $vendor | xxd -p -u)
echo "DHCPv6 option 16 vendor-class : length=${#vendor_class_16}"

# Option 15 DHCPv6 user-class (-u) : from option 77 DHCPv4
user_class_15=$(echo $dhcpopt_json | jq -r '.[] | select(.optionNumber==77) | .value')
echo "DHCPv6 option 15 user-class   : length=${#user_class_15}"

# Option 11 DHCPv6 authentication (passed with -x 11:) : from option 90 DHCPv4
authentication_11=$(echo $dhcpopt_json | jq -r '.[] | select(.optionNumber==90) | .value' | tr 'abcdef' 'ABCDEF' | tr -d ':')
echo "DHCPv6 option 11 authent      : length=${#authentication_11}"

# Option 1 DHCPv6 client-id (-c) : frol option 61 DHCPv4 (DUID prefix + MAC Address Clone from the UI)
client_id_1=${client_id_pfx}$(echo $interface_json | jq -r '.identification.macOverride' | tr 'abcdef' 'ABCDEF' | tr -d ':')
echo "DHCPv6 option 01 client-id    : length=${#client_id_1}"

# We remove the -e (log in stderr) provided by udapi-server in order to avoid duplicated messages in syslog daemon.log
arg_without_e=$(echo " $@" | sed "s/ -e//")

# -R deactivates requesting option not specified in -r
# -f deactivates sending hostname
# -a deactivates support for reconfigure opcode
# -K6 sets CoS 6 (SO_PRIORITY) for Orange ISP

[[ $test_mode -eq 1 ]] && exit 0

exec ${dhcp6_client} -a -f -K6 -R -r11,17,23,24 \
-V ${vendor_class_16} -c ${client_id_1} -u ${user_class_15} -x 11:${authentication_11} ${arg_without_e}
