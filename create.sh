#!/bin/bash

# This script is a adaptation from the original K1 firmware script by pellcorp
# https://github.com/pellcorp/creality/tree/main/firmware
# I changed some stuff for the Nebula pad and added a script in root to install the creality helper script
# Also changed the shadow file with root password set to 'creality'

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd -P)"

# if you look hard enough you can find the password on the interwebs in a certain discord
if [ -z "$NEBULA_FIRMWARE_PASSWORD" ]; then
    echo "Creality NEBULA SMART KIT firmware password not defined, did you forget to: "
    echo "export NEBULA_FIRMWARE_PASSWORD='the password from a certain discord'"
    exit 1
fi

commands="7z unsquashfs mksquashfs"
for command in $commands; do
    command -v "$command" > /dev/null
    if [ $? -ne 0 ]; then
        echo "Command $command not found"
        exit 1
    fi
done

old_version=1.1.0.27
version="6.${old_version}"

function write_ota_info() {
    echo "ota_version=${version}" > $CURRENT_DIR/tmp/${version}-koen01/ota_info
    echo "ota_board_name=${board_name}" >> $CURRENT_DIR/tmp/${version}-koen01/ota_info
    echo "ota_compile_time=$(date '+%Y %m.%d %H:%M:%S')" >> $CURRENT_DIR/tmp/${version}-koen01/ota_info
    echo "ota_site=http://192.168.43.52/ota/board_test" >> $CURRENT_DIR/tmp/${version}-koen01/ota_info
    sudo cp $CURRENT_DIR/tmp/${version}-koen01/ota_info $CURRENT_DIR/tmp/${version}-koen01/squashfs-root/etc/
}

function customise_rootfs() {
    write_ota_info
    sudo cp $CURRENT_DIR/etc/init.d/* $CURRENT_DIR/tmp/${version}-koen01/squashfs-root/etc/init.d/
    sudo sed -i "/^root/c\\$(printf '%s\n' "$root_hash")"  $CURRENT_DIR/tmp/${version}-koen01/squashfs-root/etc/shadow
    sudo cp $CURRENT_DIR/root/* $CURRENT_DIR/tmp/${version}-koen01/squashfs-root/root/
}

function update_rootfs() {
    pushd $CURRENT_DIR/tmp/${version}-koen01/ > /dev/null
    sudo unsquashfs orig_rootfs.squashfs 
    customise_rootfs
    sudo mksquashfs squashfs-root rootfs.squashfs || exit $?
    sudo rm -rf squashfs-root
    sudo chown $USER rootfs.squashfs 
}

download=$(wget -q https://www.creality.com/pages/download-creality-nebula-smart-kit -O- | grep -o  "\"\(.*\)V${old_version}.img\"" | head -1 | tr -d '"')
old_image_name=$(basename $download)
board_name=$(echo "$old_image_name" | grep -o '^[^_]*')
old_directory="${board_name}_ota_img_V${old_version}"
old_sub_directory="ota_v${old_version}"
directory="${board_name}_ota_img_V${version}"
sub_directory="ota_v${version}"
image_name="${board_name}_ota_img_V${version}".img
root_hash='root:$1$C91t0g0z$MH9VBdqKSXjvrKNEw7wqG/:19562::::::'

if [ ! -f $CURRENT_DIR/tmp/$old_image_name ]; then
    echo "Downloading $download -> $CURRENT_DIR/tmp/$old_image_name ..."
    wget "$download" -O $CURRENT_DIR/tmp/$old_image_name
fi

if [ -d $CURRENT_DIR/tmp/$old_directory ]; then
    rm -rf $CURRENT_DIR/tmp/$old_directory
fi

7z x $CURRENT_DIR/tmp/$old_image_name -p"$NEBULA_FIRMWARE_PASSWORD" -o$CURRENT_DIR/tmp

if [ -d $CURRENT_DIR/tmp/${version}-koen01 ]; then
    sudo rm -rf $CURRENT_DIR/tmp/${version}-koen01
fi
mkdir -p $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory

cat $CURRENT_DIR/tmp/$old_directory/$old_sub_directory/rootfs.squashfs.* > $CURRENT_DIR/tmp/${version}-koen01/orig_rootfs.squashfs
orig_rootfs_md5=$(md5sum $CURRENT_DIR/tmp/${version}-koen01/orig_rootfs.squashfs | awk '{print $1}')
orig_rootfs_size=$(stat -c%s $CURRENT_DIR/tmp/${version}-koen01/orig_rootfs.squashfs)

# do the changes here
update_rootfs || exit $?

rootfs_md5=$(md5sum $CURRENT_DIR/tmp/${version}-koen01/rootfs.squashfs | awk '{print $1}')
rootfs_size=$(stat -c%s  $CURRENT_DIR/tmp/${version}-koen01/rootfs.squashfs)

echo "current_version=$version" > $CURRENT_DIR/tmp/${version}-koen01/$directory/ota_config.in
echo "" > $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/ota_v${version}.ok

cp $CURRENT_DIR/tmp/$old_directory/$old_sub_directory/ota_update.in $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/
cp $CURRENT_DIR/tmp/$old_directory/$old_sub_directory/ota_md5_xImage* $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/
cp $CURRENT_DIR/tmp/$old_directory/$old_sub_directory/ota_md5_zero.bin* $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/
cp $CURRENT_DIR/tmp/$old_directory/$old_sub_directory/zero.bin.* $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/
cp $CURRENT_DIR/tmp/$old_directory/$old_sub_directory/xImage.* $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/

pushd $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory > /dev/null
split -d -b 1048576 -a 4 $CURRENT_DIR/tmp/${version}-koen01/rootfs.squashfs rootfs.squashfs.
popd > /dev/null

part_md5=
for i in $(ls $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/rootfs.squashfs.*); do
    file=$(basename $i)
    if [ -z "$part_md5" ]; then
        id=$rootfs_md5
    else
        id=$part_md5
    fi
    mv "$CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/$file" "$CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/${file}.${id}"
    part_md5=$(md5sum $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/${file}.${id} | awk '{print $1}')
    echo "$part_md5" >> "$CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/ota_md5_rootfs.squashfs.${rootfs_md5}"
done

sed -i "s/ota_version=$old_version/ota_version=$version/g" $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/ota_update.in
sed -i "s/img_md5=$orig_rootfs_md5/img_md5=$rootfs_md5/g" $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/ota_update.in
sed -i "s/img_size=$orig_rootfs_size/img_size=$rootfs_size/g" $CURRENT_DIR/tmp/${version}-koen01/$directory/$sub_directory/ota_update.in

pushd $CURRENT_DIR/tmp/${version}-koen01/ > /dev/null
7z a ${image_name}.7z -p"$NEBULA_FIRMWARE_PASSWORD" $directory
mv ${image_name}.7z ${image_name}
mv $CURRENT_DIR/tmp/${version}-koen01/${image_name} $CURRENT_DIR
popd > /dev/null
