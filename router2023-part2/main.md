# NixOS based router in 2023 - Part 2 - Software

This is the second part of my journey of having NixOS based router on BananaPI R3 board (bpir3) in which I will focus more on the software side of things.
The first part is [here](../router2023/main.md), however reading it is not essential for understanding of this part.

Before we begin I want to briefly mention that there are two different ways to have a reproducible router. The obvious one that I took is to just install NixOS there and configure it to serve as a router. The other one is to use OpenWRT, write your configuration in a declarative way and render set of uci commands to apply on an OpenWRT instance.
You can read more about the second approach here: https://github.com/Mic92/dotfiles/tree/main/openwrt

## IPv4 / IPv6

First, we need to choose whether we want to support both IPv6 and IPv4 or do only IPv4 setup.
Depending on that choice we might have to chose some specific components for our software stack.

I decided to do only IPv4 setup because:

- it is much simpler than IPv6, as there is only one canonical way of doing things
- my ISP can only assign me either IPv4 or IPv6 not both, which I was told isn't the best idea (at least for now).
- last but not least I wanted to have something working without doing PhD from every single aspect :)

With this settled we can start setting up our router.

## Kernel

You thought that we wouldn't have to deal with the kernel anymore after part 1, didn't you?

By default, the Linux kernel is configured to discard network packets that are not destined for the interface on which they were received.
This effectively prevents any kind of routing, so we have to change it.

Add following lines to your nix configuration:

```nix
boot.kernel = {
  sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };
};
```

## Interfaces

