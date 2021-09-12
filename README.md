# bash-kernel-signer

## Description

Kernel signing utility for easy overall kernel management on Ubuntu systems.

## Uses

* Signing installed mainline linux kernels using available user EFI keys (allowing them to run with secure boot)
* Deleting old/invalid signed keys
* Option to reboot when finished
* Also links to [grub-customizer](https://launchpad.net/~danielrichter2007/+archive/ubuntu/grub-customizer) for easy modification of boot config and [mainline](https://github.com/bkw777/mainline) kernel installer for installing new Ubuntu mainline PPA kernels

## Running

You need to have a directory of EFI keys on your system for this to run!

Set the directories for EFI keys and boot images in the config file and run as sudo.

## Dependencies

* [grub-customizer](https://launchpad.net/~danielrichter2007/+archive/ubuntu/grub-customizer)
* [mainline](https://github.com/bkw777/mainline)
