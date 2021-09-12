# bash-kernel-signer

## Description

Kernel signing utility for overall kernel management on Debian/Ubuntu systems.

Uses:
* Signing installed mainline linux kernels using available user EFI keys (allowing them to run with secure boot)
* Deleting old/invalid signed keys
* Option to reboot when finished
* Also links to grub-customizer for easy modification of boot config and mainline kernel installer for installing new kernels

## Running

You need to have a directory of EFI keys on your system for this to run!

Set the directories for EFI keys and boot images in the config file and run as sudo.

## Dependencies

* grub-customizer
* mainline-gtk
