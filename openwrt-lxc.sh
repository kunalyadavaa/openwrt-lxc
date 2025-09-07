#!/usr/bin/env bash
# OpenWrt LXC Installer for Proxmox
# Based on community-scripts framework
# Author: texy + ChatGPT
# License: MIT

APP="openwrt"
var_tags="${var_tags:-os}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-256}"
var_disk="${var_disk:-1}"
var_unprivileged="${var_unprivileged:-0}"   # OpenWrt works best privileged
var_os="unmanaged"
var_version="21.02.4"

# Load community-scripts functions
source <(curl -fsSL https://git.community-scripts.org/community-scripts/ProxmoxVE/raw/branch/main/misc/build.func)

header_info "$APP"
variables
color
catch_errors

function update_script() {
  msg_error "No update routine for OpenWrt. Recreate container instead."
  exit
}

# Ensure storage supports rootdir
function detect_storage() {
  while read -r id type rest; do
    if pvesh get /storage/$id --output-format json | grep -q rootdir; then
      echo "$id"
      return
    fi
  done < <(pvesh get /storage --output-format=json | jq -r '.[].storage + " " + .type')
  msg_error "No storage with 'rootdir' support found!"
  exit 1
}

function build_container_config() {
  # Fetch OpenWrt rootfs
  ROOTFS_URL="https://downloads.openwrt.org/releases/${var_version}/targets/x86/64/openwrt-${var_version}-x86-64-rootfs.tar.gz"
  msg_info "Downloading OpenWrt rootfs ${var_version}"
  wget -q "$ROOTFS_URL" -O /tmp/openwrt-rootfs.tar.gz
  msg_ok "Downloaded OpenWrt rootfs"

  STORAGE=$(detect_storage)

  msg_info "Creating LXC container (VMID ${CTID})"
  pct create $CTID /tmp/openwrt-rootfs.tar.gz \
    -arch amd64 \
    -hostname $HN \
    -cores $var_cpu \
    -memory $var_ram \
    -swap 0 \
    -net0 name=lan,bridge=vmbr0,firewall=1 \
    -net1 name=wan,bridge=vmbr0,firewall=1 \
    -rootfs $STORAGE:${var_disk} \
    -unprivileged $var_unprivileged \
    -features nesting=1 \
    -ostype unmanaged
  msg_ok "Container created"
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} LXC has been successfully initialized!${CL}"
echo -e "${INFO}${YW} You can attach with:${CL} pct attach ${CTID}"
