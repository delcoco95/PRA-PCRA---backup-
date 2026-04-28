#!/bin/bash
# Fix GRUB to boot kernel 5.15.0-161-generic (has DRBD module)
set -e

ENTRY="gnulinux-advanced-5dfae32d-dfb4-4b6f-adea-ab7dc96647bc>gnulinux-5.15.0-161-generic-advanced-5dfae32d-dfb4-4b6f-adea-ab7dc96647bc"

# Enable saved default
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' /etc/default/grub

# Set the saved default entry
grub-set-default "$ENTRY"

# Update grub
update-grub

echo "GRUB configured. Next boot will use kernel 5.15.0-161-generic"
echo "Current saved entry:"
cat /boot/grub/grubenv | grep saved
