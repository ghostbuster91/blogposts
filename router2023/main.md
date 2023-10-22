# Nixos based router in 2023 - Part 1 - Hardware

After spending a few months with NixOS as my daily driver and successfully resolving most of the issues I encountered (unlike the fortunate users of user-friendly distros like Ubuntu),
I now feel empowered and free, especially because I can put everything into a VCS.

I decided to continue nixification even further. But what else can you nixify after switching your main operating system to NixOS?

Look around, I bet you will find a lot of devices that still are not running NixOS :) One strong contender for that was my old router.

Why I chose to ~break~ nixify my router:

- It is a device of critical importance and it should be up-to-date due to security reasons, however, I have no idea if regular vendors are shipping any updates to the devices that they have already sold. On the other hand, keeping it up-to-date using nix will be trivial.
- It can serve as a vpn server, provided that your firmware allows for that. That is not an issue if you use bare linux, you are free to setup any kind of software including various vpn servers.
- Again, depending on your firmware you might be able to set up quite advanced configurations for your home network. E.g. putting all IOT devices on a separate network that does not have access to the internet. With bare linux, you are free to set up the networking rules however you like.
- In contrast to a normal linux distro/OpenWRT with nix putting the configuration into VCS is a no-brainer.
- last but not least I wanted to learn more about networking and these kind of things :)

