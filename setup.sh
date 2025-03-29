#!/bin/bash
sudo rm /usr/bin/osflash
sudo rm /usr/bin/osflash-pack
sudo rm -R /usr/bin/OSFlash_src
sudo mkdir -p /usr/bin/OSFlash_src

sudo cp osflash.sh /usr/bin/OSFlash_src/osflash.sh
sudo cp pack.sh /usr/bin/OSFlash_src/pack.sh

sudo ln -s /usr/bin/OSFlash_src/osflash.sh /usr/bin/osflash
sudo chmod 777 /usr/bin/osflash
sudo ln -s /usr/bin/OSFlash_src/pack.sh /usr/bin/osflash-pack
sudo chmod 777 /usr/bin/osflash-pack