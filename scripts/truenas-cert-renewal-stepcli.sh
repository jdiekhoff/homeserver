#!/bin/bash
#
# TrueNAS Scale Certificate Renewal Script using step-cli
# This script obtains/renews certificates from smallstep ACME server using step-cli
# and uploads them to TrueNAS
#
# Prerequisites:
# - step-cli installed on the system running this script
# - TrueNAS API access configured
# - smallstep ACME server accessible
# - Root CA certificate available
#
# Usage:
#   ./truenas-cert-renewal-stepcli.sh <domain> <truenas-host> <truenas-api-key> <ca-url> <root-ca-path> [cert-name]
#
# Example:
#   ./truenas-cert-renewal-stepcli.sh truenas.home.lab 192.168.1.100 <api-key> https://ca.home.lab /path/to/root-ca.crt truenas-cert

set -euo pipefail

# Configuration
DOMAIN="${1:-}"
TRUENAS_HOST="${2:-}"
TRUENAS_API_KEY="${3:-}"
CA_URL="${4:-}"
ROOT_CA_PATH="${5:-}"
CERT_NAME="${6:-truenas-cert}"
CERT_DIR="${CERT_DIR:-/tmp/truenas-certs}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Validate inputs
if [[ -z "$DOMAIN" || -z "$TRUENAS_HOST" || -z "$TRUENAS_API_KEY" || -z "$CA_URL" || -z "$ROOT_CA_PATH" ]]; then
    log_error "Missing required arguments"
    echo "Usage: $0 <domain> <truenas-host> <truenas-api-key> <ca-url> <root-ca-path> [cert-name]"
    echo "Example: $0 truenas.home.lab 192.168.1.100 <api-key> https://ca.home.lab /path/to/root-ca.crt truenas-cert"
    exit 1
fi

# Check if step-cli is installed
if ! command -v step-cli &> /dev/null; then
    log_error "step-cli is not installed. Please install it first:"
    echo "  Visit: https://smallstep.com/docs/step-cli/installation/"
    exit 1
fi

# Check if root CA file exists
if [[ ! -f "$ROOT_CA_PATH" ]]; then
    log_error "Root CA file not found: $ROOT_CA_PATH"
    exit 1
fi

# Create certificate directory
mkdir -p "$CERT_DIR"

log_info "Starting certificate renewal for domain: $DOMAIN"
log_info "CA URL: $CA_URL"
log_info "TrueNAS Host: $TRUENAS_HOST"
log_info "Certificate Name: $CERT_NAME"

# Step 1: Obtain certificate using step-cli
log_info "Obtaining certificate from smallstep CA..."

CERT_FILE="${CERT_DIR}/${CERT_NAME}.crt"
KEY_FILE="${CERT_DIR}/${CERT_NAME}.key"

if step ca certificate \
    "$DOMAIN" \
    "$CERT_FILE" \
    "$KEY_FILE" \
    --ca-url "$CA_URL" \
    --root "$ROOT_CA_PATH" \
    --force; then
    
    log_info "Certificate obtained successfully"
else
    log_error "Failed to obtain certificate"
    exit 1
fi

if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
    log_error "Certificate files not found at expected locations"
    log_error "Expected: $CERT_FILE and $KEY_FILE"
    exit 1
fi

log_info "Certificate files created:"
log_info "  Certificate: $CERT_FILE"
log_info "  Private Key: $KEY_FILE"

# Step 2: Read certificate and key
CERT_CONTENT=$(cat "$CERT_FILE" | base64 -w 0)
KEY_CONTENT=$(cat "$KEY_FILE" | base64 -w 0)

# Step 3: Upload to TrueNAS via API
log_info "Uploading certificate to TrueNAS..."

# Check if certificate already exists
CERT_ID=$(curl -s -k -X GET \
    "https://${TRUENAS_HOST}/api/v2.0/certificate" \
    -H "Authorization: Bearer ${TRUENAS_API_KEY}" \
    -H "Content-Type: application/json" | \
    jq -r ".[] | select(.name == \"${CERT_NAME}\") | .id" | head -n 1)

if [[ -n "$CERT_ID" && "$CERT_ID" != "null" ]]; then
    log_info "Certificate '${CERT_NAME}' already exists (ID: ${CERT_ID}), updating..."
    
    # Update existing certificate
    RESPONSE=$(curl -s -k -X PUT \
        "https://${TRUENAS_HOST}/api/v2.0/certificate/id/${CERT_ID}" \
        -H "Authorization: Bearer ${TRUENAS_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"certificate\": \"${CERT_CONTENT}\",
            \"privatekey\": \"${KEY_CONTENT}\"
        }")
    
    if echo "$RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
        log_info "Certificate updated successfully"
    else
        log_error "Failed to update certificate"
        echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
        exit 1
    fi
else
    log_info "Creating new certificate in TrueNAS..."
    
    # Create new certificate
    RESPONSE=$(curl -s -k -X POST \
        "https://${TRUENAS_HOST}/api/v2.0/certificate" \
        -H "Authorization: Bearer ${TRUENAS_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${CERT_NAME}\",
            \"certificate\": \"${CERT_CONTENT}\",
            \"privatekey\": \"${KEY_CONTENT}\",
            \"type\": 1,
            \"create_type\": \"CERTIFICATE_CREATE_IMPORTED\"
        }")
    
    if echo "$RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
        NEW_CERT_ID=$(echo "$RESPONSE" | jq -r '.id')
        log_info "Certificate created successfully (ID: ${NEW_CERT_ID})"
    else
        log_error "Failed to create certificate"
        echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
        exit 1
    fi
fi

log_info "Certificate renewal and upload completed successfully!"

# Cleanup temporary files (optional - comment out if you want to keep them for debugging)
# rm -f "$CERT_FILE" "$KEY_FILE"

exit 0
