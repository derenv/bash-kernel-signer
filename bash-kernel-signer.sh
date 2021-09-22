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
  ## Sign loop
  stop="False"
  prev_out=""
  until [[ "$stop" == "True" ]]; do
    tput reset
    echo "=========BASH KERNEL SIGNING UTILITY=========="

    # Search for kernels
    mapfile -t ukernels < <( find "$kernel_location" -name "vmlinuz-*-generic" | sort -n )
    mapfile -t skernels < <( find "$kernel_location" -name "vmlinuz-*-signed" | sort -n )

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
    read -p "Which kernel would you like to sign?:" -r user_input

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
    echo "=========BASH KERNEL SIGNING UTILITY=========="

    # Search for kernels
    mapfile -t ukernels < <( find "$kernel_location" -name "vmlinuz-*-generic" | sort -n )
    mapfile -t skernels < <( find "$kernel_location" -name "vmlinuz-*-signed" | sort -n )

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
    read -p "Which signed kernel would you like to purge?:" -r user_input

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
function create_keys()
{
  # Get user input
  tput reset
  read -r user_input -p "Please specify (existing) directory for new keys & certificates:"

  # Validate folder exists
  if [[ "$user_input" == "0" ]]; then
    ERROR_MSG="cancelled.."
    return 1
  elif [[ $(stat -c "%a" "$user_input") == "700" && -w "$user_input" && -r "$user_input" ]]; then
    # Read old keys
    echo "reading old keys..."
    efi-readvar -v PK -o "${user_input}/old_PK.esl"
    efi-readvar -v KEK -o "${user_input}/old_KEK.esl"
    efi-readvar -v db -o "${user_input}/old_db.esl"
    efi-readvar -v dbx -o "${user_input}/old_dbx.esl"
    read -n 1 -s -r -p "Old keys successfully read into files, press any key to continue.."

    # Generate keys and certificates
    echo "generating keys & certificates..."
    openssl req -new -x509 -newkey rsa:2048 -keyout "${user_input}/PK.key" -out "${user_input}/PK.crt" -days 3650 -nodes -sha256
    openssl req -new -x509 -newkey rsa:2048 -keyout "${user_input}/KEK.key" -out "${user_input}/KEK.crt" -days 3650 -nodes -sha256
    openssl req -new -x509 -newkey rsa:2048 -keyout "${user_input}/db.key" -out "${user_input}/db.crt" -days 3650 -nodes -sha256
    # Change permissions to read-only for root (precaution)
    sudo chmod -v 400 "${user_input}/PK.key"
    sudo chmod -v 400 "${user_input}/KEK.key"
    sudo chmod -v 400 "${user_input}/db.key"
    read -n 1 -s -r -p "Keys successfully generated, press any key to continue.."

    # Create update files
    echo "creating update files for keystore.."
    cert-to-efi-sig-list -g "$(uuidgen)" "${user_input}/PK.crt" "${user_input}/PK.esl"
    sign-efi-sig-list -k "${user_input}/PK.key" -c "${user_input}/PK.crt" PK "${user_input}/PK.esl" "${user_input}/PK.auth"
    cert-to-efi-sig-list -g "$(uuidgen)" "${user_input}/KEK.crt" "${user_input}/KEK.esl"
    sign-efi-sig-list -a -k "${user_input}/PK.key" -c "${user_input}/PK.crt" KEK "${user_input}/KEK.esl" "${user_input}/KEK.auth"
    cert-to-efi-sig-list -g "$(uuidgen)" "${user_input}/db.crt" "${user_input}/db.esl"
    sign-efi-sig-list -a -k "${user_input}/KEK.key" -c "${user_input}/KEK.crt" db "${user_input}/db.esl" "${user_input}/db.auth"
    sign-efi-sig-list -k "${user_input}/KEK.key" -c "${user_input}/KEK.crt" dbx "${user_input}/old_dbx.esl" "${user_input}/old_dbx.auth"
    read -n 1 -s -r -p "Update files successfully generated, press any key to continue.."

    # Create DER (Distinguished Encoding Rules) files, needed for some BIOSes
    openssl x509 -outform DER -in "${user_input}/PK.crt" -out "${user_input}/PK.cer"
    openssl x509 -outform DER -in "${user_input}/KEK.crt" -out "${user_input}/KEK.cer"
    openssl x509 -outform DER -in "${user_input}/db.crt" -out "${user_input}/db.cer"
    read -n 1 -s -r -p "DER versions successfully generated, press any key to continue"

    # Create compound esl files & auth counterparts
    cat "${user_input}/old_KEK.esl" "${user_input}/KEK.esl" > "${user_input}/compound_KEK.esl"
    cat "${user_input}/old_db.esl" "${user_input}/db.esl" > "${user_input}/compound_db.esl"
    sign-efi-sig-list -k "${user_input}/PK.key" -c "${user_input}/PK.crt" KEK "${user_input}/compound_KEK.esl" "${user_input}/compound_KEK.auth"
    sign-efi-sig-list -k "${user_input}/KEK.key" -c "${user_input}/KEK.crt" db "${user_input}/compound_db.esl" "${user_input}/compound_db.auth"
    read -n 1 -s -r -p "New esl & auth files successfully generated! See Sakaki's guide (https://wiki.gentoo.org/wiki/User:Sakaki/Sakaki's_EFI_Install_Guide/Configuring_Secure_Boot#Installing_New_Keys_into_the_Keystore) to update your keystore! (press any key to continue)"
  else
    ERROR_MSG="invalid directory, please exit and create new directory (check permissions!).."
    return 1
  fi

  return 0
}