We need to configure our network interfaces. There are two ways to configure it under NixOS - either by using [networking.interface](https://search.nixos.org/options?query=networking.interfaces) or [systemd.network](https://nixos.wiki/wiki/Systemd-networkd). The second one is preferred if you have a static configuration that doesn't change much during its lifetime, which is exactly our case.

Let's quickly recall what network interfaces we have for our disposal in bpir3:

![network interfaces in bpir3](https://wiki.banana-pi.org/images/thumb/3/3f/BPI-R3_network_interface.jpg/640x363x640px-BPI-R3_network_interface.jpg.pagespeed.ic.hRqpPzHRTV.webp "network interfaces in bpir3")

ETH1 and LAN5 are SFP sockets that we won't be using, which means that we are left with 1 wan interface, 4 lan and two wifi interfaces.

We can now write our first part of networkd configuration, that will enslave lan interfaces and configure the wan interface so that it can get the IP address from upstream (e.g. ISP).

```nix
  systemd.network = {
    wait-online.anyInterface = true;
    networks = {
      "30-lan0" = {
        matchConfig.Name = "lan0";
        linkConfig.RequiredForOnline = "enslaved";
        networkConfig = {
          ConfigureWithoutCarrier = true;
        };
      };
      # lan1 and lan2 look analogical
      "30-lan3" = {
        matchConfig.Name = "lan3";
        linkConfig.RequiredForOnline = "enslaved";
        networkConfig = {
          ConfigureWithoutCarrier = true;
        };
      };
      "10-wan" = {
        matchConfig.Name = "wan";
        networkConfig = {
          # start a DHCP Client for IPv4 Addressing/Routing
          DHCP = "ipv4";
          # accept Router Advertisements for Stateless IPv6 Auto-Configuration (SLAAC)
          IPv6AcceptRA = true;
          DNSOverTLS = true;
          DNSSEC = true;
          IPv6PrivacyExtensions = false;
          IPForward = true;
        };
        # make routing on this interface a dependency for network-online.target
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };
```

For now there is almost no configuration for lan interfaces, we only marked them as managed by networkd and that they should be `UP` even if they don't have carrier attached.
This allows connecting the carrier afterwards.

A small note about `wait-online.anyInterface` - without this networkd activation would fail as it would be waiting until timeout is reached for all managed interfaces to come online.
It is not necessary to set it if all managed interfaces are always connected but this is not my case. I want to retain ability to plug and unplug cables when needed.

Next, we can install our new configuration. I recommend using `test` command instead of `switch` while you are testing things as if anything goes wrong,
you will be able to reboot your device and it will use the last known configuration. Also, it is cleaner as it does not create new boot entry each time.

```sh
$ nixos-rebuild test  --flake .
```

Let's verify current state of network interfaces:

```sh
$ networkctl

IDX LINK    TYPE     OPERATIONAL SETUP
  1 lo      loopback carrier     unmanaged
  2 eth0    ether    off         unmanaged
  3 eth1    ether    off         unmanaged
  4 wan     dsa      routable    configured
  5 lan0    dsa      no-carrier  configured
  6 lan1    dsa      no-carrier  configured
  7 lan2    dsa      no-carrier  configured
  8 lan3    dsa      no-carrier  configured
  9 lan4    dsa      off         unmanaged

9 links listed.
```

eth0 and eth1 are SFP sockets and they are disabled in my setup.

### Bridging LAN interfaces

Since I want all my LAN interfaces to share the same address pool and to communicate within the local network without any restrictions it seems logical to connect them on the L2
into a single bridge interface. We will also advertise ourselves on that interface under `192.168.10.1/24` ip address.
This is the address under which other devices within the local network will be able to reach our router.

This can be fairly easy done with networkd:

```nix
{
    wait-online.anyInterface = true;
    netdevs = {
      # Create the bridge interface
      "20-br-lan" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br-lan";
        };
      };
    };
    networks = {
      # Connect the bridge ports to the bridge
      "30-lan0" = {
        matchConfig.Name = "lan0";
        networkConfig = {
          Bridge = "br-lan";
          ConfigureWithoutCarrier = true;
        };
        linkConfig.RequiredForOnline = "enslaved";
      };
      # lan1 and lan2 look analogical
      "30-lan3" = {
        matchConfig.Name = "lan3";
        networkConfig = {
          Bridge = "br-lan";
          ConfigureWithoutCarrier = true;
        };
        linkConfig.RequiredForOnline = "enslaved";
      };
      # Configure the bridge for its desired function
      "40-br-lan" = {
        matchConfig.Name = "br-lan";
        bridgeConfig = { };
        address = [
          "192.168.10.1/24"
        ];
        networkConfig = {
          ConfigureWithoutCarrier = true;
        };
      };
      "10-wan" = {
        # this stays the same
      };
    };
  }
```

## Routing

Having all the low-level network configuration in place we can finally setup some firewall rules.
For this we will use nftables. [Nftables](https://wiki.nftables.org/wiki-nftables/index.php/Main_Page) is a successor of [iptables](https://en.wikipedia.org/wiki/Iptables)
which due its declarative nature plays nicely with nix.

Below is almost my full nftables configuration that despite being quite simple is sufficient.

```nix
  networking = {
    hostName = "surfer";
    useNetworkd = true;
    useDHCP = false;

    # No local firewall.
    nat.enable = false;
    firewall.enable = false;

    nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority 0; policy drop;

            iifname { "br-lan" } accept comment "Allow local network to access the router"
            iifname "wan" ct state { established, related } accept comment "Allow established traffic"
            iifname "wan" icmp type { echo-request, destination-unreachable, time-exceeded } counter accept comment "Allow select ICMP"
            iifname "wan" counter drop comment "Drop all other unsolicited traffic from wan"
            iifname "lo" accept comment "Accept everything from loopback interface"
          }
          chain forward {
            type filter hook forward priority filter; policy drop;

            iifname { "br-lan" } oifname { "wan" } accept comment "Allow trusted LAN to WAN"
            iifname { "wan" } oifname { "br-lan" } ct state { established, related } accept comment "Allow established back to LANs"
          }
        }

        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;
            oifname "wan" masquerade
          }
        }
      '';
    };
  };
```

Each entry has a comment attach, so I won't go much into the details here but I want to point out few things.

As you can see there are no references to lan interfaces.
Instead we have the "br-lan" interface that is our bridge which represents our internal network.

The rules are pretty simple. We prevent any kind of outside traffic from reaching internal network and the router.
We trust all internal traffic that comes from "br-lan" to access router and the outside world (`wan`).
Established traffic from the outside (the one that originated internally) is allowed.

At the beginning I forgot to add rule for the loopback (`lo`) interface which prevented router itself from accessing the internet.

For those who don't like embedding configuration in strings there is [nixos-nftables-firewall](https://github.com/thelegy/nixos-nftables-firewall) project
which allows you to express nftables rules directly in nix.
At some point I [ported my configuration to it](https://github.com/ghostbuster91/nixos-router/commit/9fd38ec45d8b7801f0b89dd5d6efe16b68a7b1e2),
however I had to revert that because there are some things which cannot (yet?) be expressed using this project (e.g. hardware offloading).

## DNS and DHCP

...

TODO:

- wifi different standards
- mbank mobile app
- hostapd PR with multiple interfaces
- resolved and LO interface
- hardware acceleration and WED
- gc weird issue

ref:

- https://www.jjpdev.com/posts/home-router-nixos/
- https://francis.begyn.be/blog/nixos-home-router
- https://dataswamp.org/~solene/2022-08-03-nixos-with-live-usb-router.html
- https://pavluk.org/blog/2022/01/26/nixos_router.html
- https://skogsbrus.xyz/building-a-router-with-nixos/
