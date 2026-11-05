#!/usr/bin/env bash
# Creates the Debian 12 cloud-init template used by the lab. Run it ONCE, as root, on the Proxmox node.
#   bash create-debian-template.sh [VMID] [STORAGE] [BRIDGE]
set -euo pipefail

VMID="${1:-9000}"
STORAGE="${2:-local-lvm}"
BRIDGE="${3:-vmbr0}"
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
IMAGE="/var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2"

[[ $EUID -eq 0 ]] || { echo "Run as root on the Proxmox node."; exit 1; }
command -v qm >/dev/null || { echo "qm not found: this script runs on a Proxmox VE node."; exit 1; }
if qm status "$VMID" >/dev/null 2>&1; then echo "VM $VMID already exists: choose another ID."; exit 1; fi

echo "==> Downloading the Debian 12 cloud image"
mkdir -p "$(dirname "$IMAGE")"
wget -q --show-progress -O "$IMAGE" "$IMAGE_URL"

echo "==> Creating template $VMID on $STORAGE"
qm create "$VMID" --name debian-12-cloudinit --memory 1024 --cores 1 --cpu host \
  --net0 "virtio,bridge=${BRIDGE}" --scsihw virtio-scsi-single --ostype l26 \
  --serial0 socket --vga serial0 --agent enabled=1
qm set "$VMID" --scsi0 "${STORAGE}:0,import-from=${IMAGE},discard=on,iothread=1"
qm set "$VMID" --ide2 "${STORAGE}:cloudinit" --boot order=scsi0
qm template "$VMID"

echo "==> Enabling cloud-init snippets on the 'local' storage"
CONTENT=$(pvesm config local 2>/dev/null | awk '/content/{print $2}' || true)
if [[ -n "$CONTENT" && "$CONTENT" != *snippets* ]]; then
  pvesm set local --content "${CONTENT},snippets"
fi

echo "Done: template ${VMID} is ready. Next: terraform apply (see README)."
