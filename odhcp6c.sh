#!/bin/bash
########################################################################
#
# This script will replace Unifi's executable /usr/sbin/odhcp6c.           
# It will fetch active DHCP v4 client options from current                 
# ubios-udapi-server state, and then prepare DHCP v6 client options.
# DHCP v6 options are generated using a user-defined configuration file
# (/usr/local/etc/dhcpv6.conf), or with the default (dhcpv6-orange.conf)
# At the end, it will 'exec' a new version (provided) of odhcp6c
# (supporting the -K CoS option) with all needed DHCP options arguments
#
########################################################################

# "ubios-udapi-server" will call this script with arguments ("$@") : 
# -e -v -s /usr/share/ubios-udapi-server/ubios-odhcp6c-script -D -P 56 <WANinterface>
# -D means : Discard advertisements without any address or prefix proposed
# -P 56 comes from UI WAN section (defaut 48 to change as IT MUST MATCH 
# what we will get from Orange e.g. 2a01:cb00:647:6c00::/56)

SCRIPT_DIR=$(dirname ${0})
HDR="[dhcpv6-mod]"  # header set in all messages

DHCPV6_CONF=/data/local/etc/dhcpv6.conf                             # Customized conf, if exists
DEFAULT_DHCPV6_CONF=/data/dhcpv6-mod/dhcpv6-orange.conf             # Otherwise will take Orange conf
DHCP6C_SUPPORTED_OPTIONS=/data/dhcpv6-mod/supported-options.json    # Which DHCPv6 options are possible

default_dhcpv6_request_options="17,23,24"           # Default requested options (values for Orange), can be overriden in dhcpv6.conf

# -a deactivates support for reconfigure opcode, -f deactivates sending hostname, 
# -R deactivates requesting option not specified in -r (which are specified with [default_]dhcpv6_request_options)
default_odhcp6c_options="-a -f -R"      # Default basic odhcp6c cmd options   

org_odhcp6c=/usr/sbin/odhcp6c-org       # We have renamed original to -org
new_odhcp6c=/data/local/bin/odhcp6c     # Updated exec (replaces Unifi's old odhcp6c), will be "exec" at the end of this script


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

