# Nixos based router in 2023

After spending few months with NixOS as my daily driver and successfully fixing most of the issues,
that I encountered (unknown to the happy people who use user-friendly distro like ubuntu),

I felt empowered and free, now when I can put everything into a VCS.

I decided to continue nixification even further. But what else can you nixify after switching your main operating system to NixOS?

Look around, I bet you will find a lot of devices that still are not running NixOS :) One strong contender for that was my old router.

Why I chose to ~break~ nixify my router:

- It is a device of critical importance and it should be up-to-date due to security reasons, however I have no idea if regular vendors are shipping any updates to the devices that they have already sold. On the other hand keeping it up-to-date using nix will be trivial.
- It can server as a vpn server, provided that your firmware allow for that. That is not an issue if you use bare linux, you are free to setup any kind of software including various vpn servers.
- Again, depending on your firmware you might be able to setup quite advanced configurations for your home-network. E.g. putting all IOT devices on a separate network that does not have access to the internet. With bare linux you are free te setup the networking rules however you like.
- In contrast to a normal linux distro/OpenWRT with nix putting the configuration into VCS is a no-brainer.
- last but not least I wanted to learn more about networking and these kind of things :)

However, we cannot install a regular linux distribution like NixOS on an arbitrary router device and my router was no exception to that.
There are some distribution that are very small and they can be installed almost everywhere. One of such distributions is [OpenWRT](https://openwrt.org/) that is tailored for networking devices.
In our case we will need something more powerful, something that is more of a general purpose, like raspberry PI, but tailored more for networking operations.
Luckily, Sinovoip, a company that is know from building such boards, recently started selling their newest [Banana PI R3](https://wiki.banana-pi.org/Banana_Pi_BPI-R3)
board (bpir3 for short) that had everything that I needed.

The board has a MediaTek MT7986(Filogic 830) Quad core ARM A53 processor and 2 GB of RAM which is the minimum required for building the NixOS system.
It has 5 ethernet ports, it supports Wifi 6, and can be equipped with a nvme disk - perfect!

At this moment I had literally zero knowledge about ARM devices, all I knew was that you could install there OpenWRT, and since OpenWRT is a linux
I figured out that installing NixOS wouldn't be much of a problem.

I also found some unofficial arch and ubuntu images linked in the bpir3 documentation which only convinced me that this will be fairly easy.
Well, I was wrong. I mean, in the end it turned out not to be that hard provided that one knows what they were doing, but, let me remind you, I didn't.
Tbh there is still a lot of things that I don't understand but I learned a ton and I wanted to share that.

If you find anything incorrect in this article please don't hesitate to suggest a correction.

## Is your device supported?

Before we even begin to attempt installing our beloved operating system on a device we should first asses whether it is supported by the mainline kernel or not.

What does that it mean to be supported?

The kernel needs to know what kind of devices are available to it. This is information is provided by so called device-tree.
The device-tree is a tree of descriptions of every device supported by linux kernel, and it lives in the linux repository.
In our case bpir3 is a device and there should be a device-tree entry for it. This entry will then list all its components together with their physical
addresses and drivers that are required to communicate with them.

Here is a part of it that defines two buttons (reset and wps):

```
	keys {
		compatible = "gpio-keys";

		factory {
			label = "reset";
			linux,code = <KEY_RESTART>;
			gpios = <&pio 9 GPIO_ACTIVE_LOW>;
		};

		wps {
			label = "wps";
			linux,code = <KEY_WPS_BUTTON>;
			gpios = <&pio 10 GPIO_ACTIVE_LOW>;
		};
	};
```

The device-tree in linux kernel gets compiled into a device-tree binary (dts) that then gets loaded by the kernel.
Luckily, we don't have to always recompile the whole device-tree whenever we want to test some new device.
Instead, we can use device-tree overlays for that. A device-tree overlay is just a small piece of device-tree that we can add in particular place.
Once you have your overlay ready you need to compile it and it can be loaded in runtime.

Some companies upstream their device-tree changes into the mainline kernel, so there is a chance that the newer kernel will support your custom device.
Good thing about NixOS is that it is easy to use a newer version of linux kernel and if you are using unstable channel you are already on the latest one.

Unfortunately, when I embarked on this journey bpir3 was not yet supported in the mainline. All I knew was that they'd just added support for bpir3 in OpenWRT repository:
https://github.com/openwrt/openwrt/commit/a96382c1bb204698cd43e82193877c10e4b63027

Later, some of these changes got into the upstream.

First, I started with the [official docs](https://nixos.wiki/wiki/NixOS_on_ARM).
There is a section about community supported devices and it even contains few banana pi boards, however without the bpir3 (at this point it was quite new so I wasn't surprised).
Then I headed to "Porting NixOS to new boards" section where you can find several ways of how install NixOS on your board depending on the current state of linux support for the particular board and the board itself.

// What I want to write here about:
// uboot, how it works, how it differs from regular bios, atf, fip partition
