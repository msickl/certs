#!/bin/bash

# Configuration embedded in the script
CONFIG_FILE="${TMP_DIR}/ssl.cnf"

# Set directories
TMP_DIR="/tmp"
SSL_PRIVATE_DIR="/etc/ssl/private"
SSL_CERTS_DIR="/etc/ssl/certs"

# Function to handle errors
handle_error() {
    echo "$1"
    exit 1
}

# Generate ssl.cnf file dynamically
generate_config() {
    cat <<EOF > "${CONFIG_FILE}"
[ req ]
default_bits       = 4096
default_md         = sha256
default_keyfile    = ${DOMAIN}-encrypted.key
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[ req_distinguished_name ]
C = ***
ST = ***
L = ***
O = ***
OU = ***
CN = ${DOMAIN}

[ v3_req ]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${DOMAIN}
EOF
}

# Ask for domain name input
read -p "Enter the domain name (CN): " DOMAIN

# Validate domain name
if [ -z "$DOMAIN" ]; then
    handle_error "Error: Domain name (CN) cannot be empty!"
fi

# Set file paths based on the extracted domain
KEY_FILE_ENCRYPTED="${TMP_DIR}/${DOMAIN}-encrypted.key"
KEY_FILE="${TMP_DIR}/${DOMAIN}.key"
PASS_FILE="${TMP_DIR}/${DOMAIN}.pass"
CSR_FILE="${TMP_DIR}/${DOMAIN}.csr"
CRT_FILE="${DOMAIN}.crt"  # Empty .crt file in the current directory

# Generate the ssl.cnf file
generate_config

# Confirm action with user
read -p "Proceed with generating private keys and CSR for domain ${DOMAIN}? (y/n): " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    handle_error "Operation cancelled by user."
fi

# Generate a secure passphrase and save it to a file in /tmp
PASSPHRASE=$(openssl rand -base64 32)
echo "Passphrase for ${DOMAIN}: ${PASSPHRASE}" > "${PASS_FILE}"

# Generate an AES-128 encrypted private key (4096 bits) and save it in /tmp
openssl genrsa -aes128 -passout pass:${PASSPHRASE} -out "${KEY_FILE_ENCRYPTED}" 4096 || handle_error "Error generating encrypted private key."

# Decrypt the private key (remove passphrase) and save it in /tmp
openssl rsa -in "${KEY_FILE_ENCRYPTED}" -out "${KEY_FILE}" -passin pass:${PASSPHRASE} || handle_error "Error decrypting private key."

# Generate a certificate signing request (CSR) using the decrypted key and the generated configuration file
openssl req -sha256 -key "${KEY_FILE}" -new -out "${CSR_FILE}" -config "${CONFIG_FILE}" || handle_error "Error generating CSR."

# Create an empty .crt file in the current directory
touch "${CRT_FILE}" || handle_error "Error creating empty .crt file."

# Output generated files
echo "Generated encrypted private key: ${KEY_FILE_ENCRYPTED}"
echo "Decrypted private key without passphrase: ${KEY_FILE}"
echo "Generated certificate signing request (CSR): ${CSR_FILE}"
echo "Empty certificate file created: ${CRT_FILE}"

# Show the content of the CSR file
echo "Content of the CSR file (${CSR_FILE}):"
cat "${CSR_FILE}"

# Confirm installation with user
read -p "Do you want to move the key and certificate to system directories and reboot? (y/n): " install_response
if [[ ! "$install_response" =~ ^[Yy]$ ]]; then
    handle_error "Operation cancelled by user."
fi

# Move the private key to /etc/ssl/private
mv "$KEY_FILE" "${SSL_PRIVATE_DIR}/" || handle_error "Error moving the private key."
echo "Private key (${KEY_FILE}) moved to ${SSL_PRIVATE_DIR}."

# Move the certificate file to /etc/ssl/certs
mv "$CRT_FILE" "${SSL_CERTS_DIR}/" || handle_error "Error moving the certificate file."
echo "Certificate file (${CRT_FILE}) moved to ${SSL_CERTS_DIR}."

# Reboot the system
read -p "Reboot the system now? (y/n): " reboot_response
if [[ "$reboot_response" =~ ^[Yy]$ ]]; then
    echo "Rebooting system..."
    reboot || handle_error "Error initiating system reboot."
    echo "System reboot initiated."
else
    echo "System reboot skipped."
fi