## Check for signing keys
# Check if files specified in config
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [[ -f "$SCRIPT_DIR/keylocations.cfg" ]];then
  # Import config file
  source "$SCRIPT_DIR/keylocations.cfg"

  # Check keys exist
  if [[ -z "$key_location" || -z "$cert_location" ]]; then
    # empty key & cert file locations in config
    valid_keys="False"
  else
    # Key & cert files are specified
    valid_keys="True"

    # Check key & cert valid locations
    if [[ ! -f $key_location || ! -f $cert_location ]]; then
      # Otherwise print error
      echo "invalid Signature Database key/certificate locations, check config file.."
      exit 1
    fi
  fi

  # Check valid locations
  if [[ -z $kernel_location ]]; then
    # Otherwise print error
    echo "empty kernel location, check config file.."
    exit 1
  else
    # Check files exist
    if [[ ! -d $kernel_location ]]; then
      # Otherwise print error
      echo "missing kernel location, check config file.."
      exit 1
    fi
  fi
else
  # Otherwise print error
  echo "missing config file.."
  exit 1
fi


## Main Loop
stop="False"
prev_out=""
while [[ "$stop" == "False" ]]; do
  tput reset
  echo "=========BASH KERNEL SIGNING UTILITY=========="

  # Search for kernels
  mapfile -t ukernels < <( find "$kernel_location" -name "vmlinuz-*-generic" | sort -n )
  mapfile -t skernels < <( find "$kernel_location" -name "vmlinuz-*-signed" | sort -n )

  # Validate kernel signatures
  signvalids=()
  for skernel in ${skernels[@]}; do
    signvalids+=$(sbverify --cert "$cert_location" "${skernel}")
  done

  # Print all kernels
  echo " Number of kernels available for signing: ${#ukernels[@]}"
  for ukernel in "${ukernels[@]}"; do
    echo "  $ukernel"
  done
  echo " Number of signed kernels: ${#skernels[@]}"
  for ((i=0; i<${#skernels[@]}; i++)); do
    echo "  ${skernels[i]} -> ${signvalids[i]}"
  done
  if [[ "$valid_keys" == "True" ]]; then
    echo "Signature Database key & certificate detected.."
  else
    echo "Signature Database key and/or certificate not detected.."
  fi
  echo "=============================================="
  echo "$prev_out"
  echo "=============================================="
  echo "1 - Sign a kernel"
  echo "2 - Purge signed kernel"
  echo "3 - Create new keys"
  echo "4 - Install/Remove unsigned kernel"
  echo "5 - Modify Grub"
  echo "6 - Reboot"
  echo "0 - Exit"
  read -p "enter input:" -r user_input

  if [[ "$user_input" == "1" ]]; then
    if [[ "$valid_keys" == "True" ]]; then
      # sign kernels
      sign_kernel
      if [[ $? == 0 ]]; then
        prev_out="success!"
      else
        prev_out="failure: $ERROR_MSG"
      fi
    else
      prev_out="create new keys and append to existing/default keys first!"
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
    # create keys
    create_keys
    if [[ $? == 0 ]]; then
      prev_out="success!"
    else
      prev_out="failure: $ERROR_MSG"
    fi
  elif [[ "$user_input" == "4" ]]; then
    # check mainline present
    command_exists=$(su -c 'command -v mainline-gtk' "$(logname)")
    if [[ -n "$command_exists" ]]; then
      # redirect to mainline-gtk app
      mainline-gtk
      if [[ $? == 0 ]]; then
        prev_out="success!"
      else
        prev_out="failure: $?"
      fi
    else
      prev_out="mainline-gtk not present!"
    fi
  elif [[ "$user_input" == "5" ]]; then
    command_exists=$(su -c 'command -v grub-customizer' "$(logname)")
    # check grub-customizer present
    if [[ -n "$command_exists" ]]; then
      # redirect to grub-customizer app
      grub-customizer
      if [[ $? == 0 ]]; then
        prev_out="success!"
      else
        prev_out="failure: $?"
      fi
    else
      prev_out="grub-customizer not present!"
    fi
  elif [[ "$user_input" == "6" ]]; then
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
