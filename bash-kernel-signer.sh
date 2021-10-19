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
    mapfile -t kernels < <( find "$kernel_location" -name "vmlinuz-*" | sort -n )
    unsigned_kernels=()
    valid_signed_kernels=()
    invalid_signed_kernels=()
    valid_validity_checks=()
    invalid_validity_checks=()

    # For each detected kernel
    for unvalidated_kernel in "${kernels[@]}"; do
      # Validate kernel signatures
      mapfile -t validity_check < <(sbverify --cert "$cert_location" "${unvalidated_kernel}" 2>&1)

      # Increment signed/unsigned kernels
      if [[  "${#validity_check[@]}" = 1 && "${validity_check[0]}" = "Signature verification OK" ]]; then
        # Add to valid signed kernels
        valid_signed_kernels+=("$unvalidated_kernel")
        valid_validity_checks+=("${validity_check[0]}")
      elif [[ "${#validity_check[@]}" = 1 && "${validity_check[0]}" = "Signature verification failed" ]]; then
        # Add to invalid signed kernels
        invalid_signed_kernels+=("$unvalidated_kernel")
        invalid_validity_checks+=("${validity_check[0]}")
      elif [[ "${#validity_check[@]}" = 2 && "${validity_check[0]}" = "No signature table present" ]]; then
        # Add to unsiged kernels
        unsigned_kernels+=("$unvalidated_kernel")
      else
        # SOME UNKNOWN ERROR?
        echo "??error??"
      fi
    done

    # Print all kernels
    declare -i counter
    echo " Number of kernels available for signing: ${#unsigned_kernels[@]}"
    if [[ "${#unsigned_kernels[@]}" == 0 ]]; then
      echo "  -none-"
    else
      counter=0
      for kernel in "${unsigned_kernels[@]}"; do
        id=$(( "$counter" + 1 ))
        echo "  $id - $kernel"
        (( counter++ ))
      done
    fi
    echo " Number of signed kernels: ${#valid_signed_kernels[@]}"
    if [[ "${#valid_signed_kernels[@]}" == 0 ]]; then
      echo "  -none-"
    else
      counter=0
      for kernel in "${valid_signed_kernels[@]}"; do
        echo "  $kernel"
        echo "    -> ${valid_validity_checks[$counter]}"
        (( counter++ ))
      done
    fi
    echo " Number of invalid signed kernels: ${#invalid_signed_kernels[@]}"
    if [[ "${#invalid_signed_kernels[@]}" == 0 ]]; then
      echo "  -none-"
    else
      counter=0
      for kernel in "${invalid_signed_kernels[@]}"; do
        echo "  $kernel"
        echo "     -> ${invalid_validity_checks[$counter]}"
        (( counter++ ))
      done
    fi

    echo "=============================================="
    echo "$prev_out"
    echo "=============================================="
    echo "0 - Exit"
    read -p "Which kernel would you like to sign?:" -r user_input

    if [[ "$user_input" == "0" ]]; then
      ERROR_MSG="cancelled.."
      return 1
    elif [[ "$user_input" =~ ^[0-9]+$ ]] && test "$user_input" -le "${#unsigned_kernels[@]}"; then
      # Sign kernel
      selection=$(( user_input - 1 ))
      datetime=$(date +"%Y-%m-%d+%T")
      sbsign --key "$key_location" --cert "$cert_location" --output "${unsigned_kernels[$selection]}-signed$datetime" "${unsigned_kernels[$selection]}"
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
    mapfile -t kernels < <( find "$kernel_location" -name "vmlinuz-*" | sort -n )

    # Only verify keys if keys exist
    if [[ "$valid_keys" == "True" ]]; then
      unsigned_kernels=()
      valid_signed_kernels=()
      invalid_signed_kernels=()
      valid_validity_checks=()
      invalid_validity_checks=()

      # For each detected kernel
      for unvalidated_kernel in "${kernels[@]}"; do
        # Validate kernel signatures
        mapfile -t validity_check < <(sbverify --cert "$cert_location" "${unvalidated_kernel}" 2>&1)

        # Increment signed/unsigned kernels
        if [[  "${#validity_check[@]}" = 1 && "${validity_check[0]}" = "Signature verification OK" ]]; then
          # Add to valid signed kernels
          valid_signed_kernels+=("$unvalidated_kernel")
          valid_validity_checks+=("${validity_check[0]}")
        elif [[ "${#validity_check[@]}" = 1 && "${validity_check[0]}" = "Signature verification failed" ]]; then
          # Add to invalid signed kernels
          invalid_signed_kernels+=("$unvalidated_kernel")
          invalid_validity_checks+=("${validity_check[0]}")
        elif [[ "${#validity_check[@]}" = 2 && "${validity_check[0]}" = "No signature table present" ]]; then
          # Add to unsinged kernels
          unsigned_kernels+=("$unvalidated_kernel")
        else
          # SOME UNKNOWN ERROR?
          echo "??error??"
        fi
      done

      # Print all kernels
      declare -i counter
      echo " Number of kernels available for signing: ${#unsigned_kernels[@]}"
      if [[ "${#unsigned_kernels[@]}" == 0 ]]; then
        echo "  -none-"
      else
        for kernel in "${unsigned_kernels[@]}"; do
          echo "  $kernel"
        done
      fi
      echo " Number of signed kernels: ${#valid_signed_kernels[@]}"
      if [[ "${#valid_signed_kernels[@]}" == 0 ]]; then
        echo "  -none-"
      else
        counter=0
        for kernel in "${valid_signed_kernels[@]}"; do
          id=$(( "$counter" + 1 ))
          echo "  $id - $kernel"
          echo "    -> ${valid_validity_checks[$counter]}"
          (( counter++ ))
        done
      fi
      echo " Number of invalid signed kernels: ${#invalid_signed_kernels[@]}"
      if [[ "${#invalid_signed_kernels[@]}" == 0 ]]; then
        echo "  -none-"
      else
        counter=0
        for kernel in "${invalid_signed_kernels[@]}"; do
          echo "  $kernel"
          echo "     -> ${invalid_validity_checks[$counter]}"
          (( counter++ ))
        done
      fi
    else
      echo " Kernels Present: ${#kernels[@]}"
      for kernel in "${kernels[@]}"; do
        echo "  $kernel"
      done

      echo "Signature Database key and/or certificate not detected.."
    fi
    echo "=============================================="
    echo "$prev_out"
    echo "=============================================="
    echo "0 - Exit"
    read -p "Which signed kernel would you like to purge?:" -r user_input

    if [[ "$user_input" == "0" ]]; then
      ERROR_MSG="cancelled.."
      return 1
    elif [[ ! "$valid_keys" == "True" ]]; then
      prev_out="missing/invalid keys, cannot check kernels.."
    elif [[ "$user_input" =~ ^[0-9]+$ ]] && test "$user_input" -le "${#valid_signed_kernels[@]}"; then
      # Purge signed kernel
      selection=$(( user_input - 1 ))
      sudo rm -f "${valid_signed_kernels[$selection]}"
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
  read -p "Please specify (existing) directory for new keys & certificates:" -r user_input

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
    # (continue)
    read -n 1 -s -r -p "Old keys successfully read into files, press any key to continue.."

    # Generate keys and certificates
    echo -e "\ngenerating keys & certificates..."
    openssl req -new -x509 -newkey rsa:2048 -subj "/CN=new platform key/" -keyout "${user_input}/new_PK.key" -out "${user_input}/new_PK.crt" -days 3650 -nodes -sha256
    openssl req -new -x509 -newkey rsa:2048 -subj "/CN=new key exchange key/" -keyout "${user_input}/new_KEK.key" -out "${user_input}/new_KEK.crt" -days 3650 -nodes -sha256
    openssl req -new -x509 -newkey rsa:2048 -subj "/CN=new kernel signing key/" -keyout "${user_input}/new_db.key" -out "${user_input}/new_db.crt" -days 3650 -nodes -sha256
    # Change permissions to read-only for root (precaution)
    sudo chmod -v 400 "${user_input}/new_PK.key"
    sudo chmod -v 400 "${user_input}/new_KEK.key"
    sudo chmod -v 400 "${user_input}/new_db.key"
    # (continue)
    read -n 1 -s -r -p "Keys successfully generated, press any key to continue.."

    # Create update files
    echo "\ncreating update files for keystore.."
    # PK
    cert-to-efi-sig-list -g "$(uuidgen)" "${user_input}/new_PK.crt" "${user_input}/new_PK.esl"
    sign-efi-sig-list -k "${user_input}/new_PK.key" -c "${user_input}/new_PK.crt" PK "${user_input}/new_PK.esl" "${user_input}/new_PK.auth"
    # KEK
    cert-to-efi-sig-list -g "$(uuidgen)" "${user_input}/new_KEK.crt" "${user_input}/new_KEK.esl"
    sign-efi-sig-list -a -k "${user_input}/new_PK.key" -c "${user_input}/new_PK.crt" KEK "${user_input}/new_KEK.esl" "${user_input}/new_KEK.auth"
    # db
    cert-to-efi-sig-list -g "$(uuidgen)" "${user_input}/new_db.crt" "${user_input}/new_db.esl"
    sign-efi-sig-list -a -k "${user_input}/new_KEK.key" -c "${user_input}/new_KEK.crt" db "${user_input}/new_db.esl" "${user_input}/new_db.auth"
    # dbx
    sign-efi-sig-list -k "${user_input}/new_KEK.key" -c "${user_input}/new_KEK.crt" dbx "${user_input}/old_dbx.esl" "${user_input}/old_dbx.auth"
    # (continue)
    read -n 1 -s -r -p "Update files successfully generated, press any key to continue.."

    # Create DER (Distinguished Encoding Rules) files, needed for some BIOSes
    openssl x509 -outform DER -in "${user_input}/new_PK.crt" -out "${user_input}/new_PK.cer"
    openssl x509 -outform DER -in "${user_input}/new_KEK.crt" -out "${user_input}/new_KEK.cer"
    openssl x509 -outform DER -in "${user_input}/new_db.crt" -out "${user_input}/new_db.cer"
    # (continue)
    read -n 1 -s -r -p "\nDER versions successfully generated, press any key to continue"

    # Create compound esl files & auth counterparts
    cat "${user_input}/old_KEK.esl" "${user_input}/new_KEK.esl" > "${user_input}/compound_KEK.esl"
    cat "${user_input}/old_db.esl" "${user_input}/new_db.esl" > "${user_input}/compound_db.esl"
    sign-efi-sig-list -k "${user_input}/new_PK.key" -c "${user_input}/new_PK.crt" KEK "${user_input}/compound_KEK.esl" "${user_input}/compound_KEK.auth"
    sign-efi-sig-list -k "${user_input}/new_KEK.key" -c "${user_input}/new_KEK.crt" db "${user_input}/compound_db.esl" "${user_input}/compound_db.auth"
    # (continue)
    echo "New esl & auth files successfully generated!"
    echo "Add /etc/efikeys/db.key abd /etc/efikeys/db.crt to config file!"
    echo "See Sakaki's guide (https://wiki.gentoo.org/wiki/User:Sakaki/Sakaki's_EFI_Install_Guide/Configuring_Secure_Boot#Installing_New_Keys_into_the_Keystore) on how to update your keystore!"
    read -n 1 -s -r -p "(press any key to continue)"
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
  mapfile -t kernels < <( find "$kernel_location" -name "vmlinuz-*" | sort -n )

  # Only verify keys if keys exist
  if [[ "$valid_keys" == "True" ]]; then
    unsigned_kernels=()
    valid_signed_kernels=()
    invalid_signed_kernels=()
    valid_validity_checks=()
    invalid_validity_checks=()

    # For each detected kernel
    for unvalidated_kernel in "${kernels[@]}"; do
      # Validate kernel signatures
      mapfile -t validity_check < <(sbverify --cert "$cert_location" "${unvalidated_kernel}" 2>&1)

      # Increment signed/unsigned kernels
      if [[  "${#validity_check[@]}" = 1 && "${validity_check[0]}" = "Signature verification OK" ]]; then
        # Add to valid signed kernels
        valid_signed_kernels+=("$unvalidated_kernel")
        valid_validity_checks+=("${validity_check[0]}")
      elif [[ "${#validity_check[@]}" = 1 && "${validity_check[0]}" = "Signature verification failed" ]]; then
        # Add to invalid signed kernels
        invalid_signed_kernels+=("$unvalidated_kernel")
        invalid_validity_checks+=("${validity_check[0]}")
      elif [[ "${#validity_check[@]}" = 2 && "${validity_check[0]}" = "No signature table present" ]]; then
        # Add to unsiged kernels
        unsigned_kernels+=("$unvalidated_kernel")
      else
        # SOME UNKNOWN ERROR?
        echo "??error??"
      fi
    done

    # Print all kernels
    declare -i counter
    echo " Number of kernels available for signing: ${#unsigned_kernels[@]}"
    if [[ "${#unsigned_kernels[@]}" == 0 ]]; then
      echo "  -none-"
    else
      for kernel in "${unsigned_kernels[@]}"; do
        echo "  $kernel"
      done
    fi
    echo " Number of signed kernels: ${#valid_signed_kernels[@]}"
    if [[ "${#valid_signed_kernels[@]}" == 0 ]]; then
      echo "  -none-"
    else
      counter=0
      for kernel in "${valid_signed_kernels[@]}"; do
        echo "  $kernel"
        echo "    -> ${valid_validity_checks[$counter]}"
        (( counter++ ))
      done
    fi
    echo " Number of invalid signed kernels: ${#invalid_signed_kernels[@]}"
    if [[ "${#invalid_signed_kernels[@]}" == 0 ]]; then
      echo "  -none-"
    else
      counter=0
      for kernel in "${invalid_signed_kernels[@]}"; do
        echo "  $kernel"
        echo "    -> ${invalid_validity_checks[$counter]}"
        (( counter++ ))
      done
    fi

    echo "Signature Database key & certificate detected.."
  else
    echo " Kernels Present: ${#kernels[@]}"
    for kernel in "${kernels[@]}"; do
      echo "  $kernel"
    done

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
    command_exists="$(command -v mainline-gtk)"
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
    # check grub-customizer present
    command_exists="$(command -v grub-customizer)"
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
