#!/usr/bin/env bash
# OpenWrt LXC Container Installer for Proxmox
# Author: texy + ChatGPT
# License: MIT

set -euo pipefail

YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
RD=$(echo "\033[01;31m")
CL=$(echo "\033[m")
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

function msg_info() { echo -ne " [..] ${YW}$1...${CL}"; }
function msg_ok() { echo -e " ${CM} ${GN}$1${CL}"; }
function msg_error() { echo -e " ${CROSS} ${RD}$1${CL}"; }

# Default values
VMID=$(pvesh get /cluster/nextid)
HN="openwrt"
STORAGE="local-lvm"
BRG_WAN="vmbr0"
BRG_LAN="vmbr0"
LAN_IP="192.168.1.1/24"
WAN_DHCP="true"

msg_info "Fetching latest OpenWrt release"
VERSION="21.02.4"
ROOTFS_URL="https://downloads.openwrt.org/releases/${VERSION}/targets/x86/64/openwrt-${VERSION}-x86-64-rootfs.tar.gz"
wget -q "$ROOTFS_URL" -O /tmp/openwrt-rootfs.tar.gz
msg_ok "Downloaded OpenWrt rootfs ${VERSION}"

msg_info "Creating LXC container (VMID ${VMID})"
pct create $VMID /tmp/openwrt-rootfs.tar.gz \
  -arch amd64 \
  -hostname $HN \
  -cores 1 \
  -memory 256 \
  -swap 0 \
  -net0 name=lan,bridge=$BRG_LAN,hwaddr=02:$(openssl rand -hex 5 | sed 's/\(..\)/\1:/g; s/.$//') \
  -net1 name=wan,bridge=$BRG_WAN,hwaddr=02:$(openssl rand -hex 5 | sed 's/\(..\)/\1:/g; s/.$//') \
  -rootfs $STORAGE:1 \
  -unprivileged 0 \
  -features nesting=1
msg_ok "Container created"

msg_info "Configuring OpenWrt networking"
cat <<EOF > /etc/pve/lxc/${VMID}.conf
arch: amd64
cores: 1
hostname: $HN
memory: 256
net0: name=lan,bridge=$BRG_LAN,firewall=1
net1: name=wan,bridge=$BRG_WAN,firewall=1
rootfs: $STORAGE:1
ostype: unmanaged
unprivileged: 0
features: nesting=1
EOF
msg_ok "Networking set: LAN=$LAN_IP, WAN=dhcp"

msg_info "Starting container"
pct start $VMID
sleep 5
msg_ok "OpenWrt LXC ${HN} started (VMID $VMID)"
echo -e "\n${GN}Login via:${CL} pct attach $VMID\n"
