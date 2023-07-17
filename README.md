# dhcpv6-mod

This project enables Unifi UDM/UDR to provide required DHCP V6 client options to ISPs (like Orange France), including by extracting values from V4 DHCP client options  you've already set in Unifi UI.

This mod was developed because there's no way to configure DHCP v6 client options in the WAN section of Unifi's UI. It should work on any UDM/UDMPro/UDR with at least UnifiOS 2.4.x (3.x is recommended as I can no longer test in 2.x).

&nbsp;

> **NEW**:
> If you're not using Orange France ISP, it's now possible to configure your own DHCPv6 options (see the [Initialize DHCPv6 config file](#configure_dhcpv6) section).

&nbsp;


> **WARNING**:
> For existing users, after any update of this repo <u>or of your config file</u>, please don't forget to run the `./install-dhcpv6-mod.sh` command again (see [Install or update dhcpv6-mod](#install_dhcpv6_mod)).

&nbsp;

In addition, it is highly recommended that you install the `udm-boot` package included in this repo, so that the mod will be automaticaly re-applied after a reboot, even after Unifi OS firmware updates.
&nbsp;  
&nbsp;  


## Table of Contents

- [How does it work ?](#how_does_it_work)
- [Build a odhcp6c supporting CoS](#build_odhcp6c)
- [Download dhcpv6-mod files](#download_dhcpv6_mod)
- [Initialize DHCPv6 config file](#configure_dhcpv6)
- [Install (or update) dhcpv6-mod](#install_dhcpv6_mod)
- [Activate DHCPv6 WAN client](#activate_dhcpv6)
- [Install udm-boot package](#install_udm_boot)
- [Rollback (if needed)](#rollback)
&nbsp;  
&nbsp;  

<a id="how_does_it_work"></a>

## How does it work ?
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

As a prerequisite, you must have entered the needed DHCP V4 WAN options (for Orange : 60, 61, 77 and 90), using Unifi's GUI WAN1 settings, as they are needed to generate V6 options. 

Then :
- From the UDR/UDM shell prompt, build a more recent version of `odhcp6c` (from [openwrt repo](https://github.com/openwrt/odhcp6c)) that has the `-K` option in order to pass a CoS for DHCP requests
- Replace Unifi's `/usr/sbin/odhcp6c` by our own shell script `odhcp6c.sh`, which will :
  - fetch the DHCPv4 options values from `ubios-udapi-server` state file
  - prepare the DHCPv6 options with needed prefixes and formats, according to a customizable configuration file 
  - finally, `exec` the new `/data/local/bin/odhcp6c` (the one we just built), with all the adequate options
- In addition, install our own `udm-boot` Debian package (and systemd service) that will re-apply dhcpv6-mod even after a Unifi OS firmware update 

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

[OPTIONAL] You can delete the source code (not needed for our purpose) :
```bash
rm -rf /root/odhcp6c
```

&nbsp;  
&nbsp;  

<a id="download_dhcpv6_mod"></a>

## Download dhcpv6-mod files
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;  

Install the repo files in the `/data/dhcpv6-mod` directory (/data is persisted after reboots/upgrades).

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

NOTE : the command will initially create the `/data/local/etc/dhcpv6.conf` configuration file <u>ONLY if it does not already exist</u>, using the `dhcpv6-orange.conf` file content.

In fact, the `./install-dhcpv6-mod.sh` command can be run at any time : it will only update `/usr/sbin/odhcp6c` with a new version of `odhcp6c.sh` if one of the following is true :
- file `/usr/sbin/odhcp6c` is older than `odhcp6c.sh` 
- process `odhcp6c` is older than `odhcp6c.sh` or `dhcpv6.conf`

If the script does in fact need to change something, and if DHCPv6 client was already running, it will finish by a restart of both DHCP v4 and v6 clients. This will simply launch a discover phase for both (V4/V6 consistency is needed by Orange), without interrupting the WAN connection. 

You can check the log generated by the restart of both DHCP clients (if this was the case), with :
```bash
grep -E 'dhcpc|odhcp6c|dhcpv6-mod' /var/log/daemon.log 
```
And of course check the WAN connection via ping or other.

&nbsp;  
&nbsp;  


<a id="activate_dhcpv6"></a>

## Activate and test DHCP V6 client for WAN for the first time
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;  

In the UI, go to Network > Settings > Internet > Primary (WAN1)

You must already have set VLAN ID (832 for Orange), DHCP client options (V4) 60/77/90, DHCP CoS 6.

Now you need to set "IPv6 Connection" to "DHCPv6" (instead of Disabled) and "Prefix Delegation Size" to 56 (instead of 64), like so :

![IPv6 WAN settings](https://github.com/fgero/dhcpv6-mod/blob/main/images/IPV6_WAN_settings.png#gh-dark-mode-only)
![IPv6 WAN settings](https://github.com/fgero/dhcpv6-mod/blob/main/images/IPV6_WAN_settings_light.png#gh-light-mode-only)

Then, the ubios-udapi-server process should fork, in addition to udhcpc (V4 client), a new process running our own odhcp6c with all the parameters passed, like so :

```console
# ps -ef | grep dhcp
root     2574251    4134  0 Jun18 ?        00:00:00 /usr/bin/busybox-legacy/udhcpc --foreground --interface eth4.832 --script /usr/share/ubios-udapi-server/ubios-udhcpc-script --decline-script /usr/share/ubios-udapi-server/ubios-udhcpc-decline-script -r <publicIPv4> -y 6 --vendorclass sagem -x 77:<userclass_hex> -x 90:<auth>
root     2574252    4134  0 Jun18 ?        00:00:00 /data/local/bin/odhcp6c -a -f -K6 -R -r11,17,23,24 -V <pfx+vendorclass> -c <pfx+clientid> -u <userclass_string> -x 11:<auth> -v -s /usr/share/ubios-udapi-server/ubios-odhcp6c-script -D -P 56 eth4.832
```

You can check the DHCP V6 discover process and lease in the system log :

```console
# grep -E 'dhcpc|odhcp6c|dhcpv6-mod' /var/log/daemon.log
(....below some extracts, you'll get more....)
2023-06-18T17:01:51+02:00 UDR odhcp6c[2574252]: Starting SOLICIT transaction (timeout 4294967295s, max rc 0)
2023-06-18T17:01:51+02:00 UDR odhcp6c[2574252]: Got a valid ADVERTISE after 10ms
2023-06-18T17:01:51+02:00 UDR odhcp6c[2574252]: IA_PD 0001 T1 87555 T2 483840
2023-06-18T17:01:51+02:00 UDR odhcp6c[2574252]: 2a01:xxxx:xxx:xxxx::/56 preferred 604800 valid 604800
2023-06-18T17:01:52+02:00 UDR odhcp6c[2574252]: Starting REQUEST transaction (timeout 4294967295s, max rc 10)
2023-06-18T17:01:52+02:00 UDR odhcp6c[2574252]: Send REQUEST message (elapsed 0ms, rc 0)
2023-06-18T17:01:52+02:00 UDR odhcp6c[2574252]: Got a valid REPLY after 231ms
2023-06-18T17:01:52+02:00 UDR odhcp6c[2574252]: IA_PD 0001 T1 87555 T2 483840
2023-06-18T17:01:52+02:00 UDR odhcp6c[2574252]: 2a01:xxxx:xxx:xxxx::/56 preferred 604800 valid 604800
2023-06-18T17:01:52+02:00 UDR odhcp6c[2574252]: T1 87555s, T2 483840s, T3 604800s
2023-06-18T17:01:52+02:00 UDR odhcp6c[2574252]: entering stateful-mode on eth4.832
2023-06-18T17:01:52+02:00 UDR odhcp6c[2574252]: Starting <POLL> transaction (timeout 87555s, max rc 0)
(...)
2023-06-18T17:02:04+02:00 UDR ubios-udapi-server[2574251]: udhcpc: broadcasting select for 90.XX.XX.XXX, server 80.10.239.9
2023-06-18T17:02:04+02:00 UDR ubios-udapi-server[2574251]: udhcpc: lease of 90.XX.XX.XXX obtained from 80.10.239.9, lease time 604800
(...)
```

Here you asked and got a /56 prefix (7 bytes), like [2a01:xxxx:xxx:xx](#)00:, and the 8th byte (00) is reserved by your router/box, you can use 01 to FF (254 subnets of /64) 

If this does not work, you can try to reset both DHCP v4 and v6 sequences :

```bash
killall udhcpc odhcp6c 
# wait a few seconds
grep -E 'dhcpc|odhcp6c|dhcpv6-mod' /var/log/daemon.log
```

If you need to only check the log generated by odhcp6c.sh, in order to see DHCPv6 option generation :
```bash
grep dhcpv6-mod /var/log/daemon.log 
```

Even after getting a V6 lease, your WAN interface will not get a public IPV6 address, this is expected (apparently) in a V4+V6 (double stack) situation.

[OPTIONAL] If you want to use IPV6 also within your LAN, you must configure one of your Networks in the UI, with IPv6 Interace Type set to "Prefix Delegation", RA enabled, et leave the rest as default.

![IPv6 LAN settings](https://github.com/fgero/dhcpv6-mod/blob/main/images/IPV6_LAN_settings.png#gh-dark-mode-only)
![IPv6 LAN settings](https://github.com/fgero/dhcpv6-mod/blob/main/images/IPV6_LAN_settings_light.png#gh-light-mode-only)

&nbsp;  
&nbsp;  

<a id="install_udm_boot"></a>

## Install udm-boot
<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;  

It the V6 lease is OK, then you must ensure that our odhcp6c hack is maintained even after a reboot.
You could do that using [these instructions](https://github.com/unifi-utilities/unifios-utilities/tree/main/on-boot-script-2.x#manually-install-steps), from the official unifios-utilities repo, but this does not survive a firmware update (see issue [#1](https://github.com/fgero/dhcpv6-mod/issues/1)).

So I would suggest to use our own installation script :

```bash
cd /data/dhcpv6-mod/udm-boot
./install_udm_boot.sh
```

This will add the `udm-boot` package (provided as a `.deb` file in this repo) to the `ubnt-dpkg-cache` facility, so that it is restored if missing after a firmware update reboot.
The package itself, when installed, puts the `udm-boot.service` file in `/lib/systemd/system/udm-boot.service` and enable+start the udm-boot service with systemctl.

Then you can add ".sh" files in the `/data/on_boot.d/` directory so that they are executed at boot (for dhcpv6-mod purposes or any other...).

In our case, we need to replace at each reboot the old /usr/sbin/odhcp6c executable (that is automatically restored by Unifi each time) by our dhcpv6-mod script. 

For that, we need to create a symlink `05-replace-odhcp6c.sh` pointing to the real script in `udm-boot/` :

```bash
mkdir -p /data/on_boot.d
ln -fs /data/dhcpv6-mod/udm-boot/05-replace-odhcp6c.sh /data/on_boot.d/05-replace-odhcp6c.sh
```


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

In the UI, go to Network > Settings > Internet > Primary (WAN1)
Set "IPv6 Connection" to "Disabled" (instead of DHCPv6)

Then, the odhcp6c process should stop within a few seconds.

Also deactivate IPv6 in LAN if you have set that.

You can reactivate it later by changing the same setting to "DHCPv6". 
