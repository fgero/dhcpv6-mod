# dhcpv6-mod

> **NEW** since July 17th, 2023 :
> If you're not using Orange France ISP, it's now possible to configure your own DHCPv6 options (see the [Initialize DHCPv6 config file](#configure_dhcpv6) section).

> **Warning** since July 19th 2023 :
> I have definitely given up trying to automaticaly re-install the mod after UnifiOS firmware updates boots, udm-boot package does not work
> So, you must exec the ./install-dhcpv6-mod.sh after a firmware update in order for dhcpv6 to work again
> Note that, for "normal" reboots of UDM/UDR, the mod is kept, nothing to do

This project enables Unifi UDM/UDR to provide required DHCP V6 client options to ISPs (like Orange France), including by extracting values from V4 DHCP client options  you've already set in Unifi UI.

This mod was developed because there's no way to configure DHCP v6 client options in the WAN section of Unifi's UI. 

It should work on any UDM/UDMPro/UDR with at least UnifiOS 2.4.x (3.x is recommended as I can no longer test in 2.x).

For Orange France, or any other ISP that requires a non-zero CoS for DHCP requests, you need to be in **UnifiOS 3.1.12 at least** (because [DHCP v4 renew was not working](https://community.ui.com/questions/Automatic-renew-at-mid-life-of-WAN-DHCPv4-lease-does-not-work-no-CoS-set-in-unicast-renew-UDR-is-di/df07d8aa-54e4-4f8e-b171-01b876a19aec) before this release)

> **Warning**


&nbsp;  
&nbsp;  

> **Warning**
> For existing users, after any update of this repo *or of your config file*, please don't forget to run the `./install-dhcpv6-mod.sh` command again (see [Install or update dhcpv6-mod](#install_dhcpv6_mod)).

&nbsp;  
&nbsp;  


## Table of Contents

- [How does it work ?](#how_does_it_work)
- [Build a odhcp6c supporting CoS](#build_odhcp6c)
- [Download dhcpv6-mod files](#download_dhcpv6_mod)
- [Initialize DHCPv6 config file](#configure_dhcpv6)
- [Install (or update) dhcpv6-mod](#install_dhcpv6_mod)
- [Activate DHCPv6 WAN client](#activate_dhcpv6)
- [Check IPv6 lease and connectivity](#check_ipv6)
- [Rollback (if needed)](#rollback)
&nbsp;  
&nbsp;  

<a id="how_does_it_work"></a>

## How does it work ?
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

As a prerequisite, you must have entered the needed DHCP V4 WAN options (for Orange : 60, 61, 77 and 90), using Unifi's GUI WAN1 settings, as they are needed to generate V6 options. 

Then we will :
- Build a more recent version of `odhcp6c` (from [openwrt repo](https://github.com/openwrt/odhcp6c)) that has the `-K` option in order to pass a CoS for DHCP requests
- Replace Unifi's `/usr/sbin/odhcp6c` by our own shell script `odhcp6c.sh`, which will :
  - fetch the DHCPv4 options values from `ubios-udapi-server` state file
  - prepare the DHCPv6 options with required formats, customizable via a configuration file 
  - finally, `exec` the new `/data/local/bin/odhcp6c` (the one we just built), with all the adequate options


&nbsp;  
&nbsp;  

<a id="build_odhcp6c"></a>

## On the UDM/UDR, build a version of odhcp6c supporting CoS
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

First (if not already done), install git and cmake on the UDM/UDR :

```bash
apt-get install -y git cmake file
```

Then, make a new odhcp6c executable locally (here in root's home directory), from the [openwrt repo](https://github.com/openwrt/odhcp6c), and deploy it in `/data/local/bin` :

```bash
cd
git clone https://github.com/openwrt/odhcp6c.git
cd odhcp6c
cmake .
make
mkdir -p /data/local/bin
cp -p odhcp6c /data/local/bin
```
Check that our new odhcp6c supports the CoS option (the line with '-K' should be displayed) :
```console
# /data/local/bin/odhcp6c -h 2>&1 | grep priority
	-K <sk-prio>	Set packet kernel priority (0)
```

> [OPTIONAL] You can delete the source code (not needed for our purpose) :
> ```bash
> rm -rf /root/odhcp6c
> ```


&nbsp;  
&nbsp;  

<a id="download_dhcpv6_mod"></a>

## Download dhcpv6-mod files
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;  

Install the repo files in the `/data/dhcpv6-mod` directory (/data is persisted after reboots including firmwares upgrades).

You can either use `git` to clone this repo (**recommended**) :
```bash
cd /data
git clone https://github.com/fgero/dhcpv6-mod.git
```
...or alternatively download the files with `curl` :

```bash
cd /data
curl -sL https://github.com/fgero/dhcpv6-mod/archive/refs/heads/main.tar.gz | tar -xvz
mv dhcpv6-mod-main dhcpv6-mod
```

&nbsp;  
&nbsp;  

<a id="configure_dhcpv6"></a>

## Initialize DHCP V6 configuration file 
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;  

If you are using Orange France ISP, then you may skip this section and move to the next section ([Install/update dhcpv6-mod files](#install_dhcpv6_mod)), as the installation will create the `/data/local/etc/dhcpv6.conf` config file for you, with Orange settings by default.

If you are NOT using Orange France ISP, the first time you install dhcpv6-mod, you must create the `/data/local/etc/dhcpv6.conf` file yourself before moving to the next section (installation).

Please read the [CONFIGURE.md](CONFIGURE.md) documentation page, which describes how to create your own config file.

&nbsp;  
&nbsp;  

<a id="install_dhcpv6_mod"></a>

## Install (or update) dhcpv6-mod
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;  

Go to the directory we just cloned, and run the install/update script :

```bash
cd /data/dhcpv6-mod
./install-dhcpv6-mod.sh
```
This command must be issued :
- when installing `dhcpv6-mod` for the first time
- when `dhcpv6-mod` repository gets an update (except if limited to documentation)
- when you update your configuration file (`/data/local/etc/dhcpv6.conf`)
- after a **firmware update reboot** (not a normal reboot, which does not uninstall dhcpv6-mod)

> **Note**
> the command will initially create the `/data/local/etc/dhcpv6.conf` configuration file <u>ONLY if it does not already exist</u>, using the `dhcpv6-orange.conf` file content.

In fact, the `./install-dhcpv6-mod.sh` command can be run at any time : it will only update `/usr/sbin/odhcp6c` with a new version of `odhcp6c.sh` if one of the following is true :
- file `/usr/sbin/odhcp6c` is older than `odhcp6c.sh` 
- process `odhcp6c` is older than `odhcp6c.sh` or `dhcpv6.conf`

If the script did really change something, and if a DHCPv6 client process was already running, then the script will finish with a restart of both DHCP v4 and v6 clients. This will simply launch a DHCP discover phase for both (V4/V6 consistency is needed by Orange), without interrupting the WAN connection. 

So, after any update that triggered a restart of DHCPv6 clients, it is advisable to [Check IPv6 lease and connectivity](#check_ipv6)

&nbsp;  
&nbsp;  

<a id="activate_dhcpv6"></a>

## Activate DHCP V6 WAN client for the first time
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;  

In the UI, go to Network > Settings > Internet > Primary (WAN1)

You must already have set VLAN ID (832 for Orange), DHCP client options (V4) 60/77/90, DHCP CoS 6.

Now you need to set `IPv6 Connection` to `DHCPv6` (instead of Disabled) and `Prefix Delegation Size` to `56` (instead of 64), like so :

![IPv6 WAN settings](images/IPV6_WAN_settings.png#gh-dark-mode-only)
![IPv6 WAN settings](images/IPV6_WAN_settings_light.png#gh-light-mode-only)

Then, the ubios-udapi-server process should fork, in addition to udhcpc (V4 client), a new process running our own odhcp6c with all the parameters passed, like so :

```console
# ps -ef | grep dhcp
root     2574251    4134  0 Jun18 ?        00:00:00 /usr/bin/busybox-legacy/udhcpc --foreground --interface eth4.832 --script /usr/share/ubios-udapi-server/ubios-udhcpc-script --decline-script /usr/share/ubios-udapi-server/ubios-udhcpc-decline-script -r <publicIPv4> -y 6 --vendorclass sagem -x 77:<userclass_hex> -x 90:<auth>
root     2574252    4134  0 Jun18 ?        00:00:00 /data/local/bin/odhcp6c -a -f -K6 -R -r11,17,23,24 -V <pfx+vendorclass> -c <pfx+clientid> -u <userclass_string> -x 11:<auth> -v -s /usr/share/ubios-udapi-server/ubios-odhcp6c-script -D -P 56 eth4.832
```

&nbsp;  
&nbsp;  

<a id="check_ipv6"></a>

## Check DHCP V6 lease and IPV6 WAN connectivity
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;  


You can check the DHCP V6 discover process and lease in the system log :

```bash
grep -E 'dhcpc|odhcp6c|dhcpv6-mod' /var/log/daemon.log
```
<details close><summary><code>Expected output</code> (click to expand)</summary><br/>

```console
2023-07-17T15:45:26+02:00 UDR odhcp6c[2540864]: Starting RELEASE transaction (timeout 4294967295s, max rc 5)
2023-07-17T15:45:26+02:00 UDR odhcp6c[2540864]: Send RELEASE message (elapsed 0ms, rc 0)
2023-07-17T15:45:26+02:00 UDR ubios-udapi-server[2540863]: udhcpc: received SIGTERM
2023-07-17T15:45:26+02:00 UDR ubios-udapi-server[3018621]: udhcpc: started, v1.34.1
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Selected DHCPv6 client executable (with support for CoS) : /data/local/bin/odhcp6c
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Found ubios-udapi-server JSON config in /data/udapi-config/ubios-udapi-server/ubios-udapi-server.state
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Fetched DHCPv4 option 60 : length=5 value=s...m
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Fetched DHCPv4 option 77 : length=43 value=FSVDS...ebox3
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Fetched DHCPv4 option 90 : length=140 value=00000...xxxxx
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Fetched MAC Address Clone : length=12
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Fetched DHCPv4 CoS of 6
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Found dhcp6c options file /data/local/etc/dhcpv6.conf
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Generated DHCPv6 CoS of 6 (default is to set to the same value as DHCPv4 CoS)
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Generated DHCPv6 option 1 : length=20 value=0003...xxxx (clientid, -c )
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018621]: udhcpc: broadcasting discover
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018763]: [info ] ubios-dhcpc-decline-script: DHCP offer 90.xx.xx.xxx/21 on interface eth4.832, gateway: 90.xx.xx.1
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Generated DHCPv6 option 11 : length=140 value=00000...xxxxx (authentication, -x 11:)
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018763]: [info ] ubios-dhcpc-decline-script: DHCP offer 90.xx.xx.xxx/21 accepted
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018621]: udhcpc: broadcasting select for 90.xx.xx.xxx, server 80.xx.xxx.x
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Generated DHCPv6 option 15 : length=43 value=FSVDS...ebox3 (userclass, -u )
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Generated DHCPv6 option 16 : length=22 value=00000...7656D (vendorclass, -V )
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Successfully generated 4 DHCPv6 options using /data/local/etc/dhcpv6.conf
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Launching exec /data/local/bin/odhcp6c -a -f -R -r17,23,24 -K6 -c 0003...xxxx -x 11:00000...xxxxx -u FSVDS...ebox3 -V 00000...7656D  -v -s /usr/share/ubios-udapi-server/ubios-odhcp6c-script -D -P 56 eth4.832
2023-07-17T15:45:27+02:00 UDR odhcp6c[3018622]: (re)starting transaction on eth4.832
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018621]: udhcpc: lease of 90.xx.xx.xxx obtained from 80.xx.xxx.x, lease time 604800
2023-07-17T15:45:28+02:00 UDR odhcp6c[3018622]: Starting SOLICIT transaction (timeout 4294967295s, max rc 0)
2023-07-17T15:45:28+02:00 UDR odhcp6c[3018622]: Got a valid ADVERTISE after 13ms
2023-07-17T15:45:28+02:00 UDR odhcp6c[3018622]: IA_NA 0001 T1 0 T2 0
2023-07-17T15:45:28+02:00 UDR odhcp6c[3018622]: IA_PD 0001 T1 84672 T2 483840
2023-07-17T15:45:28+02:00 UDR odhcp6c[3018622]: 2a01:xxxx:xxx:xxxx::/56 preferred 604800 valid 604800
2023-07-17T15:45:30+02:00 UDR odhcp6c[3018622]: Starting SOLICIT transaction (timeout 4294967295s, max rc 0)
2023-07-17T15:45:30+02:00 UDR odhcp6c[3018622]: Got a valid ADVERTISE after 10ms
2023-07-17T15:45:30+02:00 UDR odhcp6c[3018622]: IA_PD 0001 T1 84672 T2 483840
2023-07-17T15:45:30+02:00 UDR odhcp6c[3018622]: 2a01:xxxx:xxx:xxxx::/56 preferred 604800 valid 604800
2023-07-17T15:45:31+02:00 UDR odhcp6c[3018622]: Starting REQUEST transaction (timeout 4294967295s, max rc 10)
2023-07-17T15:45:31+02:00 UDR odhcp6c[3018622]: Send REQUEST message (elapsed 0ms, rc 0)
2023-07-17T15:45:31+02:00 UDR odhcp6c[3018622]: Got a valid REPLY after 124ms
2023-07-17T15:45:31+02:00 UDR odhcp6c[3018622]: IA_PD 0001 T1 84672 T2 483840
2023-07-17T15:45:31+02:00 UDR odhcp6c[3018622]: 2a01:xxxx:xxx:xxxx::/56 preferred 604800 valid 604800
2023-07-17T15:45:31+02:00 UDR odhcp6c[3018622]: T1 84672s, T2 483840s, T3 604800s
2023-07-17T15:45:31+02:00 UDR odhcp6c[3018622]: entering stateful-mode on eth4.832
2023-07-17T15:45:31+02:00 UDR odhcp6c[3018622]: Starting <POLL> transaction (timeout 84672s, max rc 0)
```
</details><br>

In that output you asked and got a /56 prefix (7 bytes), like [2a01:xxxx:xxx:xx](#)00:, and the 8th byte (00) is reserved by your router/box, you can use 01 to FF (254 subnets of /64) 

If this does not work, you can try to reset both DHCP v4 and v6 sequences :

```bash
killall udhcpc odhcp6c 
# wait a few seconds
grep -E 'dhcpc|odhcp6c|dhcpv6-mod' /var/log/daemon.log
```

If you need to just check the log generated by odhcp6c.sh, in order to see DHCPv6 option generation :
```bash
grep dhcpv6-mod /var/log/daemon.log 
```
&nbsp;

Even after getting a V6 lease, your WAN interface will not get a public IPV6 address, this is expected (apparently) in a V4+V6 (double stack) situation. And ping -6 will not work.

If you want to use IPV6 also within your LAN, *or even just to test IPv6 connectivity*, you must configure your Networks in the UI (at least the Default Network) with `IPv6 Interface Type` set to `Prefix Delegation` instead of None.

> **Warning** 
> As a first step I strongly suggest to only change the Default Network and leave unchecked `Router Advertisment (RA)` (**disabled**)

Then, after a few seconds, you can check if the main bridge (br0) got an IPv6 address, and test WAN IPv6 connectivity from the UDR/UDM :

```console
# ip -6 addr show scope global dynamic
47: br0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP qlen 1000
    inet6 2a01:xxxx:xxx:xxxx::1/64 scope global dynamic
       valid_lft 541988sec preferred_lft 541988sec
# ping -6 google.com
PING google.com(par10s22-in-x0e.1e100.net (2a00:1450:4007:80e::200e)) 56 data bytes
64 bytes from par10s22-in-x0e.1e100.net (2a00:1450:4007:80e::200e): icmp_seq=1 ttl=117 time=2.38 ms
(...)
# curl -6 ipv6.google.com -I
HTTP/1.1 200 OK
(...)
```

&nbsp;  
&nbsp;  

<a id="activate_ipv6_lan"></a>

### [OPTIONAL] Fully activate IPV6 on your LAN (Router Advertisment)

In the previous section, you already have set `IPv6 Interface Type` to `Prefix Delegation`, but with RA disabled, and you could validate the WAN IPv6 connectivity.

Next, you can *optionnaly* check `Router Advertisment (RA)` (Enabled) for some Network(s) when you want to let devices dynamically get IPv6 addresses.

> **Note** This can lead to issues in some use cases, depending on your LAN and WLAN devices configurations...you'll have to carefully test everything.

![IPv6 LAN settings](images/IPV6_LAN_settings.png#gh-dark-mode-only)
![IPv6 LAN settings](images/IPV6_LAN_settings_light.png#gh-light-mode-only)

&nbsp;  
&nbsp;

<a id="force_firmware_update_in_V4"></a>

### Note about avoiding Unifi firmware IPV6 download endpoints not reachable
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;  

When you update your applications from Unifi UI, `wget` commands are launched in the background, to download the new firmware binaries.

Unfortunately, as of July 2023 at least, the IPV6 endpoints of `fw-download.ubnt.com` are unreachable.
And, as Unifi does not use `wget` options like `--connect-timeout=01` or the `--prefer-family=IPv4`, the default is to try the first adress returned by the DNS resolver, which is IPV6 in our case, and never timeout.

So we need to use the `.wgetrc` file to change the default behaviour of `wget` commands (until Unifi does something)

(NOTE : if you used the `install-dhcpv6-mod.sh` script to install, as you should have, then it's already done for you, this is for information or check)

```bash
grep -sq '^prefer-family' /root/.wgetrc || echo 'prefer-family = IPv4' >> /root/.wgetrc
```

&nbsp;  
&nbsp;  

<a id="rollback"></a>

## Rollback (if needed)
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;  

In the UI, go to Network > Settings > Internet > Primary (WAN1), and set "IPv6 Connection" to "Disabled" (instead of DHCPv6).

Do the same with any Network for which you have enabled "IPv6 Interface Type" to any other than "Disabled". 

Then, the odhcp6c process should stop within a few seconds.

Also deactivate IPv6 in LAN if you have set that.

You can reactivate it later by changing the same setting to "DHCPv6". 
