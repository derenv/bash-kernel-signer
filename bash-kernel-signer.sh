#!/usr/bin/env bash

##
#  Author: Deren Vural
#   Title: bash-kernel-signer.sh
# Purpose: signing installed linux kernels using available user EFI keys
# Created: 12/09/2021
##

# Root privileges check
[[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit 1

# Global error message var
ERROR_MSG=""

## Functions
function sign_kernel()
{
  ## Check for signing keys
  # Check if files specified in config
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
  if [[ -f "$SCRIPT_DIR/keylocations.cfg" ]];then
    source "$SCRIPT_DIR/keylocations.cfg"

    # Check valid locations
    if [[ -z $key_location ]] || [[ -z $cert_location ]]; then
      # Otherwise print error
      ERROR_MSG="malformed config file.."
      return 1
    fi
  else
    # Otherwise print error
    ERROR_MSG="missing config file.."
    return 1
  fi

  # Check files exist
  if [[ ! -f $key_location ]] || [[ ! -f $cert_location ]]; then
    # Otherwise print error
    ERROR_MSG="missing signing key/certificate.."
    return 1
  fi

  ## Sign loop
  stop="False"
  prev_out=""
  until [[ "$stop" == "True" ]]; do
    tput reset
    echo "========BASH KERNEL SIGNING UTILITY========"

    # Search for kernels
    mapfile -t ukernels < <( find /boot -name "vmlinuz-*-generic" | sort -n )
    mapfile -t skernels < <( find /boot -name "vmlinuz-*-signed" | sort -n )

    # Print all kernels
    echo " Number of kernels available for signing: ${#ukernels[@]}"
    counter=1
    for k in "${ukernels[@]}"; do
      echo "  $counter - $k"
      (( counter++ ))
    done
    echo " Number of signed kernels: ${#skernels[@]}"
    for k in "${skernels[@]}"; do
      echo "  $k"
    done

    echo "=============================================="
    echo "$prev_out"
    echo "=============================================="
    echo "0 - Exit"
    echo "which kernel would you like to sign?:"
    read -r user_input

    if [[ "$user_input" == "0" ]]; then
      ERROR_MSG="cancelled.."
      return 1
    elif [[ "$user_input" =~ ^[0-9]+$ ]] && test "$user_input" -le "${#ukernels[@]}"; then
      # Sign kernel
      selection=$(( user_input - 1 ))
      sbsign --key "$key_location" --cert "$cert_location" --output "${ukernels[$selection]}-signed" "${ukernels[$selection]}"
      prev_out="$?"
    else
      prev_out="invalid input.."
    fi
  done

  return 0
}
function purge_kernel()
{
  ## Purge loop
  stop="False"
  prev_out=""
  until [[ "$stop" == "True" ]]; do
    tput reset
    echo "========BASH KERNEL SIGNING UTILITY========"

    # Search for kernels
    mapfile -t ukernels < <( find /boot -name "vmlinuz-*-generic" | sort -n )
    mapfile -t skernels < <( find /boot -name "vmlinuz-*-signed" | sort -n )

    # Print all kernels
    echo " Number of kernels available for signing: ${#ukernels[@]}"
    for k in "${ukernels[@]}"; do
      echo "  $k"
    done
    echo " Number of signed kernels: ${#skernels[@]}"
    counter=1
    for k in "${skernels[@]}"; do
      echo "  $counter - $k"
      (( counter++ ))
    done

    echo "=============================================="
    echo "$prev_out"
    echo "=============================================="
    echo "0 - Exit"
    echo "which signed kernel would you like to purge?:"
    read -r user_input

    if [[ "$user_input" == "0" ]]; then
      ERROR_MSG="cancelled.."
      return 1
    elif [[ "$user_input" =~ ^[0-9]+$ ]] && test "$user_input" -le "${#skernels[@]}"; then
      # Purge signed kernel
      selection=$(( user_input - 1 ))
      rm "${skernels[$selection]}"
      prev_out="$?"
    else
      prev_out="invalid input.."
    fi
  done

  return 0
}


## Main Loop
stop="False"
prev_out=""
while [[ "$stop" == "False" ]]; do
  tput reset
  echo "========BASH KERNEL SIGNING UTILITY========"

  # Search for kernels
  mapfile -t ukernels < <( find /boot -name "vmlinuz-*-generic" | sort -n )
  mapfile -t skernels < <( find /boot -name "vmlinuz-*-signed" | sort -n )

  # Print all kernels
  echo " Number of kernels available for signing: ${#ukernels[@]}"
  for k in "${ukernels[@]}"; do
    echo "  $k"
  done
  echo " Number of signed kernels: ${#skernels[@]}"
  for k in "${skernels[@]}"; do
    echo "  $k"
  done

  echo "=============================================="
  echo "$prev_out"
  echo "=============================================="
  echo "1 - Sign a kernel"
  echo "2 - Purge signed kernel"
  echo "3 - Install/Remove unsigned kernel"
  echo "4 - Modify Grub"
  echo "5 - Reboot"
  echo "0 - Exit"
  echo "enter input:"
  read -r user_input

  if [[ "$user_input" == "1" ]]; then
    # sign kernels
    sign_kernel
    if [[ $? == 0 ]]; then
      prev_out="success!"
    else
      prev_out="failure: $ERROR_MSG"
    fi
  elif [[ "$user_input" == "2" ]]; then
    # purge kernels
    purge_kernel
    if [[ $? == 0 ]]; then
      prev_out="success!"
    else
      prev_out="failure: $ERROR_MSG"
    fi
  elif [[ "$user_input" == "3" ]]; then
    # redirect to mainline-gtk app
    mainline-gtk
    if [[ $? == 0 ]]; then
      prev_out="success!"
    else
      prev_out="failure: $?"
    fi
  elif [[ "$user_input" == "4" ]]; then
    # redirect to grub-customizer app
    grub-customizer
    if [[ $? == 0 ]]; then
      prev_out="success!"
    else
      prev_out="failure: $?"
    fi
  elif [[ "$user_input" == "5" ]]; then
    reboot
  elif [[ "$user_input" == "0" ]]; then
    # exit
    tput reset
    stop="True"
    echo "Goodbye!.."
  else
    prev_out="invalid input.."
  fi
done
