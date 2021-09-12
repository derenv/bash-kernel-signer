# bash-kernel-signer

## Description

For signing installed linux kernels using available user EFI keys (allowing them to run with secure boot).

You need to have a directory of EFI keys on your system for this to run.

This also links to grub-customizer and mainline kernel installer for easy modification of boot.

## Running

Set the directories for EFI keys and boot images in the config file and run!

## Dependencies

* grub-customizer
* mainline-gtk
