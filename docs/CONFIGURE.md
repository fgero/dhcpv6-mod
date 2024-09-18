# Configure your DHCP V6 options (for your ISP)

By default, DHCP V6 options are generated using a configuration file `/data/local/etc/dhcpv6.conf`, which is initialy created as a copy of `dhcpv6-orange.conf` (provided with this project). As the name indicates, those settings are for Orange France ISP, which has a particulary complex set of requirements about DHCP v6 options...

If you are using Orange France, then you don't need to update `/data/local/etc/dhcpv6.conf` but you can monitor potential future changes to default `dhcpv6-orange.conf`, for example if Orange decides (as they did in the past) to progressively deploy a change of DHCP request requirements.

If you are not using Orange France, your ISP has probably different requirements, so you can customize how dhcpv6-mod generates the DHCP V6 options, and for that you need to update the configuration file located in `/data/local/etc/dhcpv6.conf`.

> **Warning** Do no NOT modify `/data/dhcpv6-mod/dhcpv6-orange.conf`, only use `/data/local/etc/dhcpv6.conf` if you want to provide your own DHCPv6 options.

## Table of Contents

- [Initial creation](#initialize)
- [Basic principles](#basic_principles)
- [Other settings](#special_settings)
- [Typical example](#typical_example)
- [Default configuration (Orange)](#default_configuration)
- [How to test your configuration](#test_configuration)

&nbsp;

<a id="initialize"></a>

## Initial creation of the dhcpv6.conf file

<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

The very first time, you must create the config file and initialize it :

```bash
mkdir -p /data/local/etc
cp -p /data/dhcpv6-mod/dhcpv6-orange.conf /data/local/etc/dhcpv6.conf
```

Then you can edit the file to suit your needs.

&nbsp;

<a id="basic_principles"></a>

## Basic principles for the dhcpv6.conf file

<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

Note that the config file is "sourced" ("`. /data/local/etc/dhcpv6.conf`") by the `odhcp6c.sh` script, so **IT IS A BASH SCRIPT**.

All DHCP V4 options that are available (from the current state) are stored in the `dhcpv4[]` bash array.

So, for example, use `${dhcpv4[16]}` to fetch the value you set for DHCPv4 option 16 in the UI (please always use the brackets syntax...).

In order to generate DHCPv6 options, you must set the `dhcpv6[<opt#>]` environment variable (also a bash array). Example with like-for-like copy of 2 options from V4 to V6 :

```bash
optv6[15]=${optv4[77]}                    # userclass
optv6[11]=${optv4[90]}                    # authentication
```

(of course you could add harcoded hex strings prefixes and/or suffixes...)

NOTE : The value of `${dhcpv4[<opt#>]}` can be a little bit different from what you entered in the UI, more precisely :

- if you entered a hexstring like `01:02:ab:CD` in the UI, then the value in `optv4[]` will be `0102ABCD` (semicolons dropped and uppercase hex letters)
- if you entered a hexstring like `0102abCD`, then the value will be `0102ABCD` (uppercase hex letters)
- otherwise the value will be the same as what you entered in the UI, for example "StringNotHexadecimal", or "0102ABCD" are copied as-is into `optv4[]`

This manipulation is needed because odhcp6c wants hexadecimal strings without ':' and with uppercase hex letters.

> **Warning** : if you use `${optv4[n]}` with a option number 'n' that is NOT in the current state (i.e. not entered in Unifi's UI WAN DHCP v4 settings), then the script will immediately **FAIL**. That's intentional, there is no reason why you would need a non-existent DHCPv4 option to generate a DHCPv6 option.

&nbsp;

<a id="special_settings"></a>

## Other settings for the dhcpv6.conf file

<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

If needed, a `dhcpv4_hex[<opt#>]` array is available with the hexstring equivalent of a character string DHCPv4 option value (e.g. if dhcpv4[60]=sagem then dhcpv4_hex[60]=736167656D). This can be useful if the DHCP V6 option must be in hex (like DHCPv6 option 16, which is usually generated from DHCPv4 60 string value).

Additionnaly, a `dhcpv4_hexlen[<opt#>]` array is available, as this can be useful to construct DHCPv6 options with 2-bytes length fields.

Special case : DHCPv4 option 61 (client-id) is available as both `${optv4[61]}` and as `${macaddr}`. If you have checked and entered both "MAC Adress Clone" field in Unifi UI and option 61 in "DHCP Client Options", then the latter is stored (in both variables). If not, then the one you entered is stored in both variables.

By default, dhcpv6-mod will copy the DHCPv4 CoS set in the UI to the DHCPv6 CoS option (-K) of odhcp6c, so you don't need to specify it.

> So, even if a `dhcpv6_cos=n` option is available, DO NOT USE IT unless you know what you do, as it will probably break the DHCP lease (and your WAN connection). The reason : in almost 100% of situations (including Orange) the default behaviour is the correct one (DHCPv6 CoS copied from DHCPv4 CoS)

Option 6 (ORO, Option Requested options) to request from the DHCPv6 server can be overriden, default is "17,23,24" :

```bash
dhcpv6_request_options=17,23,24    # default, works for Orange, don't use that setting if you don't need to
```

This is : Vendor specific infos (17) + DNS servers (23) + Domain search list (24)

The other options sent to odhcp6c command line are, by default, "-a -f -R". If you want to change that for your ISP :

```bash
odhcp6c_options="-a -f -R"         # default, works for Orange, don't use that setting if you don't need to
```

This is : deactivate support for reconfigure opcode (-a), deactivate sending hostname (-f), deactivate requesting option not specified in -r (which are specified with dhcpv6_request_options).

&nbsp;

<a id="typical_example"></a>

## Typical example : generate DHCPv6 DUID option

<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

Some ISP need that DHCPv6 option 1 (DUID) to be provided to their DHCP server, here we do that with the DUID based on Link-Layer Address :

```bash
# DUID-LL(0003) + hwtype(0001) + macaddr(6 bytes)
optv6[1]=00030001${macaddr}
```

...and here with the DUID based on Link-Layer Address Plus Time, using `duid_time_hex` which is always available (RFC 8415 : 4-bytes, seconds since 2000-01-01 modulo 2^32) :

```bash
# DUID-LLT(0001) + hwtype(0001) + time(4 bytes) + macaddr(6 bytes)
optv6[1]=00010001${duid_time_hex}${macaddr}
```

Some ISPs seem to accept 00000000 as 4-byte time value.

You can also use `${optv4[61]}` instead of `${macaddr}`, both will work.

&nbsp;

<a id="default_configuration"></a>

## What is the default config file ?

<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

The `/data/local/etc/dhcpv6.conf` config file is first initialized to work for Orange ISP in France.

Here are the 4 DHCP options that are by default propagated from V4 to V6 with needed transformations, e.g. headers specified by [RFC8415](https://datatracker.ietf.org/doc/html/rfc8415) for options 16 and 1) :

| Name                                                                        | Opt V4 | Opt V6 | Header V6                                                                                                       | Value (from V4)                                             | Example of odhcp6c argument                                                                                                   |
| --------------------------------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| [Vendor class](https://www.rfc-editor.org/rfc/rfc3315.html#section-22.16)   | 60     | 16     | [0000040E 0005](https://www.iana.org/assignments/enterprise-numbers/) (4-byte IANA enterprise# + 2-byte length) | Vendor class string in hex                                  | -V [000000040E0005](https://www.iana.org/assignments/enterprise-numbers/)736167656D (here 5 bytes ASCII hex code for 'sagem') |
| [Client identifier](https://www.rfc-editor.org/rfc/rfc8415.html#page-99)    | 61     | 1      | [0003 0001](https://datatracker.ietf.org/doc/html/rfc8415#section-11) (DUID type LL + hw type ethernet          | Mac Address Clone (UI)                                      | -c [00030001](https://datatracker.ietf.org/doc/html/rfc8415#section-11)xxxxxxxxxxxx (6 bytes in hex for cloned macaddr)       |
| [User class](https://www.rfc-editor.org/rfc/rfc8415.html#page-115)          | 77     | 15     | None, because -u already adds 2-byte length field (e.g. 002B)                                                   | When using -u, pass a string (not hexstring)                | -u FSVDSL_livebox.Internet.softathome.LiveboxN (here 43 or 0x2b bytes as hexstring)                                           |
| [Authentication](https://www.rfc-editor.org/rfc/rfc8415.html#section-21.11) | 90     | 11     | None                                                                                                            | Authentication in hexstring (same as V4 opt 90 without ':') | -x 11:00....xx (70 bytes in hexstring for auth)                                                                               |

Now, the default config file should be self-explanatory :

```bash
# Put here which DHCP V6 client options you want, with or without using DHCP V4 fetched options
# We're in bash so everything (almost) is possibe, but keep it as simple as possible
dhcpv6_cos=6
optv6[16]=0000040E${optv4_hexlen[60]}${optv4_hex[60]}    # vendorclass : SagemCom IANA enterp number (0000040E) + strlen 'sagem' (0005)
optv6[1]=00030001${macaddr}               # or ${optv4[61]} : DUID-LL (0003) + hw type (0001)
optv6[15]=${optv4[77]}                    # userclass
optv6[11]=${optv4[90]}                    # authentication
```

<a id="test_configuration"></a>

## How to test your config file ?

<sup>[(Back to top)](#table-of-contents)</sup>
&nbsp;

You can test what odhcp6c-mod would do with your configuration file (or the default one), without actually executing the DHCPv6 client odhcp6c.

You need to be in SSH on the router.

For that you can create a `test-files` subdirectory in `/data/dhcpv6-mod` clone dir (note: test-files/ will be "gitignored") :

```bash
cd /data/dhcpv6-mod    # or to any clone directory
mkdir test-files
cp -p dhcpv6-orange.conf test-files/dhcpv6.conf
```

If you don't create `test-files` then your current config file, or the defaultone, will be used.

Then, you can test how odhcp6c.sh would fetch your interface details and generate DHCP v6 options using your dhcpv6.conf :

```bash
./odhcp6c.sh test ethx.832
```

(please replace ethx.832 with your interface and vlanid)

This will not change anything but generate a useful log like this one (the values are not mine, they come from test-files/interface.json) :

```console
[dhcpv6-mod] NOTE: running in test mode using interface eth4.832
[dhcpv6-mod] Selected DHCPv6 client executable (with support for CoS) : /bin/echo
[dhcpv6-mod] Fetched DHCPv4 option 60 : length=5 value=s...m
[dhcpv6-mod] Fetched DHCPv4 option 77 : length=43 value=FSVDS...ebox3
[dhcpv6-mod] Fetched DHCPv4 option 90 : length=140 value=00000...E1A82
[dhcpv6-mod] Fetched MAC Address Clone (or option 61): length=12
[dhcpv6-mod] Fetched DHCPv4 CoS of 6
[dhcpv6-mod] WARNING: took default dhcp6c options file ./dhcpv6-orange.conf as ./test-files/dhcpv6.conf was not found
[dhcpv6-mod] Generated DHCPv6 CoS of 6 (default is to set to the same value as DHCPv4 CoS)
[dhcpv6-mod] Generated DHCPv6 option 1 : length=20 value=0003...C263 (clientid, -c )
[dhcpv6-mod] Generated DHCPv6 option 11 : length=140 value=00000...E1A82 (authentication, -x 11:)
[dhcpv6-mod] Generated DHCPv6 option 15 : length=43 value=FSVDS...ebox3 (userclass, -u )
[dhcpv6-mod] Generated DHCPv6 option 16 : length=22 value=00000...7656D (vendorclass, -V )
[dhcpv6-mod] Successfully generated 4 DHCPv6 options using ./dhcpv6-orange.conf
[dhcpv6-mod] odhcp6c options would be : -a -f -R -r17,23,24 -K6 -c 00030001xxxxxxxxxxxx -x 11:xxxxxxxxx...xxx -u FSVDSL_livebox.Internet.softathome.Livebox3 -V 0000040E0005736167656D test eth4.832
```

The last line shows the options that would be passed to `odhcp6c`
