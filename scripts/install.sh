#!/bin/bash

EFI_IMG="./img/efi.img"
ROOT_IMG="./img/root.img"
SUPPRESS_CHROOT=false
NO_MOUNT=false
MOUNTING_DIR="./test"
SWAP_SIZE=false
NO_CONFIRM=false
NO_FIX=false

# parse arguments
for ARG in "$@"; do
  case $ARG in
    --efi=*)
      EFI_PART="${ARG#*=}"
      ;;
    --root=*)
      ROOT_PART="${ARG#*=}"
      ;;
    --suppress-chroot)
      SUPPRESS_CHROOT=true
      ;;
    --no-mount)
      NO_MOUNT=true
      SUPPRESS_CHROOT=true
      SWAP_SIZE=false
      ;;
    --mount=*)
      MOUNTING_DIR="${ARG#*=}"
      NO_MOUNT=false
      ;;
    --swap=*)
      SWAP_SIZE="${ARG#*=}"
      ;;
    --efi-img=*)
      EFI_IMG="${ARG#*=}"
      ;;
    --root-img=*)
      ROOT_IMG="${ARG#*=}"
      ;;
    --y)
      NO_CONFIRM=true
      ;;
    --no-fix)
      NO_FIX=true
      ;;
      
    *)
      echo ">> Usage: $0 --efi=<efi_partition> --root=<root_partition> [--efi-img=<img>] [--root-img=<img>] [--suppress-chroot] [--no-mount] [--mount=<mount_dir>] [--swap=<swap_size>] [--y] [--no-fix]"
      echo ">> Example: $0 --efi=/dev/sda1 --root=/dev/sda2 [--efi-img=img/efi.img] [--root-img=img/root.img] [--suppress-chroot] [--no-mount] [--mount=test] [--no-swap] [--swap=1G] [--y] [--no-fix]"
      exit 1
      ;;
  esac
done

# ensure efi and root are specified
if [ -z "$EFI_PART" ] || [ -z "$ROOT_PART" ]; then
  echo "Error: Both --efi and --root must be specified."
  exit 1
fi

# ensure partitions exist
if [ ! -b "$EFI_PART" ]; then
  echo ">> Error: EFI partition $EFI_PART does not exist."
  exit 1
fi

if [ ! -b "$ROOT_PART" ]; then
  echo ">> Error: Root partition $ROOT_PART does not exist."
  exit 1
fi

# check if images exist
if [ ! -f "$EFI_IMG" ] || [ ! -f "$ROOT_IMG" ]; then
  echo ">> Error: One or both image files ($EFI_IMG, $ROOT_IMG) are missing."
  exit 1
fi

# Ask for confirmation
echo ">> You are about to write the following images to partitions:"
echo " |  EFI: $EFI_IMG -> $EFI_PART"
echo " |  Root: $ROOT_IMG -> $ROOT_PART"
if [ "$NO_CONFIRM" = false ]; then
  echo ">> WARNING: This will overwrite data on these partitions!"
  read -p ">> Are you sure you want to continue? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo ">> Operation canceled."
    exit 0
  fi
fi

# unmount partitions
echo ">> Unmounting partitions..."
sudo umount "$EFI_PART" 2>/dev/null || true
sudo umount "$ROOT_PART" 2>/dev/null || true

# write partitions
echo ">> Writing EFI image to $EFI_PART..."
sudo dd if="$EFI_IMG" of="$EFI_PART" bs=4M status=progress 2>/dev/null || true

echo ">> Writing root image to $ROOT_PART..."
sudo dd if="$ROOT_IMG" of="$ROOT_PART" bs=4M status=progress 2>/dev/null || true

# Fix partitions
if [ "$NO_FIX" = false ]; then
  echo ">> Fixing unallocated space in partitions..."
  sudo e2fsck -f $EFI_PART
  sudo parted $EFI_PART --script resizepart 1 100%
  sudo resize2fs $EFI_PART

  sudo e2fsck -f $ROOT_PART
  sudo parted $ROOT_PART --script resizepart 1 100%
  sudo resize2fs $ROOT_PART
fi

# Mount partitions
if [ "$NO_MOUNT" = false ]; then
  echo ">> Copied images successfully! Mounting system to $MOUNTING_DIR!"
  mkdir -p $MOUNTING_DIR
  mount "$ROOT_PART" $MOUNTING_DIR
  mount "$EFI_PART" $MOUNTING_DIR/boot/efi
else
  echo ">> Copied images successfully!"
fi

# Make swap
if [ ! "$SWAP_SIZE" = false ]; then
  echo ">> Creating swap file of size $SWAP_SIZE"
  sudo fallocate -l $SWAP_SIZE $MOUNTING_DIR/swapfile
  sudo chmod 600 $MOUNTING_DIR/swapfile
  sudo mkswap $MOUNTING_DIR/swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a $MOUNTING_DIR/etc/fstab
else
  echo ">> No swap file is being generated!"
fi


# chroot if not suppressed
if [ "$SUPPRESS_CHROOT" = false ]; then
  echo ">> Chrooting into $MOUNTING_DIR..."
  sudo arch-chroot $MOUNTING_DIR
else
  echo ">> Chroot suppressed. Skipping $MOUNTING_DIR."
fi

# Finish message
echo ">> Installation completed successfully!"
echo ">> Images have been written to the specified partitions:"
echo " |  EFI: $EFI_PART"
echo " |  Root: $ROOT_PART"