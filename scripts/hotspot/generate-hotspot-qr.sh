#!/bin/bash

#***********************************************************************
# Generate Wi‑Fi QR Code for MuSoHu Hotspot
#***********************************************************************
# Creates a QR code that mobile devices can scan to join the hotspot.
# Works with NetworkManager "Hotspot" profile or explicit SSID/password.
#
# QR format (Wi‑Fi Alliance):
#   WIFI:T:<WPA|WEP|nopass>;S:<SSID>;P:<password>;H:<true|false>;;
#
# Dependencies:
#   - qrencode (sudo apt install qrencode)
#   - nmcli (NetworkManager) for auto-detection (optional)
#
# Usage examples:
#   bash scripts/hotspot/generate-hotspot-qr.sh --ascii
#   bash scripts/hotspot/generate-hotspot-qr.sh -s Robotixx_MuSoHu -p Robotixx -o hotspot.png
#   bash scripts/hotspot/generate-hotspot-qr.sh --from-nm Hotspot -o hotspot.png
#***********************************************************************

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OUTPUT="${SCRIPT_DIR}/hotspot-qr.png"
SSID=""
PASSWORD=""
AUTH_TYPE="WPA"   # WPA, WEP, nopass
HIDDEN="false"
OUTPUT="$DEFAULT_OUTPUT"
FROM_NM=""        # Connection name to read from (e.g., Hotspot)
ASCII_ONLY=false

print_help() {
  cat << EOF
Generate Wi‑Fi QR Code for MuSoHu Hotspot

Options:
  -s, --ssid <name>          SSID (Wi‑Fi name)
  -p, --password <pass>      Wi‑Fi password (ignored if --auth nopass)
  -t, --auth <WPA|WEP|nopass>Authentication type (default: WPA)
  -H, --hidden               Mark SSID as hidden in QR
  -o, --output <file.png>    Output PNG file path (default: ${DEFAULT_OUTPUT})
      --ascii                Print QR to terminal instead of PNG (no output file)
      --from-nm <name>       Read SSID/password from NetworkManager connection (e.g., Hotspot)
  -h, --help                 Show this help

Examples:
  # Print QR in terminal for default MuSoHu hotspot
  $(basename "$0") --ascii --ssid Robotixx_MuSoHu --password Robotixx

  # Generate PNG using NetworkManager's 'Hotspot' profile
  $(basename "$0") --from-nm Hotspot -o hotspot.png

EOF
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] Missing dependency: $1" >&2
    echo "        Install on Ubuntu/Debian: sudo apt install $1" >&2
    exit 1
  fi
}

read_nm_field() {
  local conn="$1" key="$2"
  nmcli -g "$key" connection show "$conn" 2>/dev/null | head -n1 | tr -d '\n'
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--ssid) SSID="$2"; shift 2 ;;
    -p|--password) PASSWORD="$2"; shift 2 ;;
    -t|--auth) AUTH_TYPE="$2"; shift 2 ;;
    -H|--hidden) HIDDEN="true"; shift ;;
    -o|--output) OUTPUT="$2"; shift 2 ;;
    --ascii) ASCII_ONLY=true; shift ;;
    --from-nm) FROM_NM="$2"; shift 2 ;;
    -h|--help) print_help; exit 0 ;;
    *) echo "Unknown option: $1" >&2; print_help; exit 1 ;;
  esac
done

need_cmd qrencode

# Auto-detect from NetworkManager if requested
if [[ -n "$FROM_NM" ]]; then
  need_cmd nmcli
  if [[ -z "$SSID" ]]; then
    # Property name varies across NM versions; try both
    SSID=$(read_nm_field "$FROM_NM" 802-11-wireless.ssid)
    if [[ -z "$SSID" ]]; then
      SSID=$(read_nm_field "$FROM_NM" wifi.ssid)
    fi
  fi
  if [[ -z "$PASSWORD" && "$AUTH_TYPE" != "nopass" ]]; then
    PASSWORD=$(read_nm_field "$FROM_NM" 802-11-wireless-security.psk)
    if [[ -z "$PASSWORD" ]]; then
      PASSWORD=$(read_nm_field "$FROM_NM" wifi-sec.psk)
    fi
  fi
fi

# Fallback to known MuSoHu defaults if still empty
if [[ -z "$SSID" ]]; then SSID="Robotixx_MuSoHu"; fi
if [[ "$AUTH_TYPE" != "nopass" && -z "$PASSWORD" ]]; then PASSWORD="Robotixx"; fi

# Validate
if [[ "$AUTH_TYPE" != "WPA" && "$AUTH_TYPE" != "WEP" && "$AUTH_TYPE" != "nopass" ]]; then
  echo "[ERROR] Invalid --auth value: $AUTH_TYPE (use WPA, WEP, or nopass)" >&2
  exit 1
fi

if [[ "$AUTH_TYPE" != "nopass" && -z "$PASSWORD" ]]; then
  echo "[ERROR] Password required unless --auth nopass" >&2
  exit 1
fi

# Build Wi‑Fi QR payload
QR_PAYLOAD="WIFI:T:${AUTH_TYPE};S:${SSID};"
if [[ "$AUTH_TYPE" != "nopass" ]]; then
  QR_PAYLOAD+="P:${PASSWORD};"
fi
QR_PAYLOAD+="H:${HIDDEN};;"

if $ASCII_ONLY; then
  qrencode -t ANSIUTF8 "$QR_PAYLOAD"
else
  qrencode -o "$OUTPUT" -s 8 -l H "$QR_PAYLOAD"
  echo "[SUCCESS] QR code written to: $OUTPUT"
  echo "Scan to join: SSID='${SSID}', security='${AUTH_TYPE}'"
fi
