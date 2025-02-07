#!/bin/sh
EFI_PART=""
ROOT_PART=""
OUTPUT="./osconfig/"
DO_COMPRESS=true

for ARG in "$@"; do
  case $ARG in
    --efi=*)
      EFI_PART="${ARG#*=}"
      ;;
    --root=*)
      ROOT_PART="${ARG#*=}"
      ;;
    --no-compress)
      DO_COMPRESS=false
      ;;
    --out=*)
      OUTPUT="${ARG#*=}"
      ;;
    *)
      echo ">> Usage: $0 --efi=<efi_partition> --root=<root_partition> [--no-compress] [--out=<output_dir>]"
      echo ">> Example: $0 --efi=/dev/sda1 --root=/dev/sda2 [--no-compress] [--out=./osconfig/]"
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

mkdir -p $OUTPUT
cd $OUTPUT

# Compress partitions
mkdir img
cd img
echo ">> Compressing partitions..."
echo "  | Compressing EFI..."
sudo dd if=$EFI_PART of=efi.img bs=4M status=progress &> /dev/null
echo "  | Compressing Root..."
sudo dd if=$ROOT_PART of=root.img bs=4M status=progress &> /dev/null
cd ..

# Download install script
echo ">> Downloading installation script..."
curl -o install.sh https://api.c4vxl.de/cdn/osflash/.os_install

# Compress
if [[ "$DO_COMPRESS" == "true" ]]; then
    echo ">> Compressing..."
    tar -czvf compressed.tar.gz install.sh img/
    echo "  | Compression complete!"
else
    echo ">> Skipping compression!"
fi

echo "Done!"