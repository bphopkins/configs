#!/usr/bin/env bash

# System Information Generator
# Outputs HTML body content to ~/Desktop/sysinfo.html
# Excludes security-sensitive information (serials, MAC addresses, etc.)

set -u

# Require root for dmidecode / lspci / ethtool
if [[ $(id -u) -ne 0 ]]; then
  echo "This script should be run as root (needed for dmidecode, lspci, ethtool)." >&2
  echo "Try: sudo $0" >&2
  exit 1
fi

# Hard-bound output file -- must be edited on other systems for other users
OUTPUT_FILE="/home/bph/Desktop/sysinfo.html"

# Create the directory that actually contains OUTPUT_FILE, and nothing else:
mkdir -p "$(dirname "$OUTPUT_FILE")"

# HTML escaping helper for values
html_escape() {
  local s=$1
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  s=${s//\"/&quot;}
  s=${s//\'/&#39;}
  printf '%s' "$s"
}

# Check whether a command exists
have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Start HTML output
cat >"$OUTPUT_FILE" <<'EOF'
<div class="system-info">
<h2>System Information</h2>

EOF

# Function to add section header
add_section() {
  echo "<h3>$(html_escape "$1")</h3>" >>"$OUTPUT_FILE"
}

# Function to add a key-value pair
add_info() {
  local key=$1
  local value=$2
  echo "<p><strong>$(html_escape "$key"):</strong> $(html_escape "$value")</p>" >>"$OUTPUT_FILE"
}

# ============================================================================
# SYSTEM INFORMATION
# ============================================================================
add_section "System"

SYSTEM_MANUFACTURER="Unknown"
SYSTEM_PRODUCT="Unknown"
SYSTEM_VERSION="Unknown"

if have_cmd dmidecode; then
  SYSTEM_INFO=$(dmidecode -t system 2>/dev/null || true)
  SYSTEM_MANUFACTURER=$(echo "$SYSTEM_INFO" | awk -F: '/Manufacturer:/ {gsub(/^ +/, "", $2); print $2; exit}')
  SYSTEM_PRODUCT=$(echo "$SYSTEM_INFO" | awk -F: '/Product Name:/ {gsub(/^ +/, "", $2); print $2; exit}')
  SYSTEM_VERSION=$(echo "$SYSTEM_INFO" | awk -F: '/Version:/ {gsub(/^ +/, "", $2); print $2; exit}')
fi

: "${SYSTEM_MANUFACTURER:=Unknown}"
: "${SYSTEM_PRODUCT:=Unknown}"
: "${SYSTEM_VERSION:=Unknown}"

add_info "Manufacturer" "$SYSTEM_MANUFACTURER"
add_info "Product" "$SYSTEM_PRODUCT"
add_info "Version" "$SYSTEM_VERSION"

# ============================================================================
# CPU INFORMATION
# ============================================================================
add_section "Processor"

CPU_MODEL="Unknown"
LOGICAL_CPUS="Unknown"
PHYSICAL_CORES="Unknown"
THREADS_PER_CORE="Unknown"
CORES_PER_SOCKET="Unknown"
SOCKETS="Unknown"
CPU_SPEED="Unknown"
CPU_ARCH="Unknown"

if have_cmd lscpu; then
  CPU_MODEL=$(lscpu | awk -F: '/Model name/ {gsub(/^ +/, "", $2); print $2; exit}')
  LOGICAL_CPUS=$(lscpu | awk -F: '/^CPU\(s\)/ {gsub(/^ +/, "", $2); print $2; exit}')
  THREADS_PER_CORE=$(lscpu | awk -F: '/Thread\(s\) per core/ {gsub(/^ +/, "", $2); print $2; exit}')
  CORES_PER_SOCKET=$(lscpu | awk -F: '/Core\(s\) per socket/ {gsub(/^ +/, "", $2); print $2; exit}')
  SOCKETS=$(lscpu | awk -F: '/Socket\(s\)/ {gsub(/^ +/, "", $2); print $2; exit}')
  CPU_ARCH=$(lscpu | awk -F: '/Architecture/ {gsub(/^ +/, "", $2); print $2; exit}')
fi

if [[ "$CORES_PER_SOCKET" =~ ^[0-9]+$ && "$SOCKETS" =~ ^[0-9]+$ ]]; then
  PHYSICAL_CORES=$((CORES_PER_SOCKET * SOCKETS))
fi

if have_cmd dmidecode; then
  CPU_SPEED=$(dmidecode -t processor 2>/dev/null | awk -F: '/Max Speed/ {gsub(/^ +/, "", $2); print $2; exit}')
fi

: "${CPU_MODEL:=Unknown}"
: "${LOGICAL_CPUS:=Unknown}"
: "${PHYSICAL_CORES:=Unknown}"
: "${THREADS_PER_CORE:=Unknown}"
: "${CPU_ARCH:=Unknown}"
: "${CPU_SPEED:=Unknown}"

add_info "Model" "$CPU_MODEL"
add_info "Architecture" "$CPU_ARCH"
add_info "Physical Cores" "$PHYSICAL_CORES"
add_info "Logical CPUs" "$LOGICAL_CPUS"
add_info "Threads per Core" "$THREADS_PER_CORE"
add_info "Max Speed" "$CPU_SPEED"

# ============================================================================
# MEMORY INFORMATION
# ============================================================================
add_section "Memory"

TOTAL_MEM="Unknown"
if have_cmd free; then
  TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2; exit}')
fi

MEM_TYPE="Unknown"
MEM_SPEED="Unknown"
MEM_MODULES="Unknown"
if have_cmd dmidecode; then
  MEM_INFO=$(dmidecode -t memory 2>/dev/null || true)
  MEM_TYPE=$(echo "$MEM_INFO" | awk -F: '/^[[:space:]]*Type:/ && $2 !~ /Unknown|Other|Multifactor/ && $2 !~ /Error/ {gsub(/^ +/, "", $2); print $2; exit}')
  MEM_SPEED=$(echo "$MEM_INFO" | awk -F: '/^[[:space:]]*Speed:/ && $2 !~ /Unknown/ && $2 !~ /Configured/ {gsub(/^ +/, "", $2); print $2; exit}')
  MEM_MODULES=$(echo "$MEM_INFO" | awk '/^[[:space:]]*Size:/ && $2 != "No" {count++} END {print count+0}')
fi

add_info "Total Capacity" "$TOTAL_MEM"
add_info "Type" "$MEM_TYPE"
add_info "Speed" "$MEM_SPEED"
add_info "Modules Installed" "$MEM_MODULES"

# ============================================================================
# STORAGE INFORMATION
# ============================================================================
add_section "Storage"

TOTAL_STORAGE_BYTES=0

if have_cmd lsblk; then
  DISKS=$(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print $1}')
else
  DISKS=""
fi

echo "<ul>" >>"$OUTPUT_FILE"

if [[ -n "$DISKS" ]]; then
  for disk in $DISKS; do
    DISK_SIZE_BYTES=$(lsblk -bdno SIZE "/dev/$disk" 2>/dev/null || echo 0)
    DISK_SIZE_HUMAN=$(lsblk -dno SIZE "/dev/$disk" 2>/dev/null || echo "Unknown")
    DISK_ROTA=$(lsblk -dno ROTA "/dev/$disk" 2>/dev/null || echo 1)

    if [[ "$DISK_ROTA" == "0" ]]; then
      TYPE_NAME="SSD"
    else
      TYPE_NAME="HDD"
    fi

    DISK_MODEL=$(lsblk -dno MODEL "/dev/$disk" 2>/dev/null | xargs)
    if [[ -z "$DISK_MODEL" && -f "/sys/block/$disk/device/model" ]]; then
      DISK_MODEL=$(<"/sys/block/$disk/device/model")
      DISK_MODEL=$(echo "$DISK_MODEL" | xargs)
    fi

    [[ -z "$DISK_MODEL" ]] && DISK_MODEL="Unknown Model"

    echo "<li><strong>$(html_escape "$disk"):</strong> $(html_escape "$DISK_MODEL"), $(html_escape "$DISK_SIZE_HUMAN") $(html_escape "$TYPE_NAME")</li>" >>"$OUTPUT_FILE"

    if [[ "$DISK_SIZE_BYTES" =~ ^[0-9]+$ ]]; then
      TOTAL_STORAGE_BYTES=$((TOTAL_STORAGE_BYTES + DISK_SIZE_BYTES))
    fi
  done
else
  echo "<li>No physical disks detected.</li>" >>"$OUTPUT_FILE"
fi

echo "</ul>" >>"$OUTPUT_FILE"

if [[ ${TOTAL_STORAGE_BYTES:-0} -gt 0 ]]; then
  if have_cmd numfmt; then
    TOTAL_STORAGE_HUMAN=$(numfmt --to=iec-i --suffix=B "$TOTAL_STORAGE_BYTES")
  else
    TOTAL_STORAGE_HUMAN="${TOTAL_STORAGE_BYTES} B"
  fi
  add_info "Total Storage Capacity" "$TOTAL_STORAGE_HUMAN"
else
  add_info "Total Storage Capacity" "Unknown"
fi

# ============================================================================
# NETWORK INFORMATION
# ============================================================================
add_section "Network"

if have_cmd ip; then
  INTERFACES=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2}' | cut -d'@' -f1)
