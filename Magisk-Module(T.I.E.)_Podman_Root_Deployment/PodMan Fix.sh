open /etc/default/grub as admin

sudo -i

sudo grub2-mkconfig > /boot/efi/EFI/fedora/grub.cfg
sudo grub2-mkconfig > /boot/grub2/grub.cfg

sudo reboot now

mount -t fdescfs fdesc /dev/fd

To make it permanent, add the following line to /etc/fstab:

fdesc   /dev/fd         fdescfs         rw      0       0

To start Podman after reboot:

service podman enable

podman machine init --cpus 2 -m 4096 -v 
/Users/anton 



#############$$#$#######№########



usermod --add-subuids 1000000-1000999999 root
usermod --add-subgids 1000000-1000999999 root
usermod --add-subuids 1001000000-1001999999 anton
usermod --add-subgids 1001000000-1001999999 anton
usermod --add-subuids 1002000000-1002999999 anton
usermod --add-subgids 1002000000-1002999999 anton
usermod --add-subuids 1003000000-1003999999 anton
usermod --add-subgids 1003000000-1003999999 anton 