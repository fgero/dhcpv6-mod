# dhcpv6-mod

<p align="left">
  <em><b>dhcpv6-mod</b> enables Unifi Gateways (UDMs, UDR, UCGs) to provide DHCP V6 client options required by some ISPs (e.g. Orange France), in order to activate both IPv4 and IPv6 WAN access.</em>
</p>

---

### ⚠️ **Attention**

You need <u>**UnifiOS 3.2.9 at least**</u> to use dhcpv6-mod (4.x is recommended as I can no longer test in v3).

---

This mod generates DHCPv6 options by extracting values from the V4 DHCP client options you've already set in Unifi Network UI.

This is needed because there's no way to configure required DHCP V6 client options in the WAN section, so they need to be generated otherwise.

UnifiOS 3.2.9 (or newer) is required, as this version brings the `-K` (CoS) option of `odhcp6c`.
Also, you need SSH access to your Unifi router root account.

If you don't want dhcpv6-mod's default DHCPv6 options (Orange France specific), you can configure your own (see the [Initialize DHCPv6 config file](#configure_dhcpv6) section).

&nbsp;

> **Warning**
> After any non-documentation commit of this repository, or if you update your config file, or after a firmware update reboot, don't forget to run the `./install-dhcpv6-mod.sh` command again (see [Install or update dhcpv6-mod](#install_dhcpv6_mod)).
> &nbsp;

&nbsp;
&nbsp;

## Table of Contents

- [How does it work ?](#how_does_it_work)
- [Download dhcpv6-mod files](#download_dhcpv6_mod)
- [Initialize DHCPv6 config file](#configure_dhcpv6)
- [Install (or update) dhcpv6-mod](#install_dhcpv6_mod)
- [Activate DHCPv6 WAN client](#activate_dhcpv6)
- [Check IPv6 lease and connectivity](#check_ipv6)
- [Uninstalling dhcpv6-mod](#rollback)
  &nbsp;  
  &nbsp;

<a id="how_does_it_work"></a>

## How does it work ?

<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

As a <b>prerequisite</b>, you must have entered all the DHCP V4 WAN options required by your ISP, using Unifi's Network application GUI WAN1 settings, as they are needed to generate V6 options.
This means that your IPv4-only WAN access must already work.

The installation of this mod will rename Unifi's `/usr/sbin/odhcp6c` as `/usr/sbin/odhcp6c-org`, and replace the former by our own shell script (`odhcp6c.sh` of this repo).

The new `/usr/sbin/odhcp6c` will :

- Fetch the active DHCPv4 options values from `ubios-udapi-server` state file
- Prepare the DHCPv6 options with required formats, customizable via configuration file `/data/local/etc/dhcpv6.conf`
- Finally, `exec` Unifi's original `odhcp6c-org` with all the DHCPv6 options we prepared

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

If you are using Orange France ISP, then you may skip this section and move to the next one ([Install/update dhcpv6-mod files](#install_dhcpv6_mod)), as the installation script will create the `/data/local/etc/dhcpv6.conf` config file for you, with Orange settings by default.

If you are NOT using Orange France ISP, the first time you install `dhcpv6-mod`, you must create and customize the `/data/local/etc/dhcpv6.conf` file yourself before moving to the next section (installation), which will not overwrite it.

Please read the [CONFIGURE.md](docs/CONFIGURE.md) documentation page, which describes how to create your own config file.

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

<details close><summary><code>Expected output</code> (click to expand)</summary><br/>

```console
root@UCG-Max:/data/dhcpv6-mod# ./install-dhcpv6-mod.sh
[install-dhcpv6-mod] copied dhcpv6-orange.conf default config to /data/local/etc/dhcpv6.conf
[install-dhcpv6-mod] /usr/sbin/odhcp6c detected as an original Unifi executable, we can rename it
[install-dhcpv6-mod] /usr/sbin/odhcp6c renamed /usr/sbin/odhcp6c-org
[install-dhcpv6-mod] /usr/sbin/odhcp6c now replaced by ./odhcp6c.sh
[restart-dhcp-clients] Restarting DHCPv4 (udhcpc) and DHCPv6 (odhcp6c) clients to take updates into account
[restart-dhcp-clients] (this will initiate a DHCPv4+v6 Discover process, and should not interrupt your connection...)
[restart-dhcp-clients] Restart done, you can now check dhcp client logs with :
grep -E 'dhcpc|odhcp6c|dhcpv6-mod' /var/log/daemon.log
```

</details><br>

This command must be issued :

- when installing `dhcpv6-mod` for the first time, of course
- when `dhcpv6-mod` repository gets an update commit (except when the update is documentation-only)
- when you update your own configuration file (`/data/local/etc/dhcpv6.conf`)
- after a **firmware update reboot** (i.e. Unifi OS update)

Conversely, running `install-dhcpv6-mod.sh` is NOT needed after a "normal" reboot, as dhcpv6-mod is not removed in that situation.

> **Note** During the first installation, `install-dhcpv6-mod.sh` will create the `/data/local/etc/dhcpv6.conf` configuration file <u>ONLY</u> if it doesn't already exist, using this repo's `dhcpv6-orange.conf` file.

In fact, the `./install-dhcpv6-mod.sh` command can be run at any time : it will only update `/usr/sbin/odhcp6c` with a new version of `odhcp6c.sh` if needed (`/usr/sbin/odhcp6c` older than `odhcp6c.sh`).

In addition, if `/usr/sbin/odhcp6c` has been updated OR if your config file is newer than the running `odhcp6c` process then the script will finish by calling `./restart-dhcp-clients.sh`.

The `./restart-dhcp-clients.sh` script, that can also be called manually, will restart both DHCP v4 and v6 clients (full DHCP discover sequence for both, without interrupting the WAN connection). In that case, it is advisable to check WAN access and in particular [Check IPv6 lease and connectivity](#check_ipv6)

&nbsp;  
&nbsp;

<a id="activate_dhcpv6"></a>

## Activate DHCP V6 WAN client for the first time

<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

In the UI, go to Network > Settings > Internet > click on Primary (WAN1)

For <b>Orange</b>, you must already have set VLAN ID (832), MAC Adress clone of your Livebox, DHCP client options (V4) 60/77/90, and DHCP CoS 6.<br>
In any case, you must have a working WAN IPv4 connection, with all required options set in the UI.

Next, you need to set `IPv6 Connection` to `DHCPv6` (instead of Disabled) and `Prefix Delegation Size` to `56` (instead of 64), like so :

![IPv6 WAN settings](images/IPV6_WAN_settings.png#gh-dark-mode-only)
![IPv6 WAN settings](images/IPV6_WAN_settings_light.png#gh-light-mode-only)

Then, the `ubios-udapi-server` process should fork, in addition to `udhcpc` (V4 client), a new process running our own `odhcp6c` (which will exec `/usr/sbin/odhcp6c-org`), with all the V6 parameters passed, like so :

```console
# ps -ef | grep dhcp
root     2574251    4134  0 Jun18 ?        00:00:00 /usr/bin/busybox-legacy/udhcpc --foreground --interface eth4.832 --script /usr/share/ubios-udapi-server/ubios-udhcpc-script --decline-script /usr/share/ubios-udapi-server/ubios-udhcpc-decline-script -r <publicIPv4> -y 6 --vendorclass sagem -x 77:<userclass_hex> -x 90:<auth>
root     2574252    4134  0 Jun18 ?        00:00:00 /usr/sbin/odhcp6c-org -a -f -K6 -R -r11,17,23,24 -V <pfx+vendorclass> -c <pfx+clientid> -u <userclass_string> -x 11:<auth> -v -s /usr/share/ubios-udapi-server/ubios-odhcp6c-script -D -P 56 eth4.832
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
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Selected DHCPv6 client executable (with support for CoS) : /usr/sbin/odhcp6c-org
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
2023-07-17T15:45:27+02:00 UDR ubios-udapi-server[3018622]: [dhcpv6-mod] Launching exec /usr/sbin/odhcp6c-org -a -f -R -r17,23,24 -K6 -c 0003...xxxx -x 11:00000...xxxxx -u FSVDS...ebox3 -V 00000...7656D  -v -s /usr/share/ubios-udapi-server/ubios-odhcp6c-script -D -P 56 eth4.832
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

In that output, valid for Orange, we can see that you asked and got a /56 prefix (7 bytes), like [2a01:xxxx:xxx:xx](#)00:, and the 8th byte (00) is reserved by your router/box, you can use 01 to FF (254 subnets of /64)

If this does not work, you can try to reset again both DHCP v4 and v6 sequences :

```bash
./restart-dhcp-clients.sh
```

Explanation : this scripts sends a SIGUSR2 to `udhcpc` to force a DHCPv4 RELEASE, as Unifi does not set the -R option to do that before stopping. Then it sends a SIGTERM to both `udhcpc` and `odhcp6c`, so both process will stop (`odhcp6c` will perform a RELEASE before) and immediately be restarted by `ubios-udapi-server`, starting a full DISCOVER sequence for V4 and V6.

Then we can look at the result a few seconds later :

```bash
grep -E 'dhcpc|odhcp6c|dhcpv6-mod' /var/log/daemon.log
```

If you just need to check the log generated by odhcp6c.sh, in order to see DHCPv6 option generation :

```bash
grep dhcpv6-mod /var/log/daemon.log
```

&nbsp;

Even after getting a V6 lease, your WAN interface will not get a public IPV6 address, this is expected (apparently) in a V4+V6 (double stack) situation. And ping -6 will not work unless you do the following :

If you want to use IPV6 also within your LAN, _or even just to test IPv6 connectivity_, you must configure your Networks in the UI (at least the Default Network) with `IPv6 Interface Type` set to `Prefix Delegation` instead of None.

> **Warning**
> As a first step I strongly suggest to only change the Default Network and leave unchecked `Router Advertisment (RA)` (ie. disabled), this is probably safer

Then, if you do that, after a few seconds, you can check if the main bridge (br0) got an IPv6 address, and test WAN IPv6 connectivity from the UDR/UDM :

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

Next, you can _optionnaly_ check `Router Advertisment (RA)` (so enable RA) for some Network(s) when you want devices to dynamically get IPv6 addresses.

> **Note** This can lead to issues in some use cases, depending on your LAN and WLAN devices configurations...you'll have to carefully test everything.

Go to Network > Settings > Networks > Choose one > click "IPv6" switch, then :

![IPv6 LAN settings](images/IPV6_LAN_settings.jpg#gh-dark-mode-only)
![IPv6 LAN settings](images/IPV6_LAN_settings_light.jpg#gh-light-mode-only)

&nbsp;  
&nbsp;

<a id="force_firmware_update_in_V4"></a>

### Note about avoiding Unifi firmware IPV6 download endpoints not reachable

<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

When you update your applications from Unifi UI, `wget` commands are launched in the background, to download the new firmware binaries.

Unfortunately, as of July 2023 at least, Unifi's IPV6 endpoints for `fw-download.ubnt.com` are unreachable.
And, as Unifi does not use `wget` options like `--connect-timeout=10` or the `--prefer-family=IPv4`, the default is to try the first adress returned by the DNS resolver, which is IPV6 in our case, and this will wait forever and not perform the desired update

So we need to use the `.wgetrc` file to change the default behaviour of `wget` commands (until Unifi does something)

> **Note**
> If you used the `install-dhcpv6-mod.sh` script to install, as you should have, then the fix is already done for you, this is for information or check)

```bash
grep -sq '^prefer-family' /root/.wgetrc || echo 'prefer-family = IPv4' >> /root/.wgetrc
```

&nbsp;  
&nbsp;

<a id="rollback"></a>

## Uninstalling dhcpv6-mod

<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

#### How to uninstall dhcpv6-mod

You just have to restore Unifi /usr/sbin/odhcp6c original binary, like so :

`mv /usr/sbin/odhcp6c-org /usr/sbin/odhcp6c`

and then restart the clients :

`./restart-dhcp-clients.sh`

#### How to disable IPv6

In the UI, go to Network > Settings > Internet > Primary (WAN1), and set "IPv6 Connection" to "Disabled" (instead of DHCPv6).

Do the same with any Network for which you have enabled "IPv6 Interface Type" to any other than "Disabled".

Then, the odhcp6c process should stop within a few seconds.

You can reactivate it later by changing the same setting to "DHCPv6".
