#!/bin/bash

# Ensure the script is run as root or with sudo
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root or use sudo."
  exit 1
fi

# Function to fix package with missing newline in the list file
fix_package_list_file() {
  local PACKAGE_NAME="$1"
  echo "Attempting to fix package: $PACKAGE_NAME"

  local LIST_FILE="/var/lib/dpkg/info/${PACKAGE_NAME}.list"
  if [ -f "$LIST_FILE" ]; then
    echo "Removing corrupted package list file: $LIST_FILE"
    rm -f "$LIST_FILE"
  else
    echo "Package list file not found: $LIST_FILE"
  fi

  echo "Reinstalling package: $PACKAGE_NAME"
  apt-get update
  apt-get install --reinstall "$PACKAGE_NAME" -y
}

# Function to check if jq is properly installed and working
is_jq_installed_and_working() {
  if dpkg -s jq >/dev/null 2>&1 && jq --version >/dev/null 2>&1; then
    return 0  # jq is installed and working
  else
    return 1  # jq is not installed or not working
  fi
}

# Check if jq is installed and working properly
if is_jq_installed_and_working; then
  echo "jq is already installed and working properly."
else
  echo "jq is not installed or not working properly. Attempting installation."

  MAX_RETRIES=3
  RETRY_COUNT=0
  INSTALL_SUCCESS=0

  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Try to install jq and capture the output and exit status
    INSTALL_OUTPUT=$(LC_ALL=C apt-get install jq -y 2>&1)
    INSTALL_EXIT_STATUS=$?

    if [ $INSTALL_EXIT_STATUS -eq 0 ]; then
      echo "jq installed successfully."
      if is_jq_installed_and_working; then
        INSTALL_SUCCESS=1
        break
      else
        echo "jq installation completed but jq is not functioning properly."
      fi
    else
      echo "jq installation failed. Error output:"
      echo "$INSTALL_OUTPUT"

      # Look for the missing newline error in the output
      if echo "$INSTALL_OUTPUT" | grep -q "missing final newline"; then
        # Extract the package name from the error message
        PACKAGE_NAME=$(echo "$INSTALL_OUTPUT" | grep "missing final newline" | sed -n "s/.*package '\(.*\)' is missing final newline.*/\1/p")

        if [ -n "$PACKAGE_NAME" ]; then
          echo "Detected missing newline error in package: $PACKAGE_NAME"

          # Fix the package by removing the corrupted list file and reinstalling
          fix_package_list_file "$PACKAGE_NAME"
        else
          echo "Failed to extract the package name from the error message."
          break
        fi
      else
        echo "Installation failed due to an unknown error."
        break
      fi
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
  done

  if [ $INSTALL_SUCCESS -eq 0 ]; then
    echo "jq installation failed after $MAX_RETRIES attempts."
    exit 1
  else
    echo "jq is installed and functioning properly after fixing."
  fi
fi
