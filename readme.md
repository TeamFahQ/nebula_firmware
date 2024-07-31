**I WILL NOT BE HELD RESPONSIBLE IF YOU BRICK YOUR PRINTER - CREATING AND INSTALLING CUSTOM FIRMWARE IS RISKY**

## Prerequisites

You will need a linux machine with the following commands available, something like ubuntu or arch is fine:

- p7zip (7z command)
- wget
- unsquashfs
- mksquashfs

The packages on ubuntu can be installed like so:

```
sudo apt-get install p7zip squashfs-tools wget
```

Don't try and create this on windows or MacOs, you could do it on a ubuntu vm no problem

## Creating

Then you can create a new firmware file, currently without any customations just to test things work with:

```
export NEBULA_FIRMWARE_PASSWORD='the password from a certain discord'
./create.sh
```

**NOTE:** You will be required to enter your `sudo` password

The resulting img file will be located at `/tmp/1.1.0.27-koen01/NEBULA_ota_img_V6.1.1.0.27.img`

## Testing

It's very important to test this in the safest way possible, luckily creality has provided a way to test
a new firmware image from the cli rather than relying on the display server

```
/etc/ota_bin/local_ota_update.sh /tmp/udisk/sda1/NEBULA_ota_img_V6.1.1.0.27.img
```

## Thanks

Thanks for pellcorp and destinal from discord for providing information about testing the image and also for providing 
the password creality uses for generating the image.
