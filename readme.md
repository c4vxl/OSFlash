# OS Flash

A utility for saving and flashing fully configured Linux installations.

---

## About

OS Flash allows you to save a fully configured Linux installation by capturing the Linux partitions into `.img` files and compressing them. Using the custom installer, you can then flash these stored installations onto the same or a different computer.

---

## Usage

#### Saving Your Installation

To save a Linux installation, run the `pack.sh` script with the following parameters:

```shell
sudo sh pack.sh --efi=<efi_partition> --root=<root_partition> [--no-compress] [--out=<output_dir>]
```

Parameters:

--`efi=<efi_partition>`: Path to the EFI partition.
--`root=<root_partition>`: Path to the root partition.
--`out=<output_dir>`: Directory where the installation will be saved. (Default: ./osconfig/)
--`no-compress`: Prevents compression of the installation. (_Note: The osflash.sh script only works with compressed installations!_)

Each saved installation will include an install.sh script, which allows you to directly flash the installation to a new system without using the osflash menu.

#### Flashing Your Installation
To flash a saved installation onto a computer, use the osflash.sh script. This script allows you to create and edit partitions and then flash a saved installation onto them.

1. Place all your compressed installations into the `INSTALLER_PACKAGE_DIR` directory (Default: `./installers`).
2. Run the `osflash.sh` script. (```sudo sh osflash.sh```)
3. Follow the prompts to complete the installation.

##### Alternative: Use the install.sh Script
Each installation saved with pack.sh includes an install.sh script. You can use this script to install the saved system without using the osflash.sh menu. Here's a list of additional options for the script:
- `--efi=<partition>`: Path to the EFI partition.
- `--root=<partition>`: Path to the root partition.
- `--supress-chroot`: Skips the automatic chroot into the new installation
- `--no-mount`: Prevents mounting the installation after the flash. This also suppresses chroot.
- `--mount=<dir>`: Mount the installed system to the specified directory after installation (mostly for testing purposes).
- `--efi-img=<img>`: Specify an alternative path for the EFI image (default: img/efi.img).
- `--root-img=<img>`: Specify an alternative path for the root image (default: img/root.img).
- `--swap=<size>`: Create a swap file of the specified size after installation. Requires `--no-mount` to be not specified.
- `--y`: Automatically answer all yes/no prompts with "yes".
- `--no-fix`: Skips automatic partition error checks.

---

Made by [c4vxl](https://c4vxl.de/)