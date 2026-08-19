#!/bin/bash
#
# CoreDNS DNS-01 Challenge Script for ACME
# This script adds and removes TXT records for ACME DNS-01 challenges
# Compatible with TrueNAS ACME DNS-Authenticator shell interface
#
# Usage:
#   For TrueNAS: This script is called by TrueNAS with specific parameters
#   Manual: ./coredns-dns01-challenge.sh <action> <domain> <txt-value> [zone-file]
#
# Actions:
#   present - Add TXT record
#   cleanup - Remove TXT record
#
# TrueNAS calls this script with:
#   <script> <action> <domain> <txt-value>
#
# Example:
#   ./coredns-dns01-challenge.sh present _acme-challenge.truenas.home.lab "challenge-token" /path/to/db.home.lab

set -euo pipefail

# Configuration
ACTION="${1:-}"
FQDN="${2:-}"
TXT_VALUE="${3:-}"
ZONE_FILE="${4:-/mnt/media/coredns/db.home.lab}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Validate inputs
if [[ -z "$ACTION" || -z "$FQDN" || -z "$TXT_VALUE" ]]; then
    log_error "Missing required arguments"
    echo "Usage: $0 <action> <fqdn> <txt-value> [zone-file]"
    echo "Actions: present, cleanup"
    echo "Example: $0 present _acme-challenge.truenas.home.lab \"challenge-token\""
    exit 1
fi

# Extract domain and subdomain
# FQDN format: _acme-challenge.truenas.home.lab
# We need to extract: _acme-challenge (record name) and truenas.home.lab (zone)
if [[ ! "$FQDN" =~ ^_acme-challenge\.(.+)$ ]]; then
    log_error "Invalid FQDN format. Expected: _acme-challenge.<domain>"
    exit 1
fi

RECORD_NAME="_acme-challenge"
DOMAIN="${BASH_REMATCH[1]}"

# Determine zone from domain (assuming format like truenas.home.lab -> home.lab zone)
# This is a simple heuristic - adjust based on your DNS structure
ZONE=$(echo "$DOMAIN" | sed 's/^[^.]*\.//')  # Remove first label
if [[ -z "$ZONE" ]]; then
    ZONE="$DOMAIN"
fi

log_info "Action: $ACTION"
log_info "FQDN: $FQDN"
log_info "Domain: $DOMAIN"
log_info "Zone: $ZONE"
log_info "Zone file: $ZONE_FILE"

# Check if zone file exists
if [[ ! -f "$ZONE_FILE" ]]; then
    log_error "Zone file not found: $ZONE_FILE"
    log_error "Please update ZONE_FILE variable or provide it as the 4th argument"
    exit 1
fi

# Backup zone file
BACKUP_FILE="${ZONE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$ZONE_FILE" "$BACKUP_FILE"
log_info "Backed up zone file to: $BACKUP_FILE"

case "$ACTION" in
    present)
        log_info "Adding TXT record: $RECORD_NAME.$DOMAIN -> $TXT_VALUE"
        
        # Check if record already exists
        if grep -q "^${RECORD_NAME}\.${DOMAIN}\." "$ZONE_FILE"; then
            log_warn "TXT record already exists, updating..."
            # Remove existing record
            sed -i "/^${RECORD_NAME}\.${DOMAIN}\./d" "$ZONE_FILE"
        fi
        
        # Add new TXT record
        # Format: _acme-challenge.truenas.home.lab. 300 IN TXT "challenge-token"
        # Note: Adjust TTL (300) and record format based on your zone file structure
        echo "${RECORD_NAME}.${DOMAIN}.    300    IN    TXT    \"${TXT_VALUE}\"" >> "$ZONE_FILE"
        
        # Update SOA serial (increment by 1)
        # This is a simple approach - adjust based on your zone file format
        if grep -q "; serial" "$ZONE_FILE"; then
            # If zone file has comment format
            sed -i 's/\([0-9]\{10\}\)\(.*; serial\)/'"$(date +%Y%m%d%H)"'\2/' "$ZONE_FILE" || true
        else
            # Try to find and increment serial number
            SERIAL=$(grep -i "SOA" "$ZONE_FILE" | head -1 | awk '{print $7}' || echo "")
            if [[ -n "$SERIAL" ]]; then
                NEW_SERIAL=$((SERIAL + 1))
                sed -i "s/${SERIAL}/${NEW_SERIAL}/" "$ZONE_FILE" || true
            fi
        fi
        
        log_info "TXT record added successfully"
        
        # Reload CoreDNS (if using file plugin with auto-reload, this may not be needed)
        # Option 1: Send SIGHUP to CoreDNS container
        if command -v docker &> /dev/null; then
            CONTAINER_ID=$(docker ps --filter "ancestor=coredns/coredns" --format "{{.ID}}" | head -1)
            if [[ -n "$CONTAINER_ID" ]]; then
                log_info "Reloading CoreDNS container..."
                docker kill --signal=SIGHUP "$CONTAINER_ID" 2>/dev/null || true
            fi
        fi
        
        # Option 2: If CoreDNS is watching the file, it should auto-reload
        # Option 3: Restart CoreDNS container (uncomment if needed)
        # docker restart coredns 2>/dev/null || true
        
        # Wait for DNS propagation (adjust based on your environment)
        PROPAGATION_DELAY="${PROPAGATION_DELAY:-5}"
        log_info "Waiting ${PROPAGATION_DELAY} seconds for DNS propagation..."
        sleep "$PROPAGATION_DELAY"
        
        # Verify record was added
        if grep -q "^${RECORD_NAME}\.${DOMAIN}\." "$ZONE_FILE"; then
            log_info "TXT record verified in zone file"
        else
            log_error "TXT record not found in zone file after addition"
            exit 1
        fi
        ;;
        
    cleanup)
        log_info "Removing TXT record: $RECORD_NAME.$DOMAIN"
        
        # Remove TXT record
        if grep -q "^${RECORD_NAME}\.${DOMAIN}\." "$ZONE_FILE"; then
            sed -i "/^${RECORD_NAME}\.${DOMAIN}\./d" "$ZONE_FILE"
            log_info "TXT record removed successfully"
            
            # Update SOA serial
            SERIAL=$(grep -i "SOA" "$ZONE_FILE" | head -1 | awk '{print $7}' || echo "")
            if [[ -n "$SERIAL" ]]; then
                NEW_SERIAL=$((SERIAL + 1))
                sed -i "s/${SERIAL}/${NEW_SERIAL}/" "$ZONE_FILE" || true
            fi
            
            # Reload CoreDNS
            if command -v docker &> /dev/null; then
                CONTAINER_ID=$(docker ps --filter "ancestor=coredns/coredns" --format "{{.ID}}" | head -1)
                if [[ -n "$CONTAINER_ID" ]]; then
                    log_info "Reloading CoreDNS container..."
                    docker kill --signal=SIGHUP "$CONTAINER_ID" 2>/dev/null || true
                fi
            fi
        else
            log_warn "TXT record not found, nothing to clean up"
        fi
        ;;
        
    *)
        log_error "Invalid action: $ACTION"
        echo "Valid actions: present, cleanup"
        exit 1
        ;;
esac

log_info "DNS-01 challenge script completed successfully"
exit 0
