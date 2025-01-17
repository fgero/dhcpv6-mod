# If you want IPv6 for both your WANs (primary and failover)

&nbsp;

### Case 1 : you have only 1 of the 2 interfaces with DHCPv4 client options set

That is : one interface has absolutely zero "DHCP Client Options" set in its "IPv4 Configuration" in Unifi's GUI, i.e. the ISP behind this WAN interface does not need any specific DHCP option, neither v4 nor v6.

Then, `dhcpv6-mod` will not do anything to the WAN interface because it has no DHCPv4 option : the standard `odhcp6c` client will be launched as Unifi does normally, with no DHCPv6 option generated, and no configuration file used.

Then, you are OK with only one config file, because `dhcpv6-mod` will only apply the `dhcpv6.conf` config to the interface that has at least 1 DHCPv4 option set.

&nbsp;

### Case 2 : you have both interfaces with DHCPv4 client options set

In that situation, for each interface, `dhcpv6-mod` will first look for an <i>interface-specific configuration file</i> precisely named `dhcpv6.conf.<interface>[.<vlan>]` : for example `dhcpv6.conf.eth3`, or `dhcpv6.conf.eth3.832`, depending on your VLAN configuration.
<br>
If that file exists, then its specific configuration will be applied (only) to the named interface (eth3 or eth3.832 in the examples above).

Note that this interface-specific config file can be empty (then, no V6 option generated), but at least it has to exist if you want to avoid the default configuration.

Instead of creating a completely empty configuration file, it is sometimes useful to use just the two lines below, in order to be completely standard (i.e. no options requested from DHCP server, and no particular odhcp6c command option passed), as the defaults could be undesirable :

```bash
dhcpv6_request_options=            # otherwise defaults to 17,23,24
odhcp6c_options=                   # otherwise defaults to "-a -f -R"
```

If there is no interface-specific configuration file, then `dhcpv6-mod` will take the default one, `dhcpv6.conf` : so you must at least create a specific configuration file for one of the interfaces. The other will be configured with the non-specific config file.