showPartOf() {   # show only some first and last chars of a string
    l=${#1}; ln=$(( (l-1) / 4 )); [[ $ln -gt 5 ]] && ln=5
    if [[ $l -le 4 ]]; then printf '.%.0s' $(seq 1 $l)
    else printf '%s...%s' ${1:0:$ln} ${1: -$ln}
    fi
}

###########################################################
#         ARG CHECKING AND VARIABLE INITIALIZATIONS       # 
###########################################################

[[ $# -lt 1 ]] && errExit "at least 1 (last argument) : WAN interface, e.g. eth4.832"

# Interface name provided by udapi-server as last arg, we will look for it in JSON config
arg_iface="${@: -1}"

if [[ "${arg_iface}" == "test" ]]; then   # if last arg is "test" don't do any harm (to test locally on any host)
    test_mode=1
    echo "$HDR $(colorYellow 'NOTE: running in test mode')"    
    dhcp6_client=/bin/echo    # so that we don't really call odhcp6c 
    DHCPV6_CONF=${SCRIPT_DIR}/test-files/dhcpv6.conf      # test conf, if exists
    DEFAULT_DHCPV6_CONF=${SCRIPT_DIR}/dhcpv6-orange.conf  # otherwise will take Orange conf
    DHCP6C_SUPPORTED_OPTIONS=${SCRIPT_DIR}/supported-options.json
else 
    test_mode=0
    dhcp6_client=${new_odhcp6c}
    ${org_odhcp6c} -h 2>&1 | grep -q '\-K '                   # Test if Unifi exec finally has the CoS (-K) option
    if [ $? -eq 0 ]; then dhcp6_client=${org_odhcp6c}; fi     # If YES, then use Unifi exec instead of our new one
fi

[[ ! -x "$dhcp6_client" ]] && errExit "could not find odhcp6c executable $dhcp6_client"
echo "$HDR Selected DHCPv6 client executable (with support for CoS) : ${dhcp6_client}"
if [[ $test_mode -eq 1 ]]; then config_file=test-files/interfaces.json
else config_file=$(ps -o cmd= -C ubios-udapi-server | awk '{ for(i=2;i<NF;i++) if($i=="-c") a=$(i+1); print a; }')
fi
[[ ! -f "$config_file" ]] && errExit "could not retrieve or find ubios-udapi-server config file"
echo "$HDR Found ubios-udapi-server JSON config in $config_file"


###########################################################
#      FETCHING DHCP V4 OPTIONS FROM JSON STATE FILE      #
###########################################################

interface_json=$(cat $config_file | jq -r '.interfaces[] | select(.identification.id=="'${arg_iface}'")')
[[ -z "$interface_json" ]] && errExit "could not retrieve interface $arg_iface in JSON config"
dhcpopt_json=$(echo $interface_json | jq -r '.ipv4.dhcpOptions')
[[ "$dhcpopt_json" == "null" ]] && errExit "could not retrieve dhcpOptions of interface ${arg_iface}"

for optn in $(echo $dhcpopt_json | jq -r '.[].optionNumber'); do
    val=$(echo $dhcpopt_json | jq -r '.[] | select(.optionNumber=='"${optn}"') | .value')
    if [[ "$val" =~ ^[[:xdigit:]]+$ ]]; then
        val=$(echo -n "$val" | tr 'abcdef' 'ABCDEF')                # e.g. from 789abc to 789ABC
        valX="${val}"
    elif [[ "$val" =~ ^([[:xdigit:]]{2}:)*[[:xdigit:]]{2}$ ]]; then
        val=$(echo -n "$val" | tr 'abcdef' 'ABCDEF' | tr -d ':')    # e.g. from 78:9a:bc to 789ABC
        valX="${val}"
    else # it's a string
        valX=$(echo -n "$val" | xxd -p -u -c9999)     # string to hexdump : e.g. Live to 4C697665
    fi
    optv4[optn]="$val"
    optv4_hex[optn]="$valX"
    optv4_hexlen[optn]=$(printf '%04x' $((${#valX}/2)))
    echo "$HDR Fetched DHCPv4 option ${optn} : length=${#val} value="$(showPartOf "${val}")
done

# Fetch either MAC Adress Clone or DHCPv4 option 61, the latter takes precedence if both were entered
macaddr=$(echo $interface_json | jq -r '.identification.macOverride' | tr 'abcdef' 'ABCDEF' | tr -d ':')
echo "$HDR Fetched MAC Address Clone : length=${#macaddr}"
[ -z "${optv4[61]}" ] && optv4[61]="${macaddr}" || macaddr="${optv4[61]}"    

# Fetch IPv4 CoS, if set we will use it for -K <CoS>, can be overriden by dhcpv6_cos setting of dhcpv6.conf
dhcpv4_cos=$(echo $interface_json | jq -r '.ipv4.cos')
[ "${dhcpv4_cos}" == "null" ] && dhcpv4_cos=0
echo "$HDR Fetched DHCPv4 CoS of ${dhcpv4_cos}"

# Provide duid_time_hex for the dhcpv6.conf file in case user needs 32-byte DUID time field
duid_time_dec=$(( ($(date +%s) - 946684800) % 2**32 ))
duid_time_hex=$(printf '%04x' $duid_time_dec | tr 'abcdef' 'ABCDEF')


###########################################################
#    EXECUTE DHCPV6_CONF TO GENERATE DHCP V6 OPTIONS      #
###########################################################

# set -u will stop DHCPV6_CONF execution if using any optv4[] not found in JSON
if [ ! -f ${DHCPV6_CONF} ]; then
    echo "$HDR $(colorYellow 'WARNING:') took default dhcp6c options file ${DEFAULT_DHCPV6_CONF} as ${DHCPV6_CONF} was not found"
    DHCPV6_CONF=${DEFAULT_DHCPV6_CONF}
else
    echo "$HDR Found dhcp6c options file ${DHCPV6_CONF}"
fi
set -u
. ${DHCPV6_CONF}
set +u
[[ $? -ne 0 ]] && errExit "problem running dhcp6 config file ${DHCPV6_CONF}"


###########################################################
#       CHECK AND FORMAT GENERATED DHCP V6 OPTIONS        #
###########################################################

# Supported DHCPv6 options of odhcp6c
supported_options_json=$(cat $DHCP6C_SUPPORTED_OPTIONS | jq -r '.supportedOptions[]')

# Initialize odhcp6c_opts with minimum options for odhcp6c cmd
if [[ -z "${odhcp6c_options}" ]]; then
    odhcp6c_options="${default_odhcp6c_options}"  # see at the top of this script for the default
else
    echo "$HDR" $(colorYellow "NOTE:") "odhcp6c_options default overriden to ${odhcp6c_options}"
fi
odhcp6c_opts="${default_odhcp6c_options}"

# -r argument : requested opts from DHCP server, comma-separated
if [[ -z "${dhcpv6_request_options}" ]]; then
    dhcpv6_request_options="${default_dhcpv6_request_options}"  # see at the top of this script for the default
else
    echo "$HDR" $(colorYellow "NOTE:") "dhcpv6_request_options default overriden to ${dhcpv6_request_options}"
fi
odhcp6c_opts="${odhcp6c_opts} -r${dhcpv6_request_options}"

# Set DHCPv6 CoS, to same as DHCPv4 CoS except if user specified a different value dhcpv6_cos (should not happen...)
if [[ ! -z "${dhcpv6_cos}" ]]; then
    if [[ "${dhcpv6_cos}" == "${dhcpv4_cos}" ]]; then
        echo "$HDR" $(colorYellow "NOTE:") "dhcpv6_cos=${dhcpv6_cos} setting is useless, as DHCPv4 CoS ${dhcpv4_cos} is copied by default, consider removing the setting"
    else
        echo "$HDR" $(colorYellow "WARNING: dhcpv6_cos=${dhcpv6_cos} setting is not the same as DHCPv4 CoS ${dhcpv4_cos}, please check !")
        echo "$HDR Nevertheless, DHCPv6 CoS ${dhcpv6_cos} will be applied, but this can lead to WAN DHCP not working at all"
    fi
else
    dhcpv6_cos=${dhcpv4_cos}
    echo "$HDR Generated DHCPv6 CoS of ${dhcpv6_cos} (default is to set to the same value as DHCPv4 CoS)"
fi
odhcp6c_opts="${odhcp6c_opts} -K${dhcpv6_cos}"

odhcp6c_opts_abbrev="${odhcp6c_opts}"

# Iterate over V6 options set in DHCPV6_CONF to construct odhcp6c arguments
for n in ${!optv6[@]}; do
    format=$(echo -n $supported_options_json | jq -r 'select(.number=='"${n}"') | .optionFormat')
    [[ $? -ne 0 ]] && errExit "unsupported DHCPv6 option $n specified in ${DHCPV6_CONF}"
    alias=$(echo -n $supported_options_json | jq -r 'select(.number=='"${n}"') | .optionAlias')
    odhcp6cOption=$(echo -n $supported_options_json | jq -r 'select(.number=='"${n}"') | .odhcp6cOption')
    val=${optv6[n]}
    if [[ "$format" == "string" ]]; then
        val2="${val}"   # already readable string, needs no transformation
    elif [[ "$val" =~ ^[[:xdigit:]]+$ ]]; then
        val2="${val}"   # already hexstring, needs no transformation
    elif [[ "$val" =~ ^([[:xdigit:]]{2}:)*[[:xdigit:]]{2}$ ]]; then
        val2=$(echo -n "$val" | tr 'abcdef' 'ABCDEF' | tr -d ':')    # e.g. from 78:9a:bc to 789ABC
    else
        val2=$(echo -n "$val" | xxd -p -u -c9999)     # string to hexdump : e.g. Live to 4C697665
    fi
    echo "$HDR Generated DHCPv6 option $n : length=${#val2} value="$(showPartOf "${val2}")" (${alias}, ${odhcp6cOption})"
    odhcp6c_opts="${odhcp6c_opts} ${odhcp6cOption}${val2}"
    odhcp6c_opts_abbrev="${odhcp6c_opts_abbrev} ${odhcp6cOption}$(showPartOf "${val2}")" 
done

echo "$HDR Successfully generated ${#optv6[@]} DHCPv6 options using ${DHCPV6_CONF}"


###########################################################
#        FINALLY, CALL (EXEC) THE "REAL" ODHCP6C          #
###########################################################

# We remove the -e (log in stderr) provided by udapi-server in order to avoid duplicated messages in syslog daemon.log
arg_without_e=$(echo " $@" | sed "s/ -e//")

if [[ $test_mode -eq 1 ]]; then printf "$HDR %s : " "$(colorGreen 'odhcp6c options would be')"
else
    echo "$HDR Sleeping 5 seconds before launching ${dhcp6_client}, to let udhcpc send its discover..."
    sleep 5
    echo "$HDR" $(colorGreen "Launching exec") "${dhcp6_client} ${odhcp6c_opts_abbrev} ${arg_without_e}"
fi

exec ${dhcp6_client} ${odhcp6c_opts} ${arg_without_e}
