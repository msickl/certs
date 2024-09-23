#!/bin/bash

# Set directories
TMP_DIR="/tmp"
SSL_PRIVATE_DIR="/etc/ssl/private"
SSL_CERTS_DIR="/etc/ssl/certs"

# Find the correct .key file in /tmp (excluding -encrypted) and .crt file in the current directory
KEY_FILE=$(ls ${TMP_DIR}/*.key 2>/dev/null | grep -v "-encrypted")
CRT_FILE=$(ls *.crt 2>/dev/null)

# Check if a .key file (excluding -encrypted) exists in /tmp
if [ -z "$KEY_FILE" ]; then
    echo "Error: No .key file found in /tmp (excluding -encrypted)."
    exit 1
fi

# Check if a .crt file exists in the current directory
if [ -z "$CRT_FILE" ]; then
    echo "Error: No .crt file found in the current directory."
    exit 1
fi

# Move the private key to /etc/ssl/private
mv "$KEY_FILE" "${SSL_PRIVATE_DIR}/"
if [ $? -eq 0 ]; then
    echo "Private key ($KEY_FILE) moved to ${SSL_PRIVATE_DIR}/."
else
    echo "Error moving the private key."
    exit 1
fi

# Move the certificate file to /etc/ssl/certs
mv "$CRT_FILE" "${SSL_CERTS_DIR}/"
if [ $? -eq 0 ]; then
    echo "Certificate file ($CRT_FILE) moved to ${SSL_CERTS_DIR}/."
else
    echo "Error moving the certificate file."
    exit 1
fi

# Reboot the system
echo "Rebooting system..."
reboot
if [ $? -eq 0 ]; then
    echo "System reboot initiated successfully."
else
    echo "Error initiating system reboot."
    exit 1
fi

echo "Move operation completed and system reboot initiated."