However, we cannot install a regular linux distribution like NixOS on an arbitrary router device and my router was no exception to that.
Some distribution are very small and they can be installed almost everywhere. One such distribution is [OpenWRT](https://openwrt.org/) which is tailored for networking devices.
In our case, we will need something more powerful, something that is more of a general purpose, like Raspberry PI, but tailored more for networking operations.
Luckily, Sinovoip, a company that is known from building such boards, recently started selling their newest [Banana PI R3](https://wiki.banana-pi.org/Banana_Pi_BPI-R3)
board (bpir3 for short) that had everything that I needed.

The board has a MediaTek MT7986(Filogic 830) Quad core ARM A53 processor and 2 GB of RAM which is the minimum required for building the NixOS system[^1].
It has 5 ethernet ports, it supports Wifi 6, and can be equipped with a nvme disk - perfect!

At the moment I had literally zero knowledge about embedded systems and ARM devices, all I knew was that you could install there OpenWRT, and since OpenWRT is a linux
I figured out that installing NixOS wouldn't be much of a problem.

I also found some unofficial [arch](https://forum.banana-pi.org/t/bpi-r3-imagebuilder-r3-archlinux-kernel-v6-3/15089),
[ubuntu](https://forum.banana-pi.org/t/bpi-r3-ubuntu-22-04-image/14956) and [debian](https://forum.banana-pi.org/t/bpi-r3-debian-bullseye-image/14541)
images linked in the [bpir3 documentation](https://wiki.banana-pi.org/Banana_Pi_BPI-R3) which only convinced me that this would be fairly easy.
Well, I was wrong. I mean, in the end, it turned out not to be that hard provided that one knows what they were doing, but, let me remind you, I didn't.
Tbh there are still a lot of things that I don't understand but I learned a ton and I wanted to share that.

If you find anything incorrect in this article please don't hesitate to suggest a correction.

## Preface

This is not a tutorial on how to install NixOS on some ARM based board. This just me writing about what I have learned while doing that.
It might have some educational value but there are better resources, especially the great and always evolving nix wiki - https://nixos.wiki/wiki/NixOS_on_ARM

## Is your device supported?

Before we even begin to attempt installing our beloved operating system on the device we should first asses whether it is supported by the mainline kernel or not.

What does that it mean to be supported?

The kernel needs to know what kind of hardware components are available to it. This information is provided by so called device-tree.
The device-tree is a tree of descriptions of every device supported by linux kernel.
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

Device-tree definitions live in [linux kernel repository](https://github.com/torvalds/linux/tree/master/arch/arm64/boot/dts/mediatek).
Luckily, we don't have to always fork linux whenever we want to test some new device.
Instead, we can use device-tree overlays for that. A device-tree overlay is just a small piece of device-tree that we can add in particular place.
You can think of it as a device-tree patch. Once you have your overlay ready you need to compile it and then it can be applied to the already compiled main device-tree.

Some companies upstream their device-tree changes into the mainline kernel, so there is a chance that the newer kernel will support your custom device.
Good thing about NixOS is that it is easy to use a newer version of linux kernel and if you are using unstable channel you are already on one of the latest ones.

```nix
boot.kernelPackages = pkgs.linuxPackages_6_5;
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

Not so fast. BL1 (Primary Bootloader) is the most basic bootloader and all it can do is to load next stage bootloader BL2. The Boot ROM is hardwired or configured to know where BL2 is located in memory or storage.
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

Not yet. Remember when I told you about the device-tree? U-Boot is a generic program that can be deployed on a wide variety of different devices. It achieves that by abstracting over the hardware with the help of device-tree definitions.
That means that we need to provide our bpir3 specific device-tree definitions to U-Boot in order to compile it for our board. Apart from that we will also need a `def_config` file that configures
how to build U-Boot. You can grab it from here: https://github.com/mtk-openwrt/u-boot/blob/mtksoc/configs/mt7986a_bpir3_sd_defconfig

Here is a great tutorial that goes in details on how to do that "by hand": https://forum.banana-pi.org/t/tutorial-build-customize-and-use-mediatek-open-source-u-boot-and-atf/13785

_Note that U-Boot and ATF need to be compiled for ARM, so you will either need to setup cross-compilation or have an ARM cpu. Check the [cross-compilation](#cross-compilation) section for more info._

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

However, this will use the mainline version of arm-trusted-firmware and we need the custom version from MTK fork.
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

We can then apply the same technique to build our custom version of U-Boot.
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

Great, we finally have both `bl2.img` and `fip.bin`. Now we need to put them in a specific place on our SD card.
As stated previously files (ATF at least) have to be put in very specific locations.

Below table describes our target partition layout:

| partition  | blocks (512byte)            |
| ---------- | --------------------------- |
| bl2        | 34 - 8191                   |
| u-boot-env | 8192 - 9215                 |
| factory    | 9216 - 13311                |
| fip        | 13312 - 17407               |
| kernel     | 17408 - 222207 (100 MB)     |
| rootfs     | 222208 - 12805120 (6144 MB) |

(src: http://www.fw-web.de/dokuwiki/doku.php?id=en:bpi-r3:start)

This is basically where I got before @nakato wrote on [banana-pi forum](https://forum.banana-pi.org/) that they were able to boot NixOS on bpir3.
For the sake of completeness of this blog post I will try to describe next steps but my understanding of them is pretty basic.

## Building kernel

Next we need to create NixOS image that we will put into the `rootfs` partition.
The image needs to include kernel with device-tree patches applied.
The kernel itself needs to be compiled for the target architecture - ARM64.

Let's configure the kernel:

```nix
boot.kernelPackages =
  let
    base = linux_6_4;
    bpir3_minimal = linuxKernel.customPackage {
      inherit (base) version modDirVersion src;
      configfile = copyPathToStore ./bpir3_kernel.config;
    };
  in
    bpir3_minimal
;
```

The `bpir3_kernel.config` contains configuration for building the kernel specifying which modules to include.
(The less modules you have the faster the building time :) )
How the `bpir3_kernel.config` file was created is still a mystery for me, because even if some template config file can be generated you still
need to know what most of the kernel modules are for in order to select correct subset of them.

While it wasn't necessary for booting NixOS on this board, I realized that it would be a pity not to mention here how one can apply kernel patches.
In general, patching things in Nix is a daily routine. It is quite common that you will need to patch the source code of a project in order to make it compatible with Nix.
Below is an example of creating a kernel based on the 6.4 mainline version with an applied mtk-pcie patch.

```nix
  patched_kernel = linux_6_4.override {
    kernelPatches = [{
      name = "PCI: mediatek-gen3: handle PERST after reset";
      patch = ./linux-mtk-pcie.patch;
    }];
  };
```

## NixOS image

With kernel configured we can finally build the `rootfs` image:

```nix
rootfsImage = pkgs.callPackage (pkgs.path + "/nixos/lib/make-ext4-fs.nix") {
  storePaths = config.system.build.toplevel;
  compressImage = false;
  volumeLabel = "root";
};
```

Now we should have everything that's needed to create the final SD-card image.
We will once again use nix to describe how all these pieces should be wired together:

```nix
{ config, lib, pkgs, linuxPackages_bpir3, armTrustedFirmwareMT7986,  ...}:
with lib;
let
  rootfsImage = pkgs.callPackage (pkgs.path + "/nixos/lib/make-ext4-fs.nix") {
    storePaths = config.system.build.toplevel;
    compressImage = false;
    volumeLabel = "root";
  };
in {
  boot.kernelPackages = linuxPackages_bpir3;
  boot.kernelParams = [ "console=ttyS0,115200" ];
  boot.loader.generic-extlinux-compatible.enable = true;

  hardware.deviceTree.filter = "mt7986a-bananapi-bpi-r3.dtb";
  hardware.deviceTree.overlays = [
    {
      name = "bpir3-sd-enable";
      dtsFile = ./bpir3-dts/mt7986a-bananapi-bpi-r3-sd.dts;
    }
  ];

  system.build.sdImage = pkgs.callPackage (
    { stdenv, dosfstools, e2fsprogs, gptfdisk, mtools, libfaketime, util-linux, zstd, uboot }: stdenv.mkDerivation {
      name = "nixos-bananapir3-sd";
      nativeBuildInputs = [
        dosfstools e2fsprogs gptfdisk libfaketime mtools util-linux
      ];
      buildInputs = [ uboot ];
      imageName = "nixos-bananapir3-sd";
      compressImage = false;

      buildCommand = ''
        # 512MB should provide room enough for a couple of kernels
        bootPartSizeMB=512
        root_fs=${rootfsImage}

        mkdir -p $out/nix-support $out/sd-image
        export img=$out/sd-image/nixos-bananapir3-sd.raw

        echo "${pkgs.stdenv.buildPlatform.system}" > $out/nix-support/system
        echo "file sd-image $img" >> $out/nix-support/hydra-build-products

        ## Sector Math
        bl2Start=34
        bl2End=8191

        envStart=8192
        envEnd=9215

        factoryStart=9216
        factoryEnd=13311

        fipStart=13312
        fipEnd=17407

        # End statically sized partitions

        # kernel partition
        bootSizeBlocks=$((bootPartSizeMB * 1024 * 1024 / 512))
        bootPartStart=$((fipEnd + 1))
        bootPartEnd=$((bootPartStart + bootSizeBlocks - 1))

        rootSizeBlocks=$(du -B 512 --apparent-size $root_fs | awk '{ print $1 }')
        rootPartStart=$((bootPartEnd + 1))
        rootPartEnd=$((rootPartStart + rootSizeBlocks - 1))

        # Image size is firmware + boot + root + 100s
        # Last 100s is being lazy about GPT backup, which should be 36s is size.

        imageSize=$((fipEnd + 1 + bootSizeBlocks + rootSizeBlocks + 100))
        imageSizeB=$((imageSize * 512))

        truncate -s $imageSizeB $img

        # Create a new GPT data structure
        sgdisk -o \
        --set-alignment=2 \
        -n 1:$bl2Start:$bl2End -c 1:bl2 -A 1:set:2:1 \
        -n 2:$envStart:$envEnd -c 2:u-boot-env \
        -n 3:$factoryStart:$factoryEnd -c 3:factory \
        -n 4:$fipStart:$fipEnd -c 4:fip \
        -n 5:$bootPartStart:$bootPartEnd -c 5:boot -t 5:C12A7328-F81F-11D2-BA4B-00A0C93EC93B \
        -n 6:$rootPartStart:$rootPartEnd -c 6:root \
        $img

        # Copy firmware
        dd conv=notrunc if=${uboot}/bl2.img of=$img seek=$bl2Start
        dd conv=notrunc if=${uboot}/fip.bin of=$img seek=$fipStart

        # Create vfat partition for ESP and in this case populate with extlinux config and kernels.
        truncate -s $((bootSizeBlocks * 512)) bootpart.img
        mkfs.vfat --invariant -i 0x2178694e -n ESP bootpart.img
        mkdir ./boot
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./boot
        # Reset dates
        find boot -exec touch --date=2000-01-01 {} +
        cd boot
        for d in $(find . -type d -mindepth 1 | sort); do
          faketime "2000-01-01 00:00:00" mmd -i ../bootpart.img "::/$d"
        done
        for f in $(find . -type f | sort); do
          mcopy -pvm -i ../bootpart.img "$f" "::/$f"
        done
        cd ..

        fsck.vfat -vn bootpart.img
        dd conv=notrunc if=bootpart.img of=$img seek=$bootPartStart

        # Copy root filesystem
        dd conv=notrunc if=$root_fs of=$img seek=$rootPartStart
      '';
    }
  ) { uboot = armTrustedFirmwareMT7986; };
```

This is not the complete code to make NixOS boot on bpir3. I minimized it to show (in my opinion) the most important parts.
I am also not the author of it. For the full code visit @nakato's [nixos-bpri3-example](https://github.com/nakato/nixos-bpir3-example/tree/main) repository.

## Cross-compilation

With nix [cross-compilation is quite easy](https://nixos.wiki/wiki/NixOS_on_ARM#Cross-compiling), at least in theory.

There are two ways how you can produce a binary for a different architecture.
You can either cross-compile or use an emulator like binfmt QEMU.
Both have their pros and cons. Using emulator is slower, however some packages might fail to build when trying to cross-compile them on a different architecture.

To have your derivation cross-compiled for a different architecture all you have to do is to add something like below:

```nix
{
  nixosConfigurations.myMachine = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      {
        nixpkgs.crossSystem.system = "aarch64-linux";
      }
      ./configuration.nix
    ];
  }
}
```

Now, I have tried doing it myself, but it didn't work for some reason. If you try to cross-compile something like a simple NixOS flake for raspberry PI then I suppose you will have no problems.
I suspect that it doesn't work in my case due to the internals of my flake, as there are many instances with hardcoded architecture set to aarch64.
Probably rewriting the flake as a set of NixOS modules would help, but I haven't found the time to try it yet.

I hope to do it one day and I will link my results here.
In the meantime here is an example repository where you can see cross-compilation in action: https://github.com/ghostbuster91/nixos-rockchip

## Epilog

I must say that all in all, it was much harder than I initially assumed.
However, this was not due to Nix, but rather because of the inherent complexity of the entire task. If anything, I dare to say that Nix made it possible for me to take on this challenge.

If you would like to run NixOS on ARM don't worry because it doesn't have to look that hard.
For example raspberry PI has [upstream support in NixOS](https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi#Status),
and I heard that the experience of setting it up and then using it is very smooth.

There are other boards that are supported by community. You can find full list of them and a ton of documentation as always in great [nix documentation](https://nixos.wiki/wiki/NixOS_on_ARM).
(This is not an irony, I know that some people complain about the state of nix documentation but given how broad horizon it covers I am truly amazed by how good it is.)

Now, when I have NixOS running I am planning to configure it as a router, to replace my tplink router with it at some point.

Last but not least, I would like to thank people without whom I wouldn't be able to write this blogpost and without whom that mission would probably fail:

- @lorenz who first booted NixOS on bpir3 and shared his config
- @nakato for putting all the bits and pieces into a reusable flake, but more importantly for patiently answering all of my questions
- @frank.w and @ericwoud for the support with getting NixOS on bpir3
- @samueldr and @k900 for helping me undrestand various niuances about SoC,ARM and state of the support of nix for such boards
- and many other people both from bananapi forum and "NixOS on ARM" matrix

Thank you!

[^1]:
    You don't have to build NixOS system on the exact same device where you will be using it. There is a feature in Nix called remote builds which lets you
    build your nix derivation on another machine and copy results over the network. You can read more about it [here](https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds.html)
