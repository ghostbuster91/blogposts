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

At this moment I had literally zero knowledge about embedded systems and ARM devices, all I knew was that you could install there OpenWRT, and since OpenWRT is a linux
I figured out that installing NixOS wouldn't be much of a problem.

I also found some unofficial [arch](https://forum.banana-pi.org/t/bpi-r3-imagebuilder-r3-archlinux-kernel-v6-3/15089),
[ubuntu](https://forum.banana-pi.org/t/bpi-r3-ubuntu-22-04-image/14956) and [debian](https://forum.banana-pi.org/t/bpi-r3-debian-bullseye-image/14541)
images linked in the [bpir3 documentation](https://wiki.banana-pi.org/Banana_Pi_BPI-R3) which only convinced me that this will be fairly easy.
Well, I was wrong. I mean, in the end it turned out not to be that hard provided that one knows what they were doing, but, let me remind you, I didn't.
Tbh there is still a lot of things that I don't understand but I learned a ton and I wanted to share that.

If you find anything incorrect in this article please don't hesitate to suggest a correction.

## Preface

This is not a tutorial on how to install NixOS on some ARM based board. This just me writing about what I have learned while doing that.
It might have some educational value but there are better resources, especially the great and always evolving nix wiki - https://nixos.wiki/wiki/NixOS_on_ARM

## Is your device supported?

Before we even begin to attempt installing our beloved operating system on the device we should first asses whether it is supported by the mainline kernel or not.

What does that it mean to be supported?

The kernel needs to know what kind of hardware components are available to it. This is information is provided by so called device-tree.
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

Device-tree files (dts) get compiled via device-tree compiler (dtc) into a device-tree blob (dtb) that then gets loaded by the bootloader and/or kernel.
(There are also dtsi files that are used to extract common definitions e.g. SoC. The dtsi files are meant to be included by regular dts files.)

Luckily, we don't have to always recompile the whole device-tree whenever we want to test some new device.
Instead, we can use device-tree overlays for that. A device-tree overlay is just a small piece of device-tree that we can add in particular place.
You can think of it as a device-tree patch. Once you have your overlay ready you need to compile it and then it can be applied to the already compiled main device-tree.

Some companies upstream their device-tree changes into the mainline kernel, so there is a chance that the newer kernel will support your custom device.
Good thing about NixOS is that it is easy to use a newer version of linux kernel and if you are using unstable channel you are already on one of the latest ones.

```nix
boot.kernelPackages = pkgs.linuxPackages_5_8;
```

Unfortunately, when I embarked on this journey bpir3 was not yet supported in the mainline. All I knew was that they'd just added support for bpir3 in OpenWRT repository:
https://github.com/openwrt/openwrt/commit/a96382c1bb204698cd43e82193877c10e4b63027

_Later, some of these changes got into the upstream._

Little did I know that nix can be also helpful in this context. Once you identify what device-tree patches/changes you need,
you can apply device-tree overlays directly from your NixOS configuration:

```nix
{ config, lib, pkgs, modulesPath, ... }:
{
    hardware.deviceTree.overlays = [
      {
        name = "bpir3-sd-enable";
        dtsFile = ./bpir3-dts/mt7986a-bananapi-bpi-r3-sd.dts;
      }
      {
        name = "bpir3-nand-enable";
        dtsFile = ./bpir3-dts/mt7986a-bananapi-bpi-r3-nand.dts;
      }
    ];
}
```

(`mt7986a-bananapi-bpi-r3-sd` and `mt7986a-bananapi-bpi-r3-nand` are directly extracted from the OpenWRT pull request mentioned earlier)

With device-tree entries in place we can move forward and try to start the operating system.

## Boot sequence

Before we dive into the boot sequence of embedded systems let's first do a quick recap how it works in case of regular x86 computers.
In case of a regular x86 machine booting of an operating system is handled by either UEFI or Legacy Boot in case of older computers.
Legacy Boot refers to the boot process used by the BIOS (Basic Input Output System) firmware to initialize hardware devices.
Both UEFI and BIOS come already preinstalled on motherboard's ROM.

All we have to do is to provide a device that will be bootable under the respective definition depending on which firmware we use.
MBR record in case of Legacy Boot, or EFI System Partition for the newer scheme.

Once a boot entry is found, the firmware bootloader will then load the next stage bootloader - operating system bootloader like GRUB that will eventually start the system.

In the case of embedded systems the general principle is the same - we will have a chain of bootloaders that will start from the most basic one to finally load the operating system.
The main difference however is that there is no bios nor UEFI firmware preflashed on the chip. Instead we have something that is called Boot ROM (BL1).

You might think, what is the problem, BL1 serves probably the same role as UEFI, so let's just ask it to load our operating system and we are done, right?

Not, so fast. BL1 (Primary Bootloader) is the most basic bootloader and all it can do is to load next stage bootloader BL2. The Boot ROM is hardwired or configured to know where BL2 is located in memory or storage.
This location is typically specified by the SoC manufacturer or system designer. The Boot ROM's role is to initiate the boot process by loading the secondary bootloader stage, BL2, into memory and passing control to it.
BL2 then takes over the boot process, sets up the secure environment, initializes necessary components, and proceeds to load and verify subsequent stages of the bootloader.

What is BL2 and where to find it?

I am not sure if this is a general rule for ARM based SoC but in our case BL2 is [ARM Trusted Firmware (ATF)](https://github.com/ARM-software/arm-trusted-firmware).
ATF plays a crucial role in the secure boot sequence of ARM-based systems, establishing a secure and trusted foundation for the entire system.
It initializes the security mechanisms, sets up the secure execution environment (Secure Monitor Mode), and verifies the integrity of subsequent bootloader stages.
Finally, it loads the next stage bootloader - BL3.

BL3 is further divided into:

- BL31 (sometimes written as BL3-1)
- optional BL32 that performs some additional verification (BL3-2)
- normal world bootloader BL33 (BL3-3)

BL33 is the final boot loader stage. It is usually a more feature-rich bootloader. BL3-3's responsibility is to initialize additional hardware, load the operating system kernel, and transfer control to the operating system for it to fully boot.
A popular option for embedded systems is to use [U-Boot](https://u-boot.readthedocs.io/en/latest/index.html).

_How does ATF know where to find BL3?_

There are different strategies how that can be achieved afaik, but in our case we will compile U-Boot "into" ATF.

Let's summarize what we've learned so far. There is BL1 burned into the SoC that will start ATF that will then call U-Boot which will finally load our operating system.

Does it mean that we can start now?

Not yet. Remember when I told you about the device-tree? U-Boot is a generic program that can be deployed on a wide variety of different devices. It achieves that by abstracting over the hardware by using device-tree definitions.
That means that we need to provide our bpir3 specific device-tree definitions to U-Boot in order to compile it for our board. Apart from that we will also need a `def_config` file that configures
how to build U-Boot. You can grab it from here: https://github.com/mtk-openwrt/u-boot/blob/mtksoc/configs/mt7986a_bpir3_sd_defconfig

Here is a great tutorial that goes in details on how to do that "by hand": https://forum.banana-pi.org/t/tutorial-build-customize-and-use-mediatek-open-source-u-boot-and-atf/13785

_Note that U-Boot and ATF need to be compiled for ARM, so you will either need to setup cross-compilation or have an ARM cpu._

Another thing to notice is that we need to have both custom [U-Boot](https://github.com/mtk-openwrt/u-boot) and custom [ATF](https://github.com/mtk-openwrt/arm-trusted-firmware) as both of them need some patches for bpir3.

_These patches as in case of kernel patches might at some point be upstreamed._

Once successfully compiled we will get two files - `bl2.img` and `fip.bin`. The fip file contains our custom U-Boot.
In order to boot our board from these files we need to put them in specific locations on the SD card.

As you can see this is already getting quite complex and we didn't even started compiling the kernel :)

Once again, nix can take some of that burden from us!

Nixpkgs exposes `buildArmTrustedFirmware` function that we can use to compile ATF: https://github.com/NixOS/nixpkgs/blob/2e2c6b2f027463700b557143cb04d561d8b63f9c/pkgs/misc/arm-trusted-firmware/default.nix#L14

Here is how we can use it:

```nix
(buildArmTrustedFirmware rec {
    extraMakeFlags = [ "USE_MKIMAGE=1" "DRAM_USE_DDR4=1" "BOOT_DEVICE=sdmmc" "BL33=${ubootBananaPiR3}/u-boot.bin" "all" "fip" ];
    platform = "mt7986";
    extraMeta.platforms = ["aarch64-linux"];
    filesToInstall = [ "build/${platform}/release/bl2.img" "build/${platform}/release/fip.bin" ];
  })
```

However, this will use the mainline version of arm-trusted-firmware while we need the fork from MTK repository.
We can change that by overriding some attributes of that function:

```nix
(buildArmTrustedFirmware rec {
    # same as before
  }).overrideAttrs (oldAttrs: {
    src = fetchFromGitHub {
      owner = "mtk-openwrt";
      repo = "arm-trusted-firmware";
      # mtksoc HEAD 2023-03-10
      rev = "7539348480af57c6d0db95aba6381f3ee7483779";
      hash = "sha256-OjM+metlaEzV7mXA8QHYEQd94p8zK34dLTqbyWQh1bQ=";
    };
    version = "2.7.0-mtk";
  });
```

Last but not least, we need to provide some additional tools for the build process as normally this function does not incorporate u-boot.
We can do this by extending `nativeBuildInputs` in the `overrideAttrs` clause, so end the end it looks as follows:

```nix
armTrustedFirmwareMT7986 = (buildArmTrustedFirmware rec {
    extraMakeFlags = [ "USE_MKIMAGE=1" "DRAM_USE_DDR4=1" "BOOT_DEVICE=sdmmc" "BL33=${ubootBananaPiR3}/u-boot.bin" "all" "fip" ];
    platform = "mt7986";
    extraMeta.platforms = ["aarch64-linux"];
    filesToInstall = [ "build/${platform}/release/bl2.img" "build/${platform}/release/fip.bin" ];
  }).overrideAttrs (oldAttrs: {
    src = fetchFromGitHub {
      owner = "mtk-openwrt";
      repo = "arm-trusted-firmware";
      # mtksoc HEAD 2023-03-10
      rev = "7539348480af57c6d0db95aba6381f3ee7483779";
      hash = "sha256-OjM+metlaEzV7mXA8QHYEQd94p8zK34dLTqbyWQh1bQ=";
    };
    version = "2.7.0-mtk";
    nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ dtc ubootTools ];
  });
```

When can then apply the same technique to build our custom version of U-Boot.
The base function is defined here: https://github.com/NixOS/nixpkgs/blob/359ea22552b78c8ddc9b1ca5b1af66864e10fe61/pkgs/misc/uboot/default.nix#L33

And here is how it looks like adapted to our values:

```nix
(buildUBoot {
    defconfig = "mt7986a_bpir3_sd_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    extraPatches = [];
    filesToInstall = [ "u-boot.bin" ];
    src = fetchFromGitHub {
      owner = "mtk-openwrt";
      repo = "u-boot";
      rev = "09eda825456d164e12e719a83360bf0987e64bfd";
      hash = "sha256-+YM2+d9jdv5TENCZGqwdnXNwxtkpVqHgcJ2MlZoLHUI=";
    };
    version = "2023.07-rc3";
  });
```