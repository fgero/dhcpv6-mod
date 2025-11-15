# How to use (or move to) the new DHCP v6 settings of Unifi OS 4.4+

&nbsp;

### Case 1 : you are not yet in Unifi OS 4.4 and you are running dhcpv6-mod

Then you won't have to uninstall `dhcpv6-mod` because, as documented, it is automatically removed after each Unifi OS upgrade.

So the steps are :

- Upgrade to Unifi OS 4.4+, do NOT re-install `dhcpv6-mod` after the reboot
- Follow the guide below to set the DHCPv6 options of your WAN connection, using Unifi's new dialog
- Hit the "Apply Changes" button, and wait for your V6 connection to start
- Forget about this mod, you don't need it anymore

&nbsp;

### Case 2 : you already are in Unifi OS 4.4+ and you are running dhcpv6-mod

Then you will have to uninstall `dhcpv6-mod`, ideally just before you hit "Apply Changes" for the DHCPv6 settings in Unifi's UI.

So the steps are :

- Follow the guide below to set the DHCPv6 options of your WAN connection, using Unifi's new dialog, do not immediately hit Apply
- Uninstall `dhcpv6-mod` just by running `mv /usr/sbin/odhcp6c-org /usr/sbin/odhcp6c` (it's also suggested in the guide below)
- Hit the "Apply Changes" button, and wait for your V6 connection to start
- If the connection doesn't work after a few minutes, try running `/data/dhcpv6-mod/restart-dhcp-clients.sh`
- Forget about this mod, you don't need it anymore

&nbsp;

## How to set the DHCPv6 options using UnifiOS 4.4+ UI

As always, I'm assuming that you have already entered the DHCP v4 options of your WAN interface in Unifi's UI (otherwise you have never used dhcpv6-mod...)

Go to "Settings" (the Cog icon, at the bottom left part of Unifi OS UI)
Then select "Internet", and then the WAN connection (like "Internet 1"/"WAN 1")

You should have something like this, with a working IPv4 Configuration :

![Unifi OS 4.4 IPv4 settings](../images/OS44_IPV4_WAN_settings.png#gh-dark-mode-only)
![Unifi OS 4.4 IPv4 settings](../images/OS44_IPV4_WAN_settings_light.png#gh-light-mode-only)

Scroll down until you see both "IPv4 Configuration" and "IPv6 Configuration" sections

Change the `IPv6 Connection` setting from `Disabled` to `DHCPv6`.

Enter the `DHCPv6 Client Options` like below (this is for Orange Livebox, please adapt to your specific case if needed), using `Option` and `Value` fields and the `Àdd` button :

- set DHCPv6 option 1 to something like `00:03:00:01:aa:bb:cc:dd:ee:ff`, where `00:03:00:01:` is fixed and `aa:bb:cc:dd:ee:ff` is exactly what you have entered in the `Mac Address Clone` setting, above the IPv4 section
- set DHCPv6 option 11 to what you have entered in DHCPv4 option 90 **BUT without any ':'** so it should be like 00000000... (not 00:00:00:00:...)
- set DHCPv6 option 15 to the exact same value as DHCPv4 option 77
- set DHCPv6 option 16 to a value derived from DHCPv4 option 60 (which is probably be `sagem`) : start with fixed prefix `0000040E`, then add `0005` (length of the string "sagem"), then add `736167656D` (5-byte ASCII for "sagem") --> so finally enter `0000040E0005736167656D` for DHCPv6 option 16 if DHCPv4 option 60 is `sagem`

&nbsp;

Then set `DHCPv6 COS` to `6` (just below the option table section)

Then set `Prefix Delegation Size` to `56` (uncheck `Auto`)

For the `DNS server`, repeat what you've set for the same DHCPv4 option (for me it's `Auto`, but in your case it could be specific servers)

Now, the V4 and V6 options should look like this :

![Unifi OS 4.4 IPv4v6 settings](../images/OS44_IPV4V6_WAN_settings.png#gh-dark-mode-only)
![Unifi OS 4.4 IPv4v6 settings](../images/OS44_IPV4V6_WAN_settings_light.png#gh-light-mode-only)

---

**IF YOU HAVE INSTALLED dhcpv6-mod AFTER THE UNIFI OS 4.4+ INSTALL REBOOT**

do NOT yet hit the "Apply Changes" button, you need to uninstall the mod first :

```bash
# If you have dhcpv6-mod running, uninstall it :
mv /usr/sbin/odhcp6c-org /usr/sbin/odhcp6c
```

(of course you don't need to do that if you haven't re-installed dhcpv6-mod in 4.4+ - anyway, even if you try the "mv" command, it will fail without harm as the -org executable does not exist)

---

&nbsp;

Then, hit "Apply Changes", now Unifi OS should try to start the `odhcp6c`daemon to negociate IPv6 with your ISP with the options you just set.

Wait for your V6 connection to come up...

You can dig into the logs like that :

```bash
grep -E 'dhcpc|odhcp6c' /var/log/daemon.log
```

If the V6 connection doesn't work within a few minutes, and you had dhcpv6-mod previously installed, this can greatly help :

```bash
/data/dhcpv6-mod/restart-dhcp-clients.sh
```
