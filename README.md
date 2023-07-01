# dhcpv6-mod

*Last update: July 1, 2023*

NOTE : please run the newly provided `./install_udm_boot.sh` if you want to keep the DHCPv6 mod even after a Unifi OS firmware update, without having to `dpkg -i` again the deb package, see issue #1 and the [Install udm-boot](#Install-udm-boot) section below.

## Features

Enable Unifi UDM/UDR Unifi DHCP V6 client to pass options to ISPs like Orange, by extracting values from V4 DHCP client options.

Keep the mod even after a reboot, although in the case of a Unifi OS firmware update, currently, we need to pass a manual command after the reboot.

This mod is needed as there is no possibility to configure DHCP v6 client options in the WAN section of Unifi's GUI.

Here are the 4 DHCP options that are propagated from V4 to V6 with needed transformations (headers from RFC8415 for opt 16 and 1) : 


| Name 	| Opt V4    | Opt V6 	| Header V6 | Value (from V4)   | Example of odhcp6c argument    |
|------	|-------  |-------	|---------- |----------------   |------------------ |
| [Vendor class](https://www.rfc-editor.org/rfc/rfc3315.html#section-22.16) | 60    | 16  | [0000040E 0005](#) (4-byte IANA enterprise# + 2-byte length)  | Vendor class string in hex    | -V [000000040E0005](#)736167656D (here 5 bytes ASCII hex code for 'sagem')    |
| [Client identifier](https://www.rfc-editor.org/rfc/rfc8415.html#page-99) | 61    | 1  | [0003 0001](#) (DUID type LL + hw type ethernet    | Mac Address Clone (UI)  | -c [00030001](#)xxxxxxxxxxxx (6 bytes in hex for cloned macaddr)    |
| [User class](https://www.rfc-editor.org/rfc/rfc8415.html#page-115) | 77    | 15   | None, because -u already adds 2-byte length field (e.g. 002B)    | When using -u, pass a string (not hexstring)  | -u FSVDSL_livebox.Internet.softathome.LiveboxN (here 43 or 0x2b bytes as hexstring)   |
| [Authentication](https://www.rfc-editor.org/rfc/rfc8415.html#section-21.11) | 90    | 11   | None    | Authentication in hexstring (same as V4 opt 90 without ':')  | -x 11:00....xx (70 bytes in hexstring for auth)    |


## How does it work ?

- Build a more recent version of `odhcp6c` that has the `-K` option in order to pass a CoS for DHCP requests
- Save and replace Unifi's `/usr/sbin/odhcp6c` (an old version without the '-K' option) by our own shell script `odhcp6c.sh`
- This shell script will calculate the V6 options by fetching the V4 ones, and then `exec` the new `/data/local/bin/odhcp6c` we just built.


## Compatibility

Should work on any UDM/UDMPro/UDR after 2.4.x


## Download dhcpv6-mod files

You can either :

download the files in the `/data/dhcpv6-mod` directory :

```bash
cd /data
curl -sL https://github.com/fgero/dhcpv6-mod/archive/refs/heads/main.tar.gz | tar -xvz
mv dhcpv6-mod-main dhcpv6-mod
```

...or, alternatively, if you want to use git :
```bash
cd /data
git clone https://github.com/fgero/dhcpv6-mod.git
```

## On the UDM/UDR, build a recent version of odhcp6c from openwrt git repo

First (if not already done), install git and cmake on the UDM/UDR :

```bash
apt-get install -y git cmake
```

Then make the odhcp6c executable locally (here in root's home directory) :

```bash
cd
git clone https://github.com/openwrt/odhcp6c.git
cd odhcp6c
cmake .
make
mkdir -p /data/local/bin
cp -p odhcp6c /data/local/bin
# then optionaly delete the source code (rm -rf /root/odhcp6c)
```

## Install dhcpv6-mod files

Now we can save and replace Unifi's `/usr/sbin/odhcp6c` by our own shell script `odhcp6c.sh` (that will prepare V6 args and exec the new odhcp6c exec we just built) :
 
```bash
cd /data/dhcpv6-mod
chmod +x *.sh
mv /usr/sbin/odhcp6c /usr/sbin/odhcp6c-org
cp -p odhcp6c.sh /usr/sbin/odhcp6c
```

## Activate and test DHCP V6 client for WAN (in addition to DHCP V4)

In the UI, go to Network > Settings > Internet > Primary (WAN1)

You must already have set VLAN ID (832 for Orange), DHCP client options (V4) 60/77/90, DHCP CoS 6.

Now you need to set "IPv6 Connection" to "DHCPv6" (instead of Disabled) and "Prefix Delegation Size" to 56 (instead of 64), like so :

![IPv6 WAN settings](https://github.com/fgero/dhcpv6-mod/blob/main/IPV6_WAN_settings.png?raw=true)


Then, the ubios-udapi-server process should fork, in addition to udhcpc (V4 client), a new process running our own odhcp6c with all the parameters passed, like so :

```console
# ps -ef | grep dhcp
root     2574251    4134  0 Jun18 ?        00:00:00 /usr/bin/busybox-legacy/udhcpc --foreground --interface eth4.832 --script /usr/share/ubios-udapi-server/ubios-udhcpc-script --decline-script /usr/share/ubios-udapi-server/ubios-udhcpc-decline-script -r <publicIPv4> -y 6 --vendorclass sagem -x 77:<userclass_hex> -x 90:<auth>
root     2574252    4134  0 Jun18 ?        00:00:00 /data/local/bin/odhcp6c -a -f -K6 -R -r11,17,23,24 -V <pfx+vendorclass> -c <pfx+clientid> -u <userclass_string> -x 11:<auth> -v -s /usr/share/ubios-udapi-server/ubios-odhcp6c-script -D -P 56 eth4.832
```

You can check the DHCP discover & lease in the system log :

```console
# grep -e dhcpc -e odhcp6c /var/log/daemon.log
(...)
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

If this does not work, you can try to reset both DHCP v4 and v6 sequences (apparently Orange wants that):

```bash
killall udhcpc odhcp6c 
```

Even after getting a V6 lease, your WAN interface will not get a public IPV6 address, this is expected (apparently) in a V4+V6 (double stack) situation.

Optionaly, if you want to use IPV6 also within your LAN, you must configure one of your Networks in the UI, with IPv6 Interace Type set to "Prefix Delegation", RA enabled, et leave the rest as default.


## Install udm-boot

It the V6 lease is OK, then you must ensure that our odhcp6c hack is maintained even after a reboot.
You can do that using [these instructions](https://github.com/unifi-utilities/unifios-utilities/tree/main/on-boot-script-2.x#manually-install-steps), from the unifios-utilities repo, but this does not survive a firmware update (see issue #1).

So I would suggest to do simply this :

```bash
cd /data/dhcpv6-mod
./install_udm_boot.sh
```

This will add the `udm-boot` package (provided as a `.deb` file in this repo) to the `ubnt-dpkg-cache` facility, so that it is restored if missing after a firmware update reboot.
The package itself, when installed, puts the `udm-boot.service` file in `/lib/systemd/system/udm-boot.service` and enable+start the udm-boot service with systemctl.

Then you can add ".sh" files in the `/data/on_boot.d/` directory so that they are executed at boot.

In our case, we need to replace at each reboot the /usr/sbin/odhcp6c executable (that is automatically restored by Unifi each time) by our script. For that we must copy the `05-replace-odhcp6c.sh` script :

```bash
cd /data/dhcpv6-mod
chmod +x *.sh
cp -p 05-replace-odhcp6c.sh /data/on_boot.d
```

## Avoiding Unifi firmware download endpoints not reachable in IPV6

When you update your applications from Unifi UI, `wget` commands are lauched in order to download the new firmware binaries.

Unfortunately, right now at least, the IPV6 endpoints of `fw-download.ubnt.com` are unreachable.
And, as Unifi does not use `wget` options like `--connect-timeout=01` or the `--prefer-family=IPv4`, the default is to try the first adress returned by the DNS resolver (which is IPV6) and never timeout.

So we need to use the `.wgetrc` file to change the default behaviour of `wget` commands (until Unifi does something)

```bash
grep -sq '^prefer-family' /root/.wgetrc || echo 'prefer-family = IPv4' >> /root/.wgetrc
```

## Rollback (if needed)

In the UI, go to Network > Settings > Internet > Primary (WAN1)
Set "IPv6 Connection" to "Disabled" (instead of DHCPv6)
The odhcp6c process should stop within a few seconds.

You can reactivate it later by changing the same setting to "DHCPv6". 
