# bash-kernel-signer

## Description

Kernel signing utility for easy overall kernel management on Ubuntu systems.

## Uses

* Creating a modified signature database using GPG
* Signing installed mainline or custom linux kernels (allowing them to run with secure boot)
* Deleting old/invalid signed kernels
* Option to reboot when finished
* Also links to [grub-customizer](https://launchpad.net/~danielrichter2007/+archive/ubuntu/grub-customizer) for easy modification of boot config and [mainline](https://github.com/bkw777/mainline) kernel installer for installing new Ubuntu mainline PPA kernels

## Updating EFI keys & Signature Database

You need to have a directory containing a signature database file on your system - you'll need to create this, i created a "/etc/efikeys" directory as suggested by Sakaki ('chmod -v 700 dirname' to make sure only superuser can access!).

In order to create keys for signing kernels, first generate new keys using the utility and then follow the relevent sections of [Sakaki's EFI Install Guide](https://wiki.gentoo.org/wiki/User:Sakaki/Sakaki's_EFI_Install_Guide/Configuring_Secure_Boot) for appending the keys to your existing keys (I won't go into detail here as the method varies across motherboards - it may be using the efi-updatevar command, it may be by accessing the keystore directly from the BIOS GUI and appending keys from a USB stick, etc). Once exported using efi-readvar, this should create a valid set of key files/certificates.
Once created, follow the suitable method for your system [on Sakaki's guide](https://wiki.gentoo.org/wiki/User:Sakaki/Sakaki's_EFI_Install_Guide/Configuring_Secure_Boot#Installing_New_Keys_into_the_Keystore)

## Running

Set the directories for your signature database and kernels (eg the folder containing "vmlinuz-5.14.2-051402-generic" or whichever kernel you want to sign, "/boot" on my system) in the config file and run as sudo.

## Dependencies

* openssl
* [grub-customizer](https://launchpad.net/~danielrichter2007/+archive/ubuntu/grub-customizer)
* [mainline](https://github.com/bkw777/mainline)