else
  INTERFACES=""
fi

echo "<ul>" >>"$OUTPUT_FILE"

if [[ -n "$INTERFACES" ]]; then
  for iface in $INTERFACES; do
    INFO_STRING="<strong>$(html_escape "$iface"):</strong>"

    DRIVER=""
    SPEED=""
    DEVICE_DESC=""

    if have_cmd ethtool; then
      DRIVER=$(ethtool -i "$iface" 2>/dev/null | awk -F': ' '/driver:/ {print $2; exit}')
      SPEED=$(ethtool "$iface" 2>/dev/null | awk -F': ' '/Speed:/ {print $2; exit}')
    fi

    if have_cmd lspci && [[ -e "/sys/class/net/$iface/device" ]]; then
      PCI_PATH=$(readlink -f "/sys/class/net/$iface/device" 2>/dev/null || true)
      if [[ -n "$PCI_PATH" ]]; then
        PCI_ID=${PCI_PATH##*/}
        DEVICE_DESC=$(lspci -vmm -s "$PCI_ID" 2>/dev/null | awk -F'\t' '/^Device:/ {print $2; exit}')
      fi
    fi

    if [[ -n "$DEVICE_DESC" ]]; then
      INFO_STRING+=" $(html_escape "$DEVICE_DESC")"
    fi
    if [[ -n "$DRIVER" ]]; then
      INFO_STRING+=" (Driver: $(html_escape "$DRIVER"))"
    fi
    if [[ -n "$SPEED" && "$SPEED" != "Unknown!" ]]; then
      INFO_STRING+=" - $(html_escape "$SPEED")"
    fi

    echo "<li>$INFO_STRING</li>" >>"$OUTPUT_FILE"
  done
else
  echo "<li>No non-loopback interfaces detected.</li>" >>"$OUTPUT_FILE"
fi

echo "</ul>" >>"$OUTPUT_FILE"

# ============================================================================
# OPERATING SYSTEM INFORMATION
# ============================================================================
add_section "Operating System"

OS_NAME="Unknown"
if [[ -r /etc/os-release ]]; then
  OS_NAME=$(awk -F= '/^PRETTY_NAME=/ {gsub(/"/, "", $2); print $2; exit}' /etc/os-release)
fi

KERNEL=$(uname -r 2>/dev/null || echo "Unknown")
HOSTNAME=$(hostname 2>/dev/null || echo "Unknown")

add_info "Distribution" "$OS_NAME"
add_info "Kernel Version" "$KERNEL"
add_info "Hostname" "$HOSTNAME"

# Close HTML
echo "</div>" >>"$OUTPUT_FILE"

# Add some basic CSS suggestions as a comment
cat >>"$OUTPUT_FILE" <<'EOF'

<!-- 
Suggested CSS for styling:

.system-info {
    font-family: Arial, sans-serif;
    max-width: 800px;
    margin: 20px auto;
    padding: 20px;
}

.system-info h2 {
    color: #2c3e50;
    border-bottom: 2px solid #3498db;
    padding-bottom: 10px;
}

.system-info h3 {
    color: #34495e;
    margin-top: 25px;
    margin-bottom: 10px;
}

.system-info p {
    margin: 5px 0;
    line-height: 1.6;
}

.system-info ul {
    list-style-type: none;
    padding-left: 0;
}

.system-info li {
    margin: 5px 0;
    padding: 5px;
    background-color: #f8f9fa;
    border-left: 3px solid #3498db;
    padding-left: 10px;
}
-->
EOF

echo "System information has been written to: $OUTPUT_FILE"
echo "You can now copy this file to your laptop and integrate it into your website."
