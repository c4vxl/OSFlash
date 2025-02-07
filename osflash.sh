#!/bin/sh
INSTALLER_PACKAGE_DIR="./installers"
INSTALLATION_DIR="./install-runtime"

function list_os_types() {
    local -n res="$1"

    ls $INSTALLER_PACKAGE_DIR/*.tar.gz | xargs -n 1 basename | sed 's/\.tar\.gz$//' | awk '
    BEGIN { printf "%-3d %-30s \n", "ID", "NAME" }
    { printf "%-3d %-30s \n", ++i, $1 }'

    res=($(ls $INSTALLER_PACKAGE_DIR/*.tar.gz))
}

function list_parts() {
    local -n res="$1"

    lsblk -prno NAME,SIZE,TYPE,FSTYPE,PARTLABEL | awk '
        BEGIN { printf "%-3s %-30s %-7s %-15s %-10s\n", "ID", "NAME", "SIZE", "TYPE", "LABEL" }
        $3 == "part" { printf "%-3d %-30s %-7s %-15s %-10s\n", ++i, $1, $2, $4, ($5 ? $5 : "-") }
        '
    
    res=($(lsblk -prno NAME,SIZE,FSTYPE,PARTLABEL,TYPE | awk '$5 == "part" || $4 == "part" { print $1 }'))
}

function list_disks() {
    local -n res="$1"

    lsblk -prno NAME,SIZE,FSTYPE,PARTLABEL,TYPE | awk '
        BEGIN { printf "%-3s %-30s %-7s\n", "ID", "NAME", "SIZE" }
        $3 == "disk" { printf "%-3d %-30s %-7s\n", ++i, $1, $2 }'
    
    res=($(lsblk -prno NAME,SIZE,FSTYPE,PARTLABEL,TYPE | awk '$3 == "disk"'))
}

function create_partition() {
    # Usage: create_partition $device $type $size $label
    local -n res="$5"

    # Create partition
    echo ">> Creating partition..."
    echo -e "n\n\n\n+$3\nw\n" | sudo fdisk $1 &> /dev/null
    partition=$(lsblk -prno NAME | grep "$1" | tail -n 1)
    echo ">> Configuration:"
    echo "  | Device:  $1"
    echo "  | Type:    $2"
    echo "  | Size:    $3"
    echo "  | Label:   $4"
    echo "  | Path:    $partition"

    # Format partition
    format_partition $partition "$2"

    # Label partition:
    rename_partition $partition "$4"

    res="$partition"
}

function rename_partition() {
    # Usage: rename_partition $partition $label
    echo ">> Changing Label..."
    sudo e2label "$1" "$2" &> /dev/null
}

function resize_partition() {
    # Usage: resize_partition $partition $size
    echo ">> Resizing..."
    sudo parted /dev/$1 resizepart N "$2" &> /dev/null
    sudo resize2fs /dev/$1 &> /dev/null
}

function format_partition() {
    # Usage: format_partition $partition $type
    echo ">> Formating partition..."
    eval "sudo mkfs --type=$2 $1 &> /dev/null"
}

function ask_for_os() {
    local -n res="$1"

    i=false
    while true; do
        clear

        if [[ "$i" == "true" ]]; then
            echo ">> Invalid Installer! Try again!"
        fi

        echo ">> List of installers:"
        list_os_types installers
        echo ""
        echo "======================================================="
        echo ""
        read -p "Select the installation: " selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection > 0 && selection <= ${#installers[@]} )); then
            selection=${installers[$(($selection-1))]}
            break
        fi

        i=true
    done

    res=$selection
}

function edit_partition() {
    # Usage: edit_partition $partition $defaulttype
    label=$(lsblk -o NAME,LABEL -n -d "$1" | awk '{print $2}')
    size=($(lsblk -o NAME,SIZE -n -d "$1" | awk '{print $2}'))

    echo ">> Editing partition $1:"

    # FS Type
    read -p "  | File System Type (Default: $2): " type
    type=${type:-$2}

    # Size
    read -p "  | Size (Default: $size): " size_n
    size_n=${size_n:-$size}

    # Label
    read -p "  | Label (Default: $label): " label_n
    label=${label_n:-$label}

    format_partition "$1" "$type"
    if [[ "$size_n" != "$size" ]]; then
        resize_partition "$1" "$size"
    fi
    rename_partition "$1" "$label"
}

function ask_for_partition() {
    # Usage: ask_for_partition $name $type $size
    local -n res="$4"
    
    echo ">> List of partitions:"
    list_parts partitions
    echo ""
    echo "======================================================="
    echo ""
    echo ">> Enter a '$2'-partition ($1):"

    read -p "  | Partition (Leave empty to create one): " selection

    i=false
    if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection > 0 && selection <= ${#partitions[@]} )); then
        partition=${partitions[$(($selection-1))]}
        
        read -p "  | Do you wish to make any changes to the configuration of this partition? (y/n): " edit

        if [[ "$edit" == "y" ]]; then
            edit_partition "$partition" "$2"
            echo "E  | diting complete."
        fi
    else
        while true; do
            clear

            if [[ "$i" == "true" ]]; then
                echo ">> Invalid Disk! Try again!"
            fi

            list_disks disks
            echo ""
            echo "======================================================="
            echo ""

            echo ">> This partition does not exist! Entering creation mode..."
            read -p "  | Device: " selection
            read -p "  | Label: " label
            read -p "  | Size (Default: $3): " size
            read -p "  | Type (Default: $2): " type
            size=${size:-$3}
            type=${type:-$2}
            
            if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection > 0 && selection <= ${#disks[@]} )); then
                device=${disks[$(($selection-1))]}

                create_partition "$device" "$type" "$size" "$label" partition
                break
            fi

            i="true"
        done
    fi

    res="$partition"
}

################################## USER INPUTS ##################################

# Ask for EFI Partition
clear
ask_for_partition "EFI Partition" "fat -F 32" "33MiB" efi_part
read -p "Done. Press 'ENTER' to continue." x

# Ask for Root Partition
clear
ask_for_partition "ROOT Partition" "ext4" "16G" root_part
read -p "Done. Press 'ENTER' to continue." x

# Ask for chroot
clear
read -p "Do you want to chroot into your setup after installing? (y/n): " use_chroot
use_chroot=${use_chroot:-"y"}

# Ask for mounting dir
clear
read -p "Where would you like to mount your installation after finishing? (Default: ./test): " mount_dir
mount_dir=${mount_dir:-"./test"}

# Ask for swap size
clear
read -p "Size of swap (Default: 4G): " swap_size
swap_size=${swap_size:-4G}

# Ask for os
clear
ask_for_os installer

# Output config
clear
echo ">> Your final configuration:"
echo "  | EFI Partition:      $efi_part"
echo "  | Root Partition:     $root_part"
echo "  | Use chroot:         $use_chroot"
echo "  | Mount to:           $mount_dir"
echo "  | Swap size:          $swap_size"
echo "  | Installer:          $installer"

################################## USER INPUTS ##################################


################################## RUN INSTALLATION ##################################

# Prepare installation environment
echo ">> Uncompressing installer..."
sudo umount -R $INSTALLATION_DIR/* &> /dev/null
sudo rm -Rf $INSTALLATION_DIR
sudo mkdir $INSTALLATION_DIR
sudo tar -xzvf $installer -C $INSTALLATION_DIR

# Install
echo ">> Starting installation process..."
clear
cd $INSTALLATION_DIR

if [[ "$use_chroot" == "n" ]]; then
    command="sudo sh install.sh --efi='$efi_part' --root='$root_part' --mount='$mount_dir' --swap='$swap_size' --y --suppress-chroot"
else
    command="sudo sh install.sh --efi='$efi_part' --root='$root_part' --mount='$mount_dir' --swap='$swap_size' --y"
fi

echo ">> Your configuration:"
echo "  | EFI Partition:      $efi_part"
echo "  | Root Partition:     $root_part"
echo "  | Use chroot:         $use_chroot"
echo "  | Mount to:           $mount_dir"
echo "  | Swap size:          $swap_size"
echo "  | Installer:          $installer"

echo ">> Running installation command: '$command'"
read -p "Done. Press 'ENTER' to continue." x

clear

eval $command
################################## RUN INSTALLATION ##################################

################################## CLEANUP ##################################
echo ">> Installation complete!"
read -p "Do you wish to unmount your installation? (y/n): " do_unmount
if [[ "$do_unmount" != "n" ]]; then
    sudo umount -R $mount_dir &> /dev/null
fi

echo ">> Cleaning environment!"
cd ..
if [[ "$do_unmount" != "n" ]]; then
    sudo rm -R $INSTALLATION_DIR
fi
echo ">> Done."
################################## CLEANUP ##################################